# Tareas — Íñigo
## Foco: Modelo HAR (6 clases) + Compresión Móvil

**Responsabilidad:** construir el clasificador de actividad (static, walking, running, cycling, stairs) end-to-end y entregar los artefactos TFLite que Jaime integrará en la app Flutter.

---

## ✅ Ya hecho en el setup (no repetir)

| Tarea | Estado |
|-------|--------|
| Estructura de carpetas (`data/`, `notebooks/`, `src/`, `models/`, `app/`) | ✅ Hecho |
| `requirements.txt` | ✅ Hecho |
| Skills y agentes importados en `.claude/` | ✅ Hecho |
| `CLAUDE.md` reescrito para el proyecto ML | ✅ Hecho |
| `find-skills` instalada en `.agents/skills/` | ✅ Hecho |

---

## Sprint-0 (Día 1 — COMPARTIDO con Jaime)

No avanzar a las tareas individuales hasta que estos estén listos.

- [ ] **S0-1** Crear el entorno Python:
  ```bash
  python -m venv .venv
  .venv\Scripts\activate   # Windows
  pip install -r requirements.txt
  ```

- [ ] **S0-3** Confirmar la estrategia de ventaneo (ya documentada en `docs/PLAN.md`):
  - Frecuencia objetivo: **50 Hz**
  - Tamaño ventana: **128 muestras (2.56 s)**, solapamiento **50 %**
  - Tensor de salida: `[N, 128, 6]` (accel_xyz + gyro_xyz)

- [ ] **S0-4** Construir `src/preprocessing/windowing.py` — módulo compartido:
  ```python
  def resample(signal, from_hz, to_hz=50)       # interpolación scipy
  def sliding_window(signal, window=128, overlap=0.5)  # generador de ventanas
  def compute_svm(x, y, z)                       # Signal Vector Magnitude √(x²+y²+z²)
  def normalize_by_subject(windows, subject_ids) # normalización media 0, std 1 por sujeto
  def augment_rotation(window)                   # permutación/rotación de ejes xyz
  def augment_noise(window, sigma=0.01)          # ruido gaussiano σ=0.01 g
  def augment_timewarp(window, rate=0.1)         # time-warping ±10 %
  def augment_magnitude(window, lo=0.8, hi=1.2)  # escalado de magnitud
  ```
  > La augmentation (rotación, ruido, time-warp, magnitude) es la estrategia de **datos sintéticos** (M2 del enunciado) para la robustez ante colocaciones del teléfono (R2 del enunciado).

- [ ] **S0-5** Descargar datasets de Íñigo:
  - **UCI HAR #240:** https://archive.ics.uci.edu/dataset/240/human+activity+recognition+using+smartphones → `data/raw/UCI_HAR/`
  - **MotionSense:** https://github.com/mmalekzadeh/motion-sense → `data/raw/MotionSense/`
  - **PAMAP2** (si hay tiempo): https://archive.ics.uci.edu/dataset/231/pamap2+physical+activity+monitoring → `data/raw/PAMAP2/`

---

## Día 2 — EDA y Baseline

- [ ] **A1** `notebooks/01_eda_activities.ipynb`:
  - Visualizar señales temporales por actividad y por placement (cintura UCI HAR vs bolsillo MotionSense)
  - Distribución de clases y duración media por actividad
  - Comparar UCI HAR vs MotionSense: ¿diferencias de distribución por placement?
  - Confirmar que `windowing.py` produce tensores `[N, 128, 6]` correctos
  - Visualizar el efecto de la augmentation (rotación, ruido) sobre una ventana ejemplo

- [ ] **A2** Baseline clásico (necesario para justificar la CNN — cubre V2):
  - Features manuales: media, std, energía, cruce por cero, correlación inter-eje
  - Entrenar **Random Forest** y **SVM** con estas features
  - Evaluar con LOSO (Leave-One-Subject-Out)
  - Reportar accuracy y F1-macro en tabla comparativa

  > Si RF/SVM supera el 90 %, la CNN necesita otro argumento (latencia, escalabilidad). Si está en 80–85 %, la CNN tiene margen claro.

---

## Día 3 — Modelo 1D-CNN

- [ ] **A3** `notebooks/03_har_training.ipynb`:

  **Arquitectura (cubre V2):**
  ```python
  # Input: (batch, 128, 6)
  Conv1D(64, kernel_size=3, activation='relu', padding='same')
  BatchNormalization() → MaxPooling1D(2)
  Conv1D(128, kernel_size=3, activation='relu', padding='same')
  BatchNormalization() → MaxPooling1D(2)
  Conv1D(128, kernel_size=3, activation='relu', padding='same')
  BatchNormalization()
  GlobalAveragePooling1D()
  Dense(64, activation='relu') → Dropout(0.3)
  Dense(n_classes, activation='softmax')
  ```

  **Entrenamiento:**
  - Optimizador: `Adam(lr=1e-3)` con `ReduceLROnPlateau`
  - Loss: `sparse_categorical_crossentropy`
  - Callbacks: `EarlyStopping(patience=10)`, `ModelCheckpoint`
  - Aplicar augmentation al 30 % del batch durante el entrenamiento
  - **Validación LOSO** — reportar por cada fold (cubre E2)

