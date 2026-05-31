# Model Versions

## v1 (2026-05-28) — baseline (snapshot)
**Branch:** main · **Tag:** models-v1  
**Snapshot:** `models/v1/`

### HAR v1 (snapshot — clases sin cycling)
- **Architecture:** 1D-CNN (3× Conv1D + GlobalAvgPool + Dense), 85,126 params
- **Input:** (128, 6) — 2.56 s @ 50 Hz, accel_xyz + gyro_xyz
- **Classes (v1):** walking, upstairs, downstairs, sitting, standing, running
- **Training data:** UCI HAR (10k ventanas, 30 sujetos) + MotionSense (21k ventanas, 24 sujetos)
- **Validation:** LOSO 54 sujetos
- **LOSO F1-macro:** ~0.86–0.88
- **TFLite fp16:** 179 KB, accuracy 0.978, latency 0.088 ms
- **TFLite int8:** 106 KB, accuracy 0.969, latency 0.090 ms

### Fall detector v1
- **Architecture:** Binary CNN (2× Conv1D + GlobalAvgPool + Dense), 9,313 params
- **Input:** (100, 6) — 2 s centrado en pico de impacto
- **Keras source:** `fall_cnn_best.keras` — 163 KB
- **TFLite int8:** `fall_model_int8.tflite` — 22 KB, recall=1.0, precision=0.965, F1=0.982

---

## current (main) — 6 clases incl. cycling
**Branch:** main · **Models:** `app/assets/models/` + `models/tflite/`

### HAR — current
- **Architecture:** 1D-CNN (3× Conv1D + GlobalAvgPool + Dense)
- **Input:** (128, 6) — 2.56 s @ 50 Hz, accel_xyz + gyro_xyz
- **Classes (6):** `stationary`(0) · `walking`(1) · `running`(2) · **`cycling`**(3) · `upstairs`(4) · `downstairs`(5)
  - `stationary` = sitting + standing fusionados (0 VitaPoints)
  - `cycling` = entrenado con PAMAP2 #231 (resampleo 100→50 Hz)
- **Training data:** UCI HAR + MotionSense + PAMAP2
- **Validation:** LOSO
- **TFLite fp16:** `har_model_fp16.tflite` — 179 KB
- **TFLite int8:** `har_model_int8.tflite` — 106 KB ← modelo usado en la app
- **VitaPoints/min:** walking 2 · running 5 · cycling 4 · upstairs 3 · downstairs 2 · stationary 0
- **Suavizado:** voto mayoritario últimas 3 ventanas (`_smoothingN = 3`)
- **Gate estático:** SVM < 0.05g → fuerza `stationary` (evita ruido de mesa como "upstairs")

### Fall detector — sin cambios (igual a v1)
- `fall_model_int8.tflite` — 22 KB, recall=1.0, precision=0.965, F1=0.982
- Cascada: Stage 1 SVM gate (3g) + Stage 2 CNN + Stage 2.5 altitude gate + Stage 3 inmovilidad
- Cooldown: 15 s entre alertas consecutivas
