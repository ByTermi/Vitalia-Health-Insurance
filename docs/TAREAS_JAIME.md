# Tareas — Jaime
## Foco: Detección de Caídas + Arquitectura de Producción + App Flutter

**Responsabilidad:** construir el detector de caídas binario, diseñar la arquitectura de producción teórica (con coste CapEx+OpEx y RGPD), e integrar ambos modelos TFLite en la app Flutter demo.

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

## Sprint-0 (Día 1 — COMPARTIDO con Íñigo)

No avanzar a las tareas individuales hasta que estos estén listos.

- [x] **S0-1** Crear el entorno Python:
  ```bash
  python -m venv .venv
  .venv\Scripts\activate   # Windows
  pip install -r requirements.txt
  ```

- [ ] **S0-3** Confirmar con Íñigo la estrategia de ventaneo (ya documentada en `docs/PLAN.md`):
  - Ventana actividades: 128 muestras (2.56 s) @50 Hz
  - Ventana caídas: 100 muestras (2 s) centrada en pico de impacto
  - Solapamiento 50 %

- [x] **S0-4** Participar en la construcción de `src/preprocessing/windowing.py` (con Íñigo):
  - Al menos: `resample()`, `sliding_window()`, `compute_svm()`

- [ ] **S0-5** Descargar datasets de Jaime:
  - **MobiAct v2:** https://bmi.hmu.gr/the-mobifall-and-mobiact-datasets-2/ → `data/raw/MobiAct/`
  - **SisFall:** https://pmc.ncbi.nlm.nih.gov/articles/PMC5298771/ → `data/raw/SisFall/`

---

## Día 2 — EDA y Baseline del Fall Detector

- [ ] **B1** `notebooks/02_eda_falls.ipynb`:
  - Visualizar señales de caídas vs ADL (actividades cotidianas)
  - Distribución temporal: impacto (pico SVM) → inmovilidad post-caída
  - Identificar umbral SVM empírico para la etapa 1 de la cascada
  - Tipos de caída (MobiAct: forward, backward, side, syncope)
  - Diferencia de señal: sujetos jóvenes (MobiAct) vs ancianos (SisFall)
  - **Desbalanceo:** ratio ADL/caídas — motivar el uso de SMOTE + class_weight

- [ ] **B2** Baseline binario:
  - Etiquetas: `1 = caída`, `0 = ADL/actividad normal`
  - Features manuales: pico SVM, energía, duración del impacto
  - Entrenar Logistic Regression y RF en LOSO
  - Reportar recall, precision, F1, AUC-ROC (énfasis en **recall**)

---

## Día 3 — Modelo de Caídas + Análisis FP/FN (R4, V3, V6)

- [ ] **B3** `notebooks/04_fall_detection.ipynb` — Modelo CNN binario:

  **Arquitectura (pequeña — caídas son transitorios):**
  ```python
  # Input: (batch, 100, 6) — ventana 2 s centrada en impacto
  Conv1D(32, kernel_size=3, activation='relu', padding='same')
  BatchNormalization() → MaxPooling1D(2)
  Conv1D(64, kernel_size=3, activation='relu', padding='same')
  BatchNormalization()
  GlobalAveragePooling1D()
  Dense(32, activation='relu') → Dropout(0.3)
  Dense(1, activation='sigmoid')
  ```

  **Manejo del desbalanceo — estrategia de datos sintéticos (M2 del enunciado):**
  - **SMOTE** en espacio de features para generar ejemplos sintéticos de caída
  - `class_weight = {0: 1.0, 1: n_ADL/n_falls}` en `model.fit()`
  - Augmentation de ventanas de caída (rotación, ruido) para multiplicar ejemplos
  > SMOTE + augmentation son la "generación sintética" que cubre M2 del enunciado para esta clase.

- [ ] **B4** **Análisis explícito del trade-off FP/FN** — cubre R4, V3:

  ```
  FN (miss a real fall)  →  anciano sin asistencia  →  consecuencias GRAVES
  FP (false alarm)       →  desconfianza del usuario →  baja adopción
  ```

  - Trazar la **curva Precision-Recall** del modelo
  - Definir 3 puntos de operación y documentarlos:
    - **Modo conservador (65+):** threshold bajo, recall ≥ 0.95, acepta más FP
    - **Modo equilibrado:** F1 máximo
    - **Modo estricto:** precision ≥ 0.90, menos alarmas falsas
  - Explicar cómo Vitalia puede configurar el modo según segmento de asegurado