- [ ] **A4** Variante CNN+GRU (ablación opcional):
  - Añadir `GRU(64)` después del tercer bloque Conv1D
  - Comparar: accuracy vs nº parámetros vs latencia estimada

- [ ] **A5** Evaluación completa (E2):
  - Matriz de confusión (todas las clases)
  - F1 por clase — identificar la más difícil
  - Tabla comparativa: RF/SVM baseline vs 1D-CNN vs CNN+GRU

---

## Día 4 — Compresión TFLite y benchmark (R1, R6, V4)

- [ ] **A6** `notebooks/05_tflite_benchmark.ipynb` — cubre **R1** (on-device + tamaño modelo):

  ```python
  # Float32 baseline
  converter = tf.lite.TFLiteConverter.from_keras_model(model)
  tflite_fp32 = converter.convert()

  # Float16
  converter.optimizations = [tf.lite.Optimize.DEFAULT]
  converter.target_spec.supported_types = [tf.float16]
  tflite_fp16 = converter.convert()

  # Int8 (post-training quantization)
  converter.representative_dataset = representative_data_gen  # 100-200 muestras
  converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
  tflite_int8 = converter.convert()
  ```

  | Modelo | Tamaño (KB) | Accuracy test | Latencia (ms) |
  |--------|-------------|---------------|---------------|
  | Keras fp32 | — | — | — |
  | TFLite fp32 | | | |
  | TFLite fp16 | | | |
  | TFLite int8 | | | |

- [ ] **A7** Estimación de consumo de batería — cubre **R6**:
  - Ciclo de inferencia: 1 ventana cada 2 s (duty-cycling)
  - CPU utilization estimada: ~2 % en ARM Cortex-A55 moderno
  - Consumo: < 5 mW promedio en segundo plano
  - Comparación: GPS continuo ≈ 100 mW → la inferencia on-device añade < 5 % de lo que añade el GPS
  - **Conclusión para la memoria: asumible para el usuario**

- [ ] **A8** Guardar artefactos:
  - `models/tflite/har_model_fp16.tflite`
  - `models/tflite/har_model_int8.tflite` ← **éste es el que Jaime integrará en la app**
  - Documentar la elección del modelo preferido y por qué

---

## Día 5 — Validación con datos propios (V5)

- [ ] **A9** Recoger datos del teléfono:
  1. Instalar **Phyphox** (iOS/Android, gratuito) o **Sensor Logger**
  2. Registrar ~5 min de cada actividad: caminar, correr (si posible), bajar/subir escaleras, sentado
  3. Exportar CSV con `accel_x, accel_y, accel_z, gyro_x, gyro_y, gyro_z, timestamp`
  4. Procesar con `windowing.py` (resample a 50 Hz, ventanas de 128)
  5. Inferir con `har_model_int8.tflite` y reportar resultados

- [ ] **A10** Análisis de errores con datos propios:
  - ¿En qué actividades falla el modelo?
  - ¿Diferencia bolsillo vs mano vs sobre la mesa?
  - Documentar observaciones — añaden credibilidad al pitch ante los jueces

---

## Día 6 — Memoria: secciones de Íñigo

- [ ] **A11** Sección 1: Contexto y datasets — tabla de datasets elegidos, justificación vs DSADS
- [ ] **A12** Sección 2: Preprocesado y ventaneo — módulo, 2.56 s @50 Hz, SVM, augmentation como estrategia de datos sintéticos y robustez de colocación (R2 + M2 cubiertos)
- [ ] **A13** Sección 3: Arquitectura del modelo HAR — 1D-CNN, tabla de alternativas justificada (V2)
- [ ] **A14** Sección 4: Evaluación — LOSO, matriz de confusión, comparativa con baseline (E2)
- [ ] **A15** Sección 5: Compresión y viabilidad on-device — tabla TFLite, estimación batería (R1, R6, V4, E3)

---

## Checklist de entrega — Íñigo

| Artefacto | Estado |
|-----------|--------|
| `src/preprocessing/windowing.py` (con augmentation) | [ ] |
| `notebooks/01_eda_activities.ipynb` | [ ] |
| `notebooks/03_har_training.ipynb` | [ ] |
| `notebooks/05_tflite_benchmark.ipynb` | [ ] |
| `models/tflite/har_model_int8.tflite` | [ ] |
| `models/tflite/har_model_fp16.tflite` | [ ] |
| Secciones 1–5 de la memoria | [ ] |
| CSV datos propios + análisis | [ ] |

---

## Skills útiles para Íñigo

| Skill | Cuándo |
|-------|--------|
| `/research` | Buscar papers de benchmarks HAR ligeros (MobileNet-IMU, TinyML) |
| `/verify` | Verificar que los papers de UCI HAR y MotionSense que cites son fiables |
| `/bug-finder` | Revisar el código del pipeline de preprocesado |
| `/code-review` | Antes de mergear a main |
| `/loop` | Monitorizar entrenamientos largos (>30 min) |
| `/find-skills` | Si necesitas una skill de ML/data-science que no está instalada |
