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

- [x] **B1** `notebooks/02_eda_falls.ipynb`:
  - Visualizar señales de caídas vs ADL (actividades cotidianas)
  - Distribución temporal: impacto (pico SVM) → inmovilidad post-caída
  - Identificar umbral SVM empírico para la etapa 1 de la cascada
  - Tipos de caída (MobiAct: forward, backward, side, syncope)
  - Diferencia de señal: sujetos jóvenes (MobiAct) vs ancianos (SisFall)
  - **Desbalanceo:** ratio ADL/caídas — motivar el uso de SMOTE + class_weight

- [x] **B2** Baseline binario:
  - Etiquetas: `1 = caída`, `0 = ADL/actividad normal`
  - Features manuales: pico SVM, energía, duración del impacto
  - Entrenar Logistic Regression y RF en LOSO
  - Reportar recall, precision, F1, AUC-ROC (énfasis en **recall**)

---

## Día 3 — Modelo de Caídas + Análisis FP/FN (R4, V3, V6)

- [x] **B3** `notebooks/04_fall_detection.ipynb` — Modelo CNN binario:

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

- [x] **B4** **Análisis explícito del trade-off FP/FN** — cubre R4, V3:

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

- [x] **B5** **Diseño de la cascada anti-FP** (cubre R4):
  1. **Etapa 1 — Detector de impacto** (always-on, gratis en batería):
     - `max(SVM_window) > 3g` → posible caída → activar etapa 2
  2. **Etapa 2 — Confirmador CNN:**
     - Si `sigmoid(output) > threshold` → caída confirmada
  3. **Etapa 3 — Inmovilidad post-caída (30 s):**
     - Si el usuario no se mueve → escalar alerta
  4. **Prompt "¿Estás bien?"** → reduce FP sin penalizar FN
  - Documentar el flujo en un diagrama (Mermaid o ASCII) para la memoria

- [x] **B6** Conversión TFLite del fall detector:
  - `models/tflite/fall_model_int8.tflite` — objetivo: < 200 KB
  - Reportar accuracy / recall / precision del modelo cuantizado vs Keras original

---

## Día 4 — Arquitectura de Producción + Coste + Shell Flutter

- [x] **B7** **Arquitectura de producción self-hosted** (E4):
  - On-device: qué computa el móvil (inferencia), qué datos salen (solo eventos derivados)
  - Backend: FastAPI → PostgreSQL (VitaPoints) + Redis → Worker → ntfy/SMTP (alertas)
  - Model Registry: MinIO + MLflow + OTA updates (sin pasar por stores)
  - Training Pipeline: local (notebooks) + MLflow — cuándo se reentrena, con qué datos
  - Monitoring: Prometheus + Grafana — drift, FPR en producción

  Repo backend separado: `../Vitalia Health Insurance Backend`
  Docs: `docs/ARQUITECTURA.md` + `ARQUITECTURA.html` (listo, ver repo backend).
  Diagrama: en `docs/arquitectura_produccion.md` y en el HTML.

  > Nota: se ha eliminado la dependencia de AWS/cloud. Backend completamente self-hosted
  > en EEE (Hetzner Frankfurt). Ventaja RGPD: sin transferencias internacionales, sin SCC.

- [x] **B8** **Gobernanza RGPD** (R3) — usar `/legal`:

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

- [x] **B9** **Modelo de coste completo** (M4) — ver `docs/modelo_coste.md`:

  **CapEx (construcción, one-time):**

  | Rol | Esfuerzo | Coste (100 €/h júnior) |
  |-----|----------|-----------------------|
  | Data engineering | 3 persona-semanas | ~12.000 € |
  | Modelado ML (HAR + caídas) | 6 persona-semanas | ~24.000 € |
  | Mobile dev (Flutter + TFLite) | 3 persona-semanas | ~12.000 € |
  | Backend self-hosted (FastAPI + Docker + Postgres) | 4 persona-semanas | ~16.000 € |
  | MLOps (MLflow + Prometheus/Grafana + OTA) | 2 persona-semanas | ~8.000 € |
  | Legal / DPIA | 1 persona-semana | ~4.000 € |
  | QA + campo | 2 persona-semanas | ~8.000 € |
  | **Total CapEx** | **21 persona-semanas** | **~84.000 €** |

  **OpEx (operación/mes, 180k usuarios — self-hosted EEE):**

  | Componente | Coste/mes |
  |------------|-----------|
  | Servidor principal (Hetzner AX42, Frankfurt) | ~75 € |
  | Servidor réplica HA | ~30 € |
  | Backups + dominio | ~7 € |
  | Ops/sysadmin (0.1 FTE) | ~400 € |
  | **Total OpEx** | **~512 €/mes** |

  Comparar con alternativa de API de terceros (>5.000 €/mes + problema RGPD + sin soberanía de datos).
  ROI: reducción siniestralidad → ahorro >> CapEx en año 1. Break-even < 1 semana tras lanzamiento.

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

