# Model Versions

## v1 (2026-05-28) — baseline
**Branch:** main · **Tag:** models-v1  
**Snapshot:** `models/v1/`

### HAR
- **Architecture:** 1D-CNN (3× Conv1D + GlobalAvgPool + Dense), 85,126 params
- **Input:** (128, 6) — 2.56 s @ 50 Hz, accel_xyz + gyro_xyz
- **Classes:** walking, upstairs, downstairs, sitting, standing, running
- **Training data:** UCI HAR (10k ventanas, 30 sujetos) + MotionSense (21k ventanas, 24 sujetos) = 29,894 ventanas totales
- **Validation:** LOSO 54 sujetos
- **LOSO F1-macro:** ~0.86–0.88
- **Running F1:** ~0.70–0.80 (clase más débil — solo 2,025 ventanas)
- **TFLite fp16:** `har_model_fp16.tflite` — 179 KB, accuracy 0.978, latency 0.088 ms
- **TFLite int8:** `har_model_int8.tflite` — 106 KB, accuracy 0.969, latency 0.090 ms

### Fall detector
- **Architecture:** Binary CNN (2× Conv1D + GlobalAvgPool + Dense), 9,313 params
- **Input:** (100, 6) — 2 s centrado en pico de impacto
- **Keras source:** `fall_cnn_best.keras` — 163 KB
- **TFLite int8:** `fall_model_int8.tflite` — 22 KB, recall=1.0, precision=0.965, F1=0.982

---

## v2 (pendiente)
**Branch:** Inigo-por-Jaime  
Mejoras: ResNet1D + augmentación por clase (running ×5) + class weights + cosine LR.