- [ ] **B5** **Diseño de la cascada anti-FP** (cubre R4):
  1. **Etapa 1 — Detector de impacto** (always-on, gratis en batería):
     - `max(SVM_window) > 3g` → posible caída → activar etapa 2
  2. **Etapa 2 — Confirmador CNN:**
     - Si `sigmoid(output) > threshold` → caída confirmada
  3. **Etapa 3 — Inmovilidad post-caída (30 s):**
     - Si el usuario no se mueve → escalar alerta
  4. **Prompt "¿Estás bien?"** → reduce FP sin penalizar FN
  - Documentar el flujo en un diagrama (Mermaid o ASCII) para la memoria

- [ ] **B6** Conversión TFLite del fall detector:
  - `models/tflite/fall_model_int8.tflite` — objetivo: < 200 KB
  - Reportar accuracy / recall / precision del modelo cuantizado vs Keras original

---

## Día 4 — Arquitectura de Producción + Coste + Shell Flutter

- [ ] **B7** **Arquitectura de producción teórica** (E4) — usar `/serverless-backend` como referencia:
  - On-device: qué computa el móvil (inferencia), qué datos salen (solo eventos derivados)
  - Backend: API Gateway → Lambda → DynamoDB (VitaPoints) → SNS (alertas caída)
  - Model Registry: S3 + OTA updates (cómo se actualiza el modelo sin pasar por stores)
  - Training Pipeline: SageMaker — cuándo se reentrena, con qué datos nuevos
  - Monitoring: drift de actividad, FPR del fall detector en producción

  Generar diagrama con `/graphify` o Mermaid para la memoria.

- [ ] **B8** **Gobernanza RGPD** (R3) — usar `/legal`:

  Usar y ampliar esta tabla en la sección de la memoria:

  | Dato | Dónde se almacena | Cuánto tiempo | Protección |
  |------|-------------------|---------------|------------|
  | Señal cruda accel/gyro | On-device RAM | < 10 s | Nunca sale del dispositivo |
  | Eventos de actividad | Backend DynamoDB | 2 años | Pseudonimizado por `user_id` hash |
  | Alertas de caída | Backend DynamoDB | 90 días | Acceso restringido a centralita |
  | Datos cedidos para retraining | Backend (solo con consentimiento) | Hasta revocación | Anonimizados antes del ingesta |

  Cubrir además:
  - Datos de salud (Art. 9 RGPD) — justificar cumplimiento por diseño (on-device)
  - Consentimiento: cláusula separada para alertas de emergencia
  - **DPIA** obligatoria (tratamiento a escala)
  - Derecho al olvido: endpoint `DELETE /users/{id}/events`

- [ ] **B9** **Modelo de coste completo** (M4) — usar `/market-analysis` para contexto competitivo:

  **CapEx (construcción, one-time):**

  | Rol | Esfuerzo | Coste (100 €/h júnior) |
  |-----|----------|-----------------------|
  | Data engineering | 3 persona-semanas | ~6.000 € |
  | Modelado ML (HAR + caídas) | 4 persona-semanas | ~8.000 € |
  | Mobile dev (Flutter + TFLite) | 3 persona-semanas | ~6.000 € |
  | Backend serverless | 4 persona-semanas | ~8.000 € |
  | Legal / DPIA | 1 persona-semana | ~2.000 € |
  | QA + campo | 2 persona-semanas | ~4.000 € |
  | **Total CapEx** | **17 persona-semanas** | **~34.000 €** |

  **OpEx (operación/mes, 180k usuarios):**

  | Componente | Coste/mes |
  |------------|-----------|
  | Backend serverless | ~400 € |
  | Model OTA (S3 + CDN) | ~50 € |
  | Monitoring + alertas | ~100 € |
  | Training trimestral amortizado | ~17 € |
  | **Total OpEx** | **~567 €/mes** |

  Comparar con alternativa de API de terceros (>5.000 €/mes + problema RGPD).
  ROI: reducción siniestralidad 0.5 % → ahorro >> CapEx en año 1.