## Sprint 2 — Mejoras v2: Altitud + Anti-FP + Suavizado

> **Contexto:** el modelo distingue bien las actividades en general, pero (1) al caminar un paso fuerte puede disparar la cascada de caída (falso positivo) y (2) el HAR parpadea entre walking/upstairs/downstairs sin suavizado temporal. La solución común es añadir señal de altitud (barómetro + fallback accel).

### Sincronización con Íñigo antes de empezar

**Sync 1:** acordar la firma exacta de `AltitudeService` (nombres de métodos, unidades, signo de velocidad vertical) antes de que Íñigo integre el gate de altitud en `har_classifier.dart`.

---

- [ ] **J-1** `app/lib/sensors/altitude_service.dart` — **AltitudeService** (infra compartida)
  - Suscribirse a `barometerEventStream()` de sensors_plus v7; si el móvil no tiene barómetro, `hasBarometer` queda `false`.
  - Barómetro: calibrar `P0` con las primeras 20 lecturas; convertir presión → altitud con fórmula barométrica; mantener buffer circular de 200 lecturas.
  - Fallback (sin barómetro): low-pass del accel bruto → vector de gravedad → proyectar `linear_accel` sobre el eje vertical → buffer de aceleración vertical.
  - API pública (acordada en Sync 1):
    - `bool get hasBarometer`
    - `double get verticalVelocityMs` — m/s firmado (+ = subir, − = bajar)
    - `double altitudeDeltaOverLastSamples(int n)` — metros netos en las últimas n muestras
    - `void addSample(SensorSample sample)` — necesario para el fallback accel
    - `void start()` — suscribe al barómetro si existe
    - `void stop()`
  - Umbrales (constantes anotadas, calibrar con datos reales si hace falta): stairs gate `|Δh| < 0.25 m` → plano; fall gate `Δh < −0.3 m` o `vVert < −1.0 m/s`.

- [ ] **J-2** `app/lib/inference/fall_detector.dart` — gate de altitud en la cascada
  - Modificar `analyze()` para aceptar `double? altitudeDeltaM` y `double? verticalVelocityMs`.
  - Nuevo Stage 2.5 (entre CNN y inmovilidad): si el CNN supera el umbral PERO no hay caída de altitud significativa (`altitudeDeltaM > −0.3` y `verticalVelocityMs > −1.0`), el resultado se queda en `triggeredStage = 2` sin escalar a alerta.
  - Si `altitudeDeltaM == null` (sin servicio o sin barómetro + fallback poco fiable) → comportamiento actual intacto (no empeorar recall en móviles sin sensor).
  - Documentar los umbrales como constantes anotadas (calibrar con datos reales si hace falta).

- [ ] **J-3** `app/lib/screens/activity_screen.dart` — debounce de alertas de caída
  - Añadir `DateTime? _lastFallAlertTime` + constante `_fallCooldown = Duration(seconds: 15)`.
  - En `_onSample`, antes de `_triggerFallAlert()`: comprobar que han pasado al menos `_fallCooldown` desde la última alerta.
  - Evita que ventanas consecutivas con la misma caída disparen múltiples diálogos.

- [ ] **J-4** `app/lib/inference/har_classifier.dart` — suavizado temporal (voto mayoritario)
  - Añadir buffer interno circular de los últimos 3 resultados (`List<Activity?>`).
  - `classify()` sigue devolviendo `HarResult?`, pero la `activity` devuelta es la clase mayoritaria de los últimos 3; la `confidence` es la media de confianza de esa clase.
  - Si no hay mayoría clara (empate), devolver la predicción más reciente.
  - Previene parpadeo entre walking/upstairs sin requerir reentreno.

- [x] **J-6** `app/lib/inference/fall_detector.dart` — bajar umbrales CNN (−0.05)
  - balanced: 0.70 → 0.65 · strict: 0.85 → 0.80 · conservative: intacto (0.55).
  - Guards ya implementados (altitude gate + blanking + debounce) compensan el posible aumento de FP.

- [ ] **J-7** `docs/ENTREGABLES.html` — panel de entregables ✅ **Hecho en esta sesión**
  - 6 secciones: entregables obligatorios (E1-E4), aspectos valorados (V1-V6), requisitos técnicos (R1-R6), extras vs competencia, estado de artefactos, limitaciones.

