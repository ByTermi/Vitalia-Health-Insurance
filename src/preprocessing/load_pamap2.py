"""
PAMAP2 cycling loader for Vitalia HAR pipeline.

Extracts cycling windows (activityID == 6) from the ankle IMU of the PAMAP2
Protocol dataset.  Returns (X, y, subjects) in the same format as the UCI HAR /
MotionSense processed arrays: (N, 128, 6) float32 with channels
[lax, lay, laz, gx, gy, gz] at 50 Hz.

Placement caveat: PAMAP2 uses a body-worn IMU on the ankle, not a smartphone in
the pocket.  SVM rotation-invariant features + axis-permutation augmentation
compensate for this.  This is a known limitation documented in docs/PLAN.md.
"""

from __future__ import annotations
from pathlib import Path
import numpy as np
from scipy.signal import butter, filtfilt
from .windowing import resample, sliding_window, augment_window

# ─── PAMAP2 column layout ───────────────────────────────────────────────────
# Col 0: timestamp (s)
# Col 1: activityID
# Col 2: heart rate
# IMU hand  → cols  3-19  (17 cols: temp, accel16×3, accel6×3, gyro×3, mag×3, orient×4)
# IMU chest → cols 20-36
# IMU ankle → cols 37-53
_ANKLE_ACCEL_COLS = [38, 39, 40]   # ±16g accel in m/s²
_ANKLE_GYRO_COLS  = [44, 45, 46]  # gyroscope in rad/s
_ACTIVITY_COL     = 1
_CYCLING_ID       = 6
_PAMAP2_HZ        = 100
_TARGET_HZ        = 50
_GRAVITY_MS2      = 9.81


def _highpass_gravity_removal(accel_g: np.ndarray, fs: float = 50.0) -> np.ndarray:
    """Remove gravity component from accelerometer via Butterworth high-pass at 0.3 Hz."""
    b, a = butter(4, 0.3 / (fs / 2), btype='high')
    return filtfilt(b, a, accel_g, axis=0)


def load_pamap2_cycling(
    pamap2_dir: str | Path,
    window_size: int = 128,
    overlap: float = 0.5,
    subject_prefix: int = 200,   # offset added to PAMAP2 subject IDs to avoid collision
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Load cycling windows from PAMAP2 Protocol files.

    Parameters
    ----------
    pamap2_dir:
        Root of the PAMAP2_Dataset/PAMAP2_Dataset directory that contains
        the Protocol/ subdirectory.
    window_size, overlap:
        Window parameters — must match the rest of the HAR pipeline.
    subject_prefix:
        Added to PAMAP2 subject IDs (101-109) → 301-309, ensuring no clash
        with UCI (1-30) or MotionSense (1-24) subject IDs.

    Returns
    -------
    X: (N, 128, 6) float32  — windows [lax, lay, laz, gx, gy, gz] at 50 Hz
    y: (N,) int32           — all 3 (cycling class index in canonical order)
    subjects: (N,) int32    — subject IDs offset by subject_prefix
    """
    pamap2_dir = Path(pamap2_dir)
    protocol_dir = pamap2_dir / 'Protocol'
    if not protocol_dir.exists():
        raise FileNotFoundError(f'PAMAP2 Protocol directory not found: {protocol_dir}')

    X_parts, y_parts, subj_parts = [], [], []

    for dat_file in sorted(protocol_dir.glob('subject*.dat')):
        subj_id = int(dat_file.stem.replace('subject', ''))

        try:
            data = np.loadtxt(dat_file, dtype=np.float32)
        except Exception as e:
            print(f'  Warning: could not load {dat_file.name}: {e}')
            continue

        # Keep only cycling rows; drop NaN rows (heart rate often NaN)
        mask = data[:, _ACTIVITY_COL] == _CYCLING_ID
        cycling = data[mask]
        if len(cycling) < window_size:
            print(f'  {dat_file.name}: only {len(cycling)} cycling samples — skipping')
            continue

        # Replace NaN with column mean (rare sensor dropouts)
        col_means = np.nanmean(cycling, axis=0)
        nan_mask = np.isnan(cycling)
        cycling[nan_mask] = np.take(col_means, np.where(nan_mask)[1])

        # Extract ankle accel (m/s²) and gyro (rad/s)
        accel_ms2 = cycling[:, _ANKLE_ACCEL_COLS]
        gyro      = cycling[:, _ANKLE_GYRO_COLS]

        # 1. Resample 100 → 50 Hz
        accel_ms2 = resample(accel_ms2, orig_hz=_PAMAP2_HZ, target_hz=_TARGET_HZ)
        gyro      = resample(gyro,      orig_hz=_PAMAP2_HZ, target_hz=_TARGET_HZ)

        n = min(len(accel_ms2), len(gyro))
        accel_ms2 = accel_ms2[:n]
        gyro      = gyro[:n]

        # 2. Convert accel to g
        accel_g = accel_ms2 / _GRAVITY_MS2

        # 3. Remove gravity via high-pass (produces linear/body accel in g,
        #    matching UCI body_acc and MotionSense userAcceleration channels)
        linear_accel_g = _highpass_gravity_removal(accel_g, fs=_TARGET_HZ)

        # 4. Build (N, 6) signal: [lax, lay, laz, gx, gy, gz]
        signal = np.concatenate([linear_accel_g, gyro], axis=1).astype(np.float32)

        # 5. Sliding window
        windows = sliding_window(signal, window_size=window_size, overlap=overlap)
        if len(windows) == 0:
            continue

        X_parts.append(windows)
        y_parts.append(np.full(len(windows), 3, dtype=np.int32))   # cycling = index 3
        subj_parts.append(np.full(len(windows), subject_prefix + subj_id, dtype=np.int32))
        print(f'  {dat_file.name}: {len(windows)} cycling windows')

    if not X_parts:
        raise RuntimeError('No cycling windows found — check PAMAP2 path and activityID.')

    X = np.concatenate(X_parts, axis=0)
    y = np.concatenate(y_parts, axis=0)
    subjects = np.concatenate(subj_parts, axis=0)
    print(f'PAMAP2 cycling total: {len(X)} windows, {len(np.unique(subjects))} subjects')
    return X, y, subjects


def augment_cycling(
    X_cyc: np.ndarray,
    y_cyc: np.ndarray,
    subj_cyc: np.ndarray,
    n_augments: int = 4,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Aggressively augment cycling windows to compensate for:
      - Small subject count (9 subjects)
      - Placement gap (ankle → pocket)

    Uses augment_window() with emphasis on axis_permutation + magnitude_scale.
    Total windows = original × (n_augments + 1).
    """
    aug_X, aug_y, aug_subj = [X_cyc], [y_cyc], [subj_cyc]
    for i in range(len(X_cyc)):
        extras = augment_window(X_cyc[i], n_augments=n_augments)
        aug_X.append(np.stack(extras))
        aug_y.append(np.full(n_augments, 3, dtype=np.int32))
        aug_subj.append(np.full(n_augments, subj_cyc[i], dtype=np.int32))
    return (
        np.concatenate(aug_X, axis=0),
        np.concatenate(aug_y, axis=0),
        np.concatenate(aug_subj, axis=0),
    )