- [x] **B10** **Shell de la app Flutter** (`app/`):
  ```bash
  cd app && flutter create . --org com.vitalia --platforms android
  ```
  ```yaml
  # pubspec.yaml
  dependencies:
    tflite_flutter: ^0.10.4
    sensors_plus: ^4.0.2
    permission_handler: ^11.0.0
  ```
  Estructura mínima:
  - `lib/sensors/sensor_service.dart` — stream accel+gyro @50 Hz
  - `lib/inference/har_classifier.dart` — carga `har_model_int8.tflite` + sliding window
  - `lib/inference/fall_detector.dart` — carga `fall_model_int8.tflite` + cascada 3 etapas
  - `lib/screens/activity_screen.dart` — actividad actual + VitaPoints
  - `assets/models/` — placeholder hasta recibir los `.tflite` de Íñigo (Día 5)

---

## Día 5 — Integración y Validación con Datos Propios (V5)

- [ ] **B11** Recibir `har_model_int8.tflite` de Íñigo → añadir a `assets/models/` junto con `fall_model_int8.tflite`

- [ ] **B12** Completar la integración en la app:
  - `SensorService → windowing → HAR inference → UI`
  - `SensorService → SVM threshold → Fall CNN → alert flow`
  - Probar en dispositivo Android real (o emulador con datos de replay)

- [ ] **B13** Recoger datos del teléfono para validación (V5):
  1. Instalar **Phyphox** o **Sensor Logger**
  2. Grabar: caminar, sentado, bajar escaleras
  3. Simular una caída: dejar caer el teléfono sobre una superficie blanda con cuidado
  4. Inferir en tiempo real en la app → captura de pantalla o vídeo para la presentación

- [ ] **B14** **Fallback documental** (si la app no está al 100 %):
  - Demo alternativa: notebook Python con inferencia frame a frame sobre datos propios
  - Documentar como "trabajo futuro" en la memoria

---

## Día 6 — Memoria: secciones de Jaime

- [ ] **B15** Sección 6: Detección de caídas — sub-problema binario (justificación V6), arquitectura, cascada
- [ ] **B16** Sección 7: Trade-off FP/FN — curva PR, 3 puntos de operación, decisión de diseño (R4, V3)
- [ ] **B17** Sección 8: Arquitectura de producción — diagrama, componentes, OTA (E4)
- [ ] **B18** Sección 9: RGPD y gobernanza de datos de salud — tabla qué/dónde/cuánto (R3)
- [ ] **B19** Sección 10: Modelo de coste y ROI — CapEx + OpEx + comparativa + ROI (M4)

---

## Checklist de entrega — Jaime

| Artefacto | Estado |
|-----------|--------|
| `notebooks/02_eda_falls.ipynb` | [x] shell ready |
| `notebooks/04_fall_detection.ipynb` | [x] shell ready (run when datasets downloaded) |
| `models/tflite/fall_model_int8.tflite` | [ ] (generated by notebook 04) |
| App Flutter funcional (`app/`) | [x] shell ready (needs Flutter install + Day 5 .tflite) |
| Diagrama arquitectura de producción | [ ] |
| Secciones 6–10 de la memoria | [ ] |
| Datos propios + vídeo/capturas demo | [ ] |

---

## Skills útiles para Jaime

| Skill | Cuándo |
|-------|--------|
| `/legal` | Generar sección RGPD Art. 9 (datos de salud, DPIA, retención, consentimiento) |
| `/security` | Revisar privacidad del diseño on-device, exposición de APIs |
| `/serverless-backend` | Diseñar backend AWS serverless (Lambda, DynamoDB, SNS, OTA) |
| `/graphify` | Generar diagrama de arquitectura de producción para la memoria |
| `/market-analysis` | Modelo de coste CapEx+OpEx y análisis competitivo (Vitality, Generali) |
| `/cross-platform-dev` | Flutter + TFLite + sensors_plus — guía de integración |
| `/android-development` | Si se necesita código nativo Android para acceder a sensores |
| `/bug-finder` | Revisar el código Flutter |
| `/verify` | Verificar papers de MobiAct y SisFall antes de citar |
| `/find-skills` | Si necesitas una skill adicional no instalada |
