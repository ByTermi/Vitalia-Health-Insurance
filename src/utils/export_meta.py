"""
Generate models/tflite/model_meta.json from MLflow latest runs + local TFLite sizes.

Usage:
    python -m src.utils.export_meta            # from repo root
    python src/utils/export_meta.py

Call this at the end of any training notebook/script after exporting .tflite files.
The n8n sync picks up model_meta.json on the next 5-min poll and uploads it to MinIO.
Prometheus gauges refresh within 60 s after that.
"""
import json
import os
import sys
from pathlib import Path

MODELS_DIR = Path("models/tflite")
OUTPUT_PATH = MODELS_DIR / "model_meta.json"

MLFLOW_URI = os.environ.get("MLFLOW_TRACKING_URI", "http://localhost:5000")
HAR_EXPERIMENT = "vitalia-har-cnn"
FALL_EXPERIMENT = "vitalia-fall-cnn"


def _get_latest_run_metrics(client, experiment_name: str) -> dict:
    exp = client.get_experiment_by_name(experiment_name)
    if exp is None:
        print(f"  [warn] MLflow experiment '{experiment_name}' not found", file=sys.stderr)
        return {}
    runs = client.search_runs(
        experiment_ids=[exp.experiment_id],
        order_by=["start_time DESC"],
        max_results=1,
    )
    if not runs:
        print(f"  [warn] No runs in '{experiment_name}'", file=sys.stderr)
        return {}
    return runs[0].data.metrics


def _latest_tflite_size_kb(glob_pattern: str) -> int:
    files = sorted(MODELS_DIR.glob(glob_pattern), key=lambda f: f.stat().st_mtime, reverse=True)
    if not files:
        return 0
    return max(1, round(files[0].stat().st_size / 1024))


def _extract_version() -> str:
    """Parse version from newest har_*_vX.Y.Z.tflite filename."""
    files = sorted(MODELS_DIR.glob("har_*.tflite"), key=lambda f: f.stat().st_mtime, reverse=True)
    for f in files:
        if "_v" in f.name:
            try:
                return f.name.split("_v")[-1].replace(".tflite", "")
            except Exception:
                pass
    return "1.0.0"


def export_meta(output_path: Path = OUTPUT_PATH) -> dict:
    try:
        import mlflow
        from mlflow.tracking import MlflowClient
        mlflow.set_tracking_uri(MLFLOW_URI)
        client = MlflowClient(MLFLOW_URI)
        har_metrics = _get_latest_run_metrics(client, HAR_EXPERIMENT)
        fall_metrics = _get_latest_run_metrics(client, FALL_EXPERIMENT)
    except Exception as e:
        print(f"  [warn] MLflow unreachable ({e}) — metrics will be 0.0", file=sys.stderr)
        har_metrics = {}
        fall_metrics = {}

    meta = {
        "version": _extract_version(),
        "har": {
            "f1_macro": round(float(har_metrics.get("f1_macro_full", 0.0)), 4),
            "size_kb": _latest_tflite_size_kb("har_*.tflite"),
        },
        "fall": {
            "recall_balanced":    round(float(fall_metrics.get("balanced_recall",    0.0)), 4),
            "precision_balanced": round(float(fall_metrics.get("balanced_precision", 0.0)), 4),
            "f1_balanced":        round(float(fall_metrics.get("balanced_f1",        0.0)), 4),
            "size_kb": _latest_tflite_size_kb("fall_*.tflite"),
        },
    }

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(meta, indent=2))
    print(f"model_meta.json → {output_path}")
    print(json.dumps(meta, indent=2))
    return meta


if __name__ == "__main__":
    export_meta()
