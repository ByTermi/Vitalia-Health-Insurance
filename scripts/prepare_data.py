"""
Extrae celdas de procesamiento del notebook 01 y genera los archivos .npy
necesarios para entrenar el modelo HAR.

Output en data/processed/:
  X_activities.npy        (N, 128, 6)  float32
  y_activities.npy        (N,)         int   1-6
  subjects_activities.npy (N,)         int

Ejecutar desde la raiz del proyecto:
  python scripts/prepare_data.py
"""

import sys
from pathlib import Path

# Añadir raiz al path para importar src/preprocessing
sys.path.insert(0, str(Path(__file__).parent.parent))

import numpy as np
import pandas as pd
from src.preprocessing.windowing import resample, sliding_window

DATA_RAW  = Path('data/raw')
DATA_PROC = Path('data/processed')
DATA_PROC.mkdir(parents=True, exist_ok=True)

# ── UCI HAR ──────────────────────────────────────────────────────────────────
UCI_ROOT = DATA_RAW / 'UCI_HAR' / 'UCI HAR Dataset'
UCI_TO_UNIFIED = {1: 1, 2: 2, 3: 3, 4: 4, 5: 5}  # drop label 6 (laying)

def load_uci_split(split: str):
    sig_dir = UCI_ROOT / split / 'Inertial Signals'
    channels = []
    for sensor in ['body_acc', 'body_gyro']:
        for ax in ['x', 'y', 'z']:
            channels.append(np.loadtxt(sig_dir / f'{sensor}_{ax}_{split}.txt'))
    X = np.stack(channels, axis=-1).astype(np.float32)
    y = np.loadtxt(UCI_ROOT / split / f'y_{split}.txt').astype(int)
    subjects = np.loadtxt(UCI_ROOT / split / f'subject_{split}.txt').astype(int)
    return X, y, subjects

print('Cargando UCI HAR...')
X_tr, y_tr, s_tr = load_uci_split('train')
X_te, y_te, s_te = load_uci_split('test')
X_uci = np.concatenate([X_tr, X_te])
y_uci = np.concatenate([y_tr, y_te])
s_uci = np.concatenate([s_tr, s_te])

# Filtrar clases y remapear
mask = np.isin(y_uci, list(UCI_TO_UNIFIED.keys()))
X_uci = X_uci[mask]
y_uci = np.array([UCI_TO_UNIFIED[l] for l in y_uci[mask]])
s_uci = s_uci[mask]
print(f'  UCI HAR: {X_uci.shape}, clases={np.unique(y_uci)}')

# ── MotionSense ───────────────────────────────────────────────────────────────
MS_ROOT = DATA_RAW / 'MotionSense' / 'A_DeviceMotion_data'
if not MS_ROOT.exists():
    # Fallback: carpetas directamente en MotionSense/
    MS_ROOT = DATA_RAW / 'MotionSense'

MS_LABEL_MAP = {'dws': 3, 'ups': 2, 'wlk': 1, 'jog': 6, 'sit': 4, 'std': 5}
ACC_COLS  = ['userAcceleration.x', 'userAcceleration.y', 'userAcceleration.z']
GYRO_COLS = ['rotationRate.x',     'rotationRate.y',     'rotationRate.z']

print('Cargando MotionSense...')
ms_windows, ms_labels, ms_subjects = [], [], []
for activity_dir in sorted(MS_ROOT.iterdir()):
    prefix = activity_dir.name.split('_')[0]
    if prefix not in MS_LABEL_MAP:
        continue
    label = MS_LABEL_MAP[prefix]
    for csv_path in sorted(activity_dir.glob('sub_*.csv')):
        sub_id = int(csv_path.stem.split('_')[1])
        df = pd.read_csv(csv_path)
        if not all(c in df.columns for c in ACC_COLS + GYRO_COLS):
            continue
        signal = df[ACC_COLS + GYRO_COLS].values.astype(np.float32)
        wins = sliding_window(signal, window_size=128, overlap=0.5)
        if len(wins) == 0:
            continue
        ms_windows.append(wins)
        ms_labels.extend([label] * len(wins))
        ms_subjects.extend([sub_id + 100] * len(wins))  # offset para no colisionar con UCI

X_ms = np.concatenate(ms_windows, axis=0)
y_ms = np.array(ms_labels)
s_ms = np.array(ms_subjects)
print(f'  MotionSense: {X_ms.shape}, clases={np.unique(y_ms)}')

# ── Merge y guardar ───────────────────────────────────────────────────────────
X_all = np.concatenate([X_uci, X_ms], axis=0)
y_all = np.concatenate([y_uci, y_ms], axis=0)
s_all = np.concatenate([s_uci, s_ms], axis=0)

np.save(DATA_PROC / 'X_activities.npy',        X_all)
np.save(DATA_PROC / 'y_activities.npy',         y_all)
np.save(DATA_PROC / 'subjects_activities.npy',  s_all)

print(f'\nGuardado en data/processed/')
print(f'  X_activities.npy:        {X_all.shape}  {X_all.dtype}  ({X_all.nbytes/1e6:.1f} MB)')
print(f'  y_activities.npy:        {y_all.shape}')
print(f'  subjects_activities.npy: {s_all.shape}  ({len(np.unique(s_all))} sujetos)')
NAMES = {1:'walking',2:'upstairs',3:'downstairs',4:'sitting',5:'standing',6:'running'}
for lbl in sorted(np.unique(y_all)):
    print(f'  clase {lbl} ({NAMES[lbl]:12s}): {(y_all==lbl).sum():5d} ventanas')
