# Vitalia Health Insurance — ML + Flutter

On-device Human Activity Recognition (HAR) and fall-detection pipeline. Academic competition, Case 06.

## Project repositories

| Repo | GitHub | Description |
|------|--------|-------------|
| **This repo** | — | ML pipeline (Python/TFLite), Flutter Android app, notebooks, models |
| **Backend** | https://github.com/ByTermi/Vitalia-Backend | FastAPI + PostgreSQL + Redis + MinIO + MLflow + Prometheus + Grafana |
| **Data Viewer** | https://github.com/ByTermi/Vitalia-Data-Viewer | Read-only backend inspector (http://localhost:8090) |

## Results

Models trained, quantized to TFLite int8, and deployed on-device in the Flutter app.

| Model | Dataset(s) | Metrics | TFLite int8 | Latency |
|-------|-----------|---------|-------------|---------|
| **HAR (activities)** | UCI HAR #240 · MotionSense · PAMAP2 | Accuracy **0.978** (int8 0.969) · RF/SVM baseline LOSO F1-macro 0.826 / 0.810 | 105 KB | 0.09 ms/window (PC) |
| **Fall detector** | MobiAct v2 · SisFall | F1 **0.982** · Recall **1.000** · Precision 0.965 · AUC-ROC 0.989 | 22 KB | <0.05 ms |

- **100% on-device inference** (GDPR): only derived events reach the backend.
- **3-stage fall cascade**: cheap SVM impact detector (<1 mW) → CNN confirmer → age-segment configurable threshold. Recall prioritized (1.000) so no fall is missed.
- Compression targets met: <200 KB and <50 ms latency for both models.

> Numbers reproducible from `notebooks/03_har_training.ipynb`, `04_fall_detection.ipynb` and `05_tflite_benchmark.ipynb`.

## Production backend (deployed)

Self-hosted stack (no cloud, EEA) that starts with a single `docker compose`. Containerized services:

| Service | Port | Role |
|---------|------|------|
| `api` (FastAPI) | 8000 | REST API: activity/fall events, VitaPoints, model OTA, GDPR right-to-erasure |
| `db` (PostgreSQL 16) | 5432 | Users, events, VitaPoints, consents |
| `redis` | 6379 | `vitalia:falls` queue between API and worker |
| `worker` | — | Fall-alert pipeline (waits 30 s ACK → ntfy + email) + GDPR cron |
| `minio` | 9000/9001 | S3 store for OTA TFLite models and opt-in retraining data |
| `ntfy` | 8080 | Self-hosted push notifications (fall alerts via SSE) |
| `mlflow` | 5000 | Model registry + experiment tracking (`vitalia-har`, `vitalia-fall`) |
| `prometheus` | 9090 | Scrapes `/metrics` + model-quality gauges (`har_f1_macro`, `fall_recall_balanced`) |
| `grafana` | 3000 | 12 panels: operations + "Deployed Model Quality" |

Endpoint and end-to-end flow details: `docs/SERVICIOS_BACKEND.md`.

## Start the full stack (Backend + Data Viewer)

From the Backend repo:

```bash
cd ../Vitalia\ Health\ Insurance\ Backend
docker compose -f docker-compose-general.yml up -d --build
```

## Stack

- **ML pipeline:** Python 3.11 · NumPy · pandas · scikit-learn · TensorFlow/Keras → TFLite
- **Demo app:** Flutter (Android) · `tflite_flutter` · `sensors_plus`
- **Notebooks:** Jupyter — EDA, training, evaluation

## Docs

- `docs/PLAN.md` — overall plan
- `docs/TAREAS_INIGO.md` — activities + compression
- `docs/TAREAS_JAIME.md` — falls + architecture + Flutter app
- `docs/SERVICIOS_BACKEND.md` — backend endpoints and flows

## Start the ML environment

```bash
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
jupyter notebook notebooks/
```

## Start the Flutter app

```bash
cd app && flutter pub get && flutter run
```