- [ ] **J-5** (bloqueado hasta I-1 de Íñigo) `app/lib/inference/har_classifier.dart` + UI — clase "Quieto"
  - Renombrar `Activity.sitting` → `Activity.stationary`, eliminar `Activity.standing`.
  - Nuevo orden enum = `['walking', 'upstairs', 'downstairs', 'stationary', 'running']` (5 clases).
  - Actualizar `_activityNames`, `_vitaPointsPerMinute`, `isActive`, iconos en `activity_screen.dart`.
  - **Dependencia:** `har_model_int8.tflite` debe tener 5 salidas en el orden correcto (tarea I-4 de Íñigo).

---

## Día 5 — Integración y Validación con Datos Propios (V5)

- [x] **B11** Recibir `har_model_int8.tflite` de Íñigo → añadir a `assets/models/` junto con `fall_model_int8.tflite`

- [ ] **B12** Completar la integración en la app:
  - `SensorService → windowing → HAR inference → UI`
  - `SensorService → SVM threshold → Fall CNN → alert flow`
  - Probar en dispositivo Android real (o emulador con datos de replay)

- [ ] **B13** Demo en dispositivo Android real (V5):
  1. `flutter run --release` en el móvil
  2. Caminar, sentarse, bajar escaleras → verificar que la app clasifica correctamente en tiempo real
  3. Simular caída (tirar el teléfono sobre superficie blanda) → verificar dialog "¿Estás bien?"
  4. Captura de pantalla o vídeo corto para la presentación al jurado

  > La app ya tiene `har_model_int8.tflite` + `fall_model_int8.tflite` cargados,
  > muestra actividad + confianza en tiempo real y gestiona el flujo de alerta completo.
  > No se necesita Phyphox ni ninguna app externa.

- [ ] **B14** **Fallback** (si el dispositivo no está disponible):
  - Grabar pantalla del emulador Android con datos de replay
  - O capturas estáticas del tab Métricas + tab Pruebas con backend conectado

---

## Día 6 — Memoria: secciones de Jaime

- [x] **B15** Sección 6: Detección de caídas — sub-problema binario (justificación V6), arquitectura, cascada
- [x] **B16** Sección 7: Trade-off FP/FN — curva PR, 3 puntos de operación, decisión de diseño (R4, V3)
- [x] **B17** Sección 8: Arquitectura de producción — diagrama, componentes, OTA (E4)
- [x] **B18** Sección 9: RGPD y gobernanza de datos de salud — tabla qué/dónde/cuánto (R3)
- [x] **B19** Sección 10: Modelo de coste y ROI — CapEx + OpEx + comparativa + ROI (M4)

---

## Checklist de entrega — Jaime

| Artefacto | Estado |
|-----------|--------|
| `notebooks/02_eda_falls.ipynb` | [x] completo — SisFall 4505 grabaciones, SVM analysis, EDA |
| `notebooks/04_fall_detection.ipynb` | [x] completo — CNN Recall 1.0, F1 0.98, TFLite 22 KB |
| `models/tflite/fall_model_int8.tflite` | [x] 22 KB, latencia 0.02ms p99 |
| App Flutter funcional (`app/`) | [x] completa — 9 endpoints integrados, OTA, VitaPoints sync, ntfy SSE, SettingsScreen RGPD |
| Diagrama arquitectura de producción | [x] en docs/arquitectura_produccion.md + Backend repo |
| Secciones 6–10 de la memoria | [x] docs/MEMORIA_JAIME.md |
| Datos propios + vídeo/capturas demo | [ ] |

---

## Skills útiles para Jaime

| Skill | Cuándo |
|-------|--------|
| `/legal` | Generar sección RGPD Art. 9 (datos de salud, DPIA, retención, consentimiento) |
| `/security` | Revisar privacidad del diseño on-device, exposición de APIs |
| `/serverless-backend` | Skill cloud-oriented (AWS/GCP/Azure) — **no aplica** al diseño self-hosted actual. Ref: docs/arquitectura_produccion.md |
| `/graphify` | Generar diagrama de arquitectura de producción para la memoria |
| `/market-analysis` | Modelo de coste CapEx+OpEx y análisis competitivo (Vitality, Generali) |
| `/cross-platform-dev` | Flutter + TFLite + sensors_plus — guía de integración |
| `/android-development` | Si se necesita código nativo Android para acceder a sensores |
| `/bug-finder` | Revisar el código Flutter |
| `/verify` | Verificar papers de MobiAct y SisFall antes de citar |
| `/find-skills` | Si necesitas una skill adicional no instalada |
