"""
Shared preprocessing module: resampling, windowing, SVM, augmentation.
Used by both HAR (Íñigo) and fall detector (Jaime).
"""

import numpy as np
from scipy.signal import resample_poly, butter, filtfilt
from math import gcd


# --------------------------------------------------------------------------- #
# Resampling
# --------------------------------------------------------------------------- #

def resample(data: np.ndarray, orig_hz: int, target_hz: int = 50) -> np.ndarray:
    """Resample sensor data from orig_hz to target_hz.

    Args:
        data: (N, C) array — N samples, C channels.
        orig_hz: original sampling frequency.
        target_hz: target frequency (default 50 Hz).

    Returns:
        (M, C) resampled array.
    """
    if orig_hz == target_hz:
        return data
    g = gcd(orig_hz, target_hz)
    up = target_hz // g
    down = orig_hz // g
    return resample_poly(data, up, down, axis=0).astype(np.float32)


# --------------------------------------------------------------------------- #
# Signal preprocessing
# --------------------------------------------------------------------------- #

def butterworth_lowpass(data: np.ndarray, cutoff: float = 20.0, fs: float = 50.0,
                        order: int = 4) -> np.ndarray:
    """Zero-phase Butterworth low-pass filter (removes sensor noise above cutoff Hz)."""
    nyq = fs / 2.0
    normal_cutoff = cutoff / nyq
    b, a = butter(order, normal_cutoff, btype='low', analog=False)
    return filtfilt(b, a, data, axis=0).astype(np.float32)


def normalize_subject(data: np.ndarray) -> np.ndarray:
    """Zero-mean, unit-std normalization per channel (per subject)."""
    mean = data.mean(axis=0, keepdims=True)
    std = data.std(axis=0, keepdims=True) + 1e-8
    return ((data - mean) / std).astype(np.float32)


# --------------------------------------------------------------------------- #
# Signal Vector Magnitude
# --------------------------------------------------------------------------- #

def compute_svm(accel: np.ndarray) -> np.ndarray:
    """Compute SVM = sqrt(x² + y² + z²) for accelerometer columns.

    Args:
        accel: (N, 3) array — ax, ay, az in g.

    Returns:
        (N,) SVM array.
    """
    return np.sqrt((accel ** 2).sum(axis=1)).astype(np.float32)


# --------------------------------------------------------------------------- #
# Sliding window
# --------------------------------------------------------------------------- #

def sliding_window(data: np.ndarray, window_size: int = 128,
                   overlap: float = 0.5) -> np.ndarray:
    """Extract overlapping windows from a continuous signal.

    Args:
        data: (N, C) sensor data.
        window_size: samples per window (128 @ 50 Hz = 2.56 s for HAR).
        overlap: fraction of overlap between consecutive windows (0.5 = 50 %).

    Returns:
        (W, window_size, C) array of windows.
    """
    step = int(window_size * (1.0 - overlap))
    n_samples, n_channels = data.shape
    starts = range(0, n_samples - window_size + 1, step)
    windows = np.stack([data[s: s + window_size] for s in starts], axis=0)
    return windows.astype(np.float32)


def extract_fall_window(data: np.ndarray, impact_idx: int,
                        pre: int = 50, post: int = 50) -> np.ndarray:
    """Extract a window centered on the fall impact peak.

    Args:
        data: (N, C) sensor data.
        impact_idx: sample index of the SVM peak (impact).
        pre: samples before the impact (default 50 = 1 s @ 50 Hz).
        post: samples after the impact (default 50 = 1 s @ 50 Hz).

    Returns:
        (pre+post, C) window, or None if not enough samples around the peak.
    """
    start = impact_idx - pre
    end = impact_idx + post
    if start < 0 or end > len(data):
        return None
    return data[start:end].astype(np.float32)


def detect_impact_peaks(svm: np.ndarray, threshold_g: float = 3.0,
                        min_distance: int = 50) -> np.ndarray:
    """Stage-1 fall detector: find SVM peaks exceeding threshold_g.

    Returns indices of candidate impact samples.
    """
    from scipy.signal import find_peaks
    peaks, _ = find_peaks(svm, height=threshold_g, distance=min_distance)
    return peaks


# --------------------------------------------------------------------------- #
# Data augmentation (placement invariance + fall class balancing)
# --------------------------------------------------------------------------- #

def augment_axis_permutation(window: np.ndarray,
                             accel_cols: slice = slice(0, 3),
                             gyro_cols: slice = slice(3, 6)) -> np.ndarray:
    """Simulate different phone orientations by permuting/flipping axes.

    Applies a random permutation of [x, y, z] with random sign flips.
    """
    perm = np.random.permutation(3)
    signs = np.random.choice([-1, 1], size=3)
    aug = window.copy()
    aug[:, accel_cols] = window[:, accel_cols][:, perm] * signs
    aug[:, gyro_cols] = window[:, gyro_cols][:, perm] * signs
    return aug.astype(np.float32)


def augment_gaussian_noise(window: np.ndarray, sigma: float = 0.01) -> np.ndarray:
    """Add Gaussian noise (σ = 0.01 g) to simulate sensor variability."""
    return (window + np.random.normal(0, sigma, window.shape)).astype(np.float32)


def augment_magnitude_scale(window: np.ndarray,
                            scale_range: tuple = (0.8, 1.2)) -> np.ndarray:
    """Scale all axes by a random factor to simulate sensor sensitivity differences."""
    scale = np.random.uniform(*scale_range)
    return (window * scale).astype(np.float32)


def augment_time_warp(window: np.ndarray, warp_ratio: float = 0.1) -> np.ndarray:
    """Stretch/compress the time axis by ±warp_ratio then resize back."""
    n, c = window.shape
    factor = 1.0 + np.random.uniform(-warp_ratio, warp_ratio)
    new_len = max(1, int(n * factor))
    warped = resample_poly(window, new_len, n, axis=0)
    # Resize back to original length
    out = resample_poly(warped, n, new_len, axis=0)
    # Trim or pad to ensure exact length
    if len(out) >= n:
        return out[:n].astype(np.float32)
    pad = np.zeros((n - len(out), c), dtype=np.float32)
    return np.concatenate([out, pad], axis=0).astype(np.float32)


def augment_window(window: np.ndarray, n_augments: int = 4) -> list:
    """Apply all augmentation strategies to a single window. Returns list of augmented windows."""
    augmented = []
    for _ in range(n_augments):
        aug = window.copy()
        if np.random.rand() > 0.5:
            aug = augment_axis_permutation(aug)
        if np.random.rand() > 0.5:
            aug = augment_gaussian_noise(aug)
        if np.random.rand() > 0.5:
            aug = augment_magnitude_scale(aug)
        if np.random.rand() > 0.5:
            aug = augment_time_warp(aug)
        augmented.append(aug)
    return augmented


# --------------------------------------------------------------------------- #
# Full preprocessing pipeline
# --------------------------------------------------------------------------- #

def preprocess_signal(data: np.ndarray, orig_hz: int,
                      target_hz: int = 50,
                      lowpass_cutoff: float = 20.0) -> np.ndarray:
    """Resample → low-pass filter → per-subject normalize.

    Args:
        data: (N, 6) raw sensor data [ax, ay, az, gx, gy, gz].
        orig_hz: original sampling frequency.
        target_hz: target frequency.
        lowpass_cutoff: Butterworth cutoff in Hz.

    Returns:
        Preprocessed (M, 6) array at target_hz.
    """
    data = resample(data, orig_hz, target_hz)
    data = butterworth_lowpass(data, cutoff=lowpass_cutoff, fs=target_hz)
    data = normalize_subject(data)
    return data
