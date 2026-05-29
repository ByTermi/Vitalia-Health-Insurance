# Vitalia Health Insurance — ML + Flutter

Pipeline de reconocimiento de actividad fisica (HAR) y deteccion de caidas on-device. Caso 06 de competicion academica.

## Repositorios del proyecto

| Repo | GitHub | Descripcion |
|------|--------|-------------|
| **Este repo** | — | Pipeline ML (Python/TFLite), app Flutter Android, notebooks, modelos |
| **Backend** | https://github.com/ByTermi/Vitalia-Backend | FastAPI + PostgreSQL + Redis + MinIO + MLflow + Prometheus + Grafana |
| **Data Viewer** | https://github.com/ByTermi/Vitalia-Data-Viewer | Inspector read-only del backend (http://localhost:8090) |

## Arrancar el stack completo (Backend + Data Viewer)

Desde el repo Backend:

```bash
cd ../Vitalia\ Health\ Insurance\ Backend
docker compose -f docker-compose-general.yml up -d --build
```

## Stack

- **ML pipeline:** Python 3.11 · NumPy · pandas · scikit-learn · TensorFlow/Keras → TFLite
- **App demo:** Flutter (Android) · `tflite_flutter` · `sensors_plus`
- **Notebooks:** Jupyter — EDA, entrenamiento, evaluacion

## Docs

- `docs/PLAN.md` — plan global
- `docs/TAREAS_INIGO.md` — actividades + compresion
- `docs/TAREAS_JAIME.md` — caidas + arquitectura + app Flutter

## Arrancar entorno ML

```bash
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
jupyter notebook notebooks/
```

## Arrancar app Flutter

```bash
cd app && flutter pub get && flutter run
```
