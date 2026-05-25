# Plan Global — Caso 06: Vitalia Health Insurance
## HAR on-device + Detección de Caídas

**Entrega:** ~31 mayo 2026 | **Equipo:** Íñigo S + Jaime | **Rival (mismo caso):** Santi-Sheimae
**Jurado:** compañeros de clase (rol de cliente) · Valoran: precio, robustez, ajuste al contexto

> **Alcance de fase 1:** actividad física + caídas. El contexto del enunciado menciona "dormir mejor" — el seguimiento de sueño está **fuera del alcance** de esta fase y no se implementa.

---

## 0. Matriz de trazabilidad de requisitos del enunciado

Esta tabla mapea cada requisito explícito del enunciado a la sección o tarea que lo cubre. Garantiza cobertura total.

| Requisito | Tipo | Sección / Tarea | Responsable |
|-----------|------|-----------------|-------------|
| Clase: estático (sentado/parado) | Funcional | §2 + datasets UCI HAR | Íñigo |
| Clase: caminando | Funcional | §2 + datasets UCI HAR | Íñigo |
| Clase: corriendo | Funcional | PAMAP2/WISDM + A3 | Íñigo |
| Clase: ciclismo (bici real) | Funcional | PAMAP2 + A3 | Íñigo |
| Clase: subir/bajar escaleras | Funcional | UCI HAR + A3 | Íñigo |
| Detección de caídas (segmento 65+) | Funcional | §4.3 + B1–B6 + SisFall | Jaime |
| R1: modelo on-device (sin stream) + razonar tamaño | Técnico | §4.4 compresión + A6–A7 | Íñigo |
| R2: robustez variabilidad colocación (bolsillo/mano/brazalete/bolso) | Técnico | §4.1 preprocesado + augmentation + A-aug | Íñigo |
| R3: RGPD — qué datos, dónde, cuánto tiempo | Legal | §5 tabla RGPD + B8 | Jaime |
| R4: trade-off FN/FP caídas — razonar y gestionar | Crítico | §4.3 + B4–B5 + curva PR | Jaime |
| R5: datasets públicos de accel/gyro | Datos | §3 + A-datos + B-datos | Ambos |
| R6: estimar consumo batería + asumible | Técnico | §4.4 estimación batería + A7 | Íñigo |
| E1: modelo funcional (input ventana → clasifica + caídas) | Entregable | notebooks A3 + B3 + modelos .tflite | Ambos |
| E2: demostrar sobre datos de test | Entregable | evaluación LOSO + métricas A5 + B4 | Ambos |
| E3: razonar viabilidad despliegue móvil | Entregable | §4.4 TFLite benchmark + A6 | Íñigo |
| E4: arquitectura producción teórica + estimar coste | Entregable | §5 + B7 + B9 (CapEx+OpEx) | Jaime |
| V1: ventaneo/preprocesado + justificación | Valorado | §4.1 + S0-3 + A12 memoria | Íñigo |
| V2: arquitectura NN + por qué vs alternativas | Valorado | §4.2 tabla alternativas + A3 + A13 | Íñigo |
| V3: trade-off FP/FN explícito | Valorado | §4.3 + B4 curva PR + B16 memoria | Jaime |
| V4: decisiones modelo ligero para móvil | Valorado | §4.4 + A6 cuantización + A7 batería | Íñigo |
| V5: validación con datos propios (móviles estudiantes) | Valorado | A9–A10 + B13 | Ambos |
| V6: caídas = sub-problema binario documentado | Valorado | §4.3 justificación + B3 + B15 | Jaime |
| M2: datos públicos / scraping / sintéticos | Método | §3 datasets + §3.bis augmentation | Ambos |
| M3: MVP funcional + arquitectura teórica | Método | app Flutter + notebooks + §5 | Ambos |
| M4: estimar coste de construir + mantener | Método | §5 coste CapEx + OpEx + B9 | Jaime |

---

## 1. Objetivo y criterios de evaluación

Construir un **prototipo MVP funcional** (demo + modelo funcionando) más una **arquitectura de producción teórica** lo suficientemente detallada para estimar coste real. Los jueces valoran:
- **Precio** — coste de construir y mantener la solución.
- **Robustez** — que el sistema funcione en condiciones reales.
- **Ajuste al contexto** — que las decisiones tengan sentido para una aseguradora española con 180k asegurados.

---

## 2. Problema a resolver

Vitalia tiene fraude del ~35 % en autoregistro de actividad física. Queremos inferir automáticamente la actividad desde el acelerómetro + giroscopio del smartphone **on-device** (sin stream continuo a la nube), clasificando:

| Clase | Dataset fuente |
|-------|----------------|
| Estático (sentado/parado) | UCI HAR, MotionSense |
| Caminando | UCI HAR, MotionSense |
| Corriendo | PAMAP2, WISDM |
| Ciclismo (bicicleta real) | PAMAP2 |
| Subiendo/bajando escaleras | UCI HAR |
| **Caída** (sub-problema binario) | MobiAct v2, SisFall |

---

## 3. Datasets — justificación frente a DSADS

### ¿Por qué NO el dataset del enunciado (DSADS #256)?
| Problema | Impacto |
|----------|---------|
| 5 unidades Xsens en el cuerpo — NO smartphone | No aplica para inferencia on-device |
| Solo 25 Hz | Bajo para señales de impacto (caídas) |
| Solo 8 sujetos | Generalización muy limitada |
| Sin caídas | No cubre el requisito principal |
| Ciclismo en bici estática (A15/A16) | No aplica a ciclismo real |

> DSADS se puede usar como dataset auxiliar opcional, pero no como primario.

### Datasets seleccionados

| Uso | Dataset | Sensores | Hz | Notas |
|-----|---------|----------|----|-------|
| **Actividades (base)** | UCI HAR #240 | Accel+Gyro — smartphone cintura | 50 | Walk, upstairs, downstairs, sit, stand, lay |
| **Actividades (robustez)** | MotionSense | Accel+Gyro — smartphone bolsillo | 50 | Mismo placement que el target — clave para invarianza |
| **Running + Cycling** | PAMAP2 #231 | Accel+Gyro body-worn | 100 → 50 | Resamplear a 50 Hz |
| **Caídas (primario)** | MobiAct v2 | Accel+Gyro — smartphone bolsillo | ~87 → 50 | 4 tipos de caída + 12 ADL |
| **Caídas (ancianos)** | SisFall | Accel+Gyro (cintura) | 200 → 50 | Único con 15 sujetos ancianos (60–75 años) |
| **Validación propia** | Teléfonos equipo | Smartphone nativo | Nativo | Phyphox / Sensor Logger |

### Estrategia de unificación
1. **Resamplear todo a 50 Hz.**
2. **Normalizar unidades** → todos en *g* (1 g = 9.81 m/s²).
3. **Invarianza de placement:** SVM + augmentation (ver §3.bis).

### 3.bis — Estrategia de datos sintéticos / augmentation (cubre M2 del enunciado)

El enunciado permite "generación sintética" como fuente de datos. La aplicamos en dos frentes:

**Para robustez de colocación (R2):**
| Técnica | Qué simula |
|---------|------------|
| Rotación/permutación de ejes (x↔y↔z) | Diferentes orientaciones del teléfono (mano, bolsillo, brazalete) |
| Ruido gaussiano (σ = 0.01 g) | Variabilidad del sensor entre dispositivos |
| Escalado de magnitud (×0.8 – ×1.2) | Sensores con diferente sensibilidad |
| Time-warping (±10 % duración) | Variabilidad de ritmo individual |

**Para clase caída (muy desequilibrada):**
| Técnica | Dónde |
|---------|-------|
| SMOTE en espacio de features | Balance clases en dataset de entrenamiento |
| `class_weight` en entrenamiento | Penalizar FN en la loss function |
| Augmentation de ventanas de caída | Multiplicar ejemplos de caída con las técnicas anteriores |

---

## 4. Arquitectura técnica

### 4.1 Preprocesado y ventaneo (módulo compartido)

```
Sensor raw (accel xyz + gyro xyz @ 50 Hz)
    ↓ Filtro paso-bajo (Butterworth 20 Hz) — elimina ruido
    ↓ Normalización por sujeto (media 0, std 1)
    ↓ Sliding window: 128 muestras (2.56 s), solapamiento 50 %
    ↓ Features: señal bruta + SVM + energía por eje + cruce por cero
    ↓ Data augmentation (rotación, ruido, time-warp, magnitude-scale)
    → Tensor [N, 128, 6] para el modelo
```

**Justificación de 128 muestras @50 Hz:** convención de UCI HAR (reproduce benchmark), capta ≥2 ciclos de paso/pedaleo y aporta contexto suficiente a la CNN sin coste excesivo.

Para caídas: detección de pico de impacto (SVM > umbral g) → ventana 100 muestras (2 s pre+post impacto) → clasificador binario.

### 4.2 Modelo HAR — 1D-CNN

**Arquitectura elegida:** 1D-CNN con 3 bloques convolucionales + Global Average Pooling + cabeza densa.

```
Input [128, 6]
  → Conv1D(64, k=3, relu) → BatchNorm → MaxPool(2)
  → Conv1D(128, k=3, relu) → BatchNorm → MaxPool(2)
  → Conv1D(128, k=3, relu) → BatchNorm
  → GlobalAveragePooling1D
  → Dense(64, relu) → Dropout(0.3)
  → Dense(6, softmax)
```

| Alternativa | Por qué no elegirla |
|-------------|---------------------|
| RF/SVM sobre features manuales | Requiere ingeniería de features manual; peor con datos crudos; más difícil de actualizar |
| LSTM puro | Mayor latencia on-device, convergencia más lenta, accuracy similar a la CNN |
| CNN+LSTM híbrido | +30 % parámetros — se evalúa como ablación pero no es el primario |
| Transformer | Excelente accuracy pero demasiado pesado para TFLite on-device |

**Validación:** Leave-One-Subject-Out (LOSO) para medir generalización real por sujeto.

### 4.3 Detección de caídas — modelo binario independiente

Tratar caídas como sub-problema binario (no 7ª clase) porque:
- La clase caída está muy desequilibrada respecto al total de ventanas.
- El coste de FN (no detectar una caída en un anciano) >> coste de FP (alarma falsa).
- Umbrales de decisión distintos a los de clasificación de actividad.

**Trade-off FP/FN (V3 del enunciado):**

```
FN (no detecta caída real)  →  anciano sin asistencia  →  consecuencias GRAVES
FP (alarma sin caída)       →  desconfianza del usuario →  baja adopción
```

Estrategia:
1. **Cascada de dos etapas:** detector de impacto basado en umbral SVM (siempre activo, muy barato en batería) → solo si hay pico, activa el clasificador CNN para confirmar.
2. **Optimización de threshold:** maximizar recall a precision ≥ 0.85. Reportar curva Precision-Recall con 3 puntos de operación (conservador/65+, equilibrado, estricto).
3. **Ventana de confirmación (post-fall):** 30 s de inmovilidad post-impacto refuerza la alerta.
4. **Prompt "¿Estás bien?":** antes de escalar a contacto de emergencia → reduce FP sin aumentar FN.

### 4.4 Compresión para on-device (R1, V4 del enunciado)

| Técnica | Resultado esperado |
|---------|--------------------|
| Conversión TFLite | Baseline |
| Cuantización float16 | ~2× reducción tamaño, <1 % pérdida accuracy |
| Cuantización int8 (post-training) | ~4× reducción, <2 % pérdida |
| Pruning (opcional) | Sparsidad 50 %, combinable con cuantización |

**Objetivo:** modelo HAR < 500 KB + modelo caídas < 200 KB. Latencia < 50 ms por ventana.

**Estimación batería (R6 del enunciado):**
- Inferencia ARM Cortex-A55 a 2 s de ciclo ≈ < 5 mW promedio en segundo plano.
- Comparación: GPS continuo ≈ 100 mW. Inferencia on-device es < 5 % del coste del GPS.
- **Conclusión: asumible para el usuario** (< 1 % batería/hora adicional).

---

## 5. Arquitectura de producción (E4 + M4 del enunciado)

```
┌─────────────────────────────────────────────────────┐
│                  SMARTPHONE (on-device)              │
│  Accel+Gyro → Preprocessor → HAR model (TFLite)    │
│                            → Fall detector (TFLite)  │
│                                                      │
│  Solo eventos derivados salen del dispositivo:       │
│  { activity: "walking", duration_min: 15 }           │
│  { event: "fall_detected" }                          │
└───────────────────┬─────────────────────────────────┘
                    │ HTTPS + TLS 1.3 + JWT
                    ▼
┌─────────────────────────────────────────────────────┐
│              BACKEND SERVERLESS (AWS)                │
│  API Gateway → Lambda: validar + ingestar eventos    │
│             → DynamoDB: VitaPoints ledger            │
│             → SNS/SQS: pipeline alertas caída        │
│                  → Lambda: notificación push         │
│                  → Lambda: llamada centralita (65+)  │
│  S3 Model Registry → OTA model updates → app        │
│  SageMaker: pipeline de reentrenamiento              │
│  CloudWatch: monitoring drift + FPR en producción   │
└─────────────────────────────────────────────────────┘
```

### Gobernanza RGPD (Art. 9 — datos de salud) — tabla explícita

| Dato | Dónde se almacena | Cuánto tiempo | Protección |
|------|-------------------|---------------|------------|
| Señal cruda accel/gyro | **On-device, RAM** | < 10 s (ventana activa) | **Nunca sale del dispositivo** |
| Eventos de actividad (tipo, duración) | Backend — DynamoDB | **2 años** (scoring VitaPoints) | Pseudonimizado por `user_id` hash |
| Alertas de caída | Backend — DynamoDB | **90 días** | Acceso restringido a centralita |
| Datos propios cedidos para reentrenamiento | Backend (solo con consent. explícito) | Hasta revocación del consentimiento | Anonimizados antes del ingesta |

**Cumplimiento:**
- Consentimiento explícito en onboarding, separado para alertas de emergencia.
- **DPIA** obligatoria (tratamiento a escala de datos de salud, Art. 9).
- Derecho al olvido: endpoint `DELETE /users/{id}/events`.
- Cumplimiento por diseño: los datos crudos del sensor nunca abandonan el dispositivo.

### Modelo de coste (M4 del enunciado)

**CapEx — coste de construcción (one-time)**

| Rol | Esfuerzo | Coste estimado (100 €/h júnior) |
|-----|----------|---------------------------------|
| Data engineering (descarga, limpieza, pipeline) | 3 persona-semanas | ~6.000 € |
| Modelado ML (HAR + fall detector + cuantización) | 4 persona-semanas | ~8.000 € |
| Mobile dev (Flutter + TFLite + sensores) | 3 persona-semanas | ~6.000 € |
| Backend serverless (API, alertas, OTA, monitoring) | 4 persona-semanas | ~8.000 € |
| Legal / DPIA | 1 persona-semana | ~2.000 € |
| QA + pruebas en campo | 2 persona-semanas | ~4.000 € |
| **Total CapEx** | **17 persona-semanas** | **~34.000 €** |

**OpEx — coste de operación y mantenimiento (mensual, 180k usuarios)**

| Componente | Coste/mes |
|------------|-----------|
| Backend serverless (Lambda + DynamoDB + API GW) | ~400 € |
| Model OTA (S3 + CloudFront) | ~50 € |
| Monitoring + alertas (CloudWatch + SNS) | ~100 € |
| Training trimestral (GPU cloud p3.2xlarge ~4h) | ~17 € amortizado/mes |
| **Total OpEx** | **~567 €/mes** |

**ROI:** si el sistema reduce la siniestralidad activa un 0.5 % en 180k asegurados → ahorro >> CapEx en año 1 y > 10× el OpEx mensual.

**Comparativa:** solución de terceros (API de reconocimiento de actividad) costaría >5.000 €/mes Y transfiere datos de movimiento al proveedor (incompatible con Art. 9 RGPD).

---

## 6. Reparto de tareas

| | Íñigo | Jaime |
|--|-------|-------|
| **Foco** | Modelo HAR (6 clases) + compresión móvil | Fall detector + arquitectura producción + app Flutter |
| **Datasets** | UCI HAR, MotionSense, PAMAP2/WISDM | MobiAct v2, SisFall |
| **Modelo** | 1D-CNN actividades → TFLite + cuantización | CNN binario caídas → TFLite + threshold tuning |
| **Demo** | Entrega los .tflite a Jaime | Integra ambos modelos en la app Flutter |
| **Memoria** | Secciones 1–5: datasets, preprocesado, HAR, evaluación, benchmark | Secciones 6–10: caídas, FP/FN, arquitectura, RGPD, coste |

**Sprint-0 (Día 1 — AMBOS):** entorno Python, módulo de preprocesado compartido, windowing, descarga datasets.
*(Repo, requirements.txt, estructura de carpetas y skills ya configurados — ver checklist "Ya hecho" en cada archivo de tareas.)*

**Punto de integración (Día 5):** Íñigo entrega `models/tflite/har_model_int8.tflite` a Jaime para la app.

Ver detalles en `docs/TAREAS_INIGO.md` y `docs/TAREAS_JAIME.md`.

---

## 7. Cronograma

| Día | Fecha | Íñigo | Jaime |
|-----|-------|-------|-------|
| 1 | Lun 25/05 *(hoy)* | **Sprint-0:** venv, windowing.py, descargar UCI HAR + MotionSense | **Sprint-0 compartido** + descargar MobiAct + SisFall |
| 2 | Mar 26/05 | EDA actividades + baseline RF/SVM | EDA caídas + baseline binario |
| 3 | Mié 27/05 | 1D-CNN actividades — entrenar + evaluar LOSO | CNN fall detector + curva PR + análisis FP/FN |
| 4 | Jue 28/05 | TFLite + cuantización + benchmark batería | Arquitectura producción + coste CapEx/OpEx + shell Flutter |
| 5 | Vie 29/05 | Validación datos propios + ajuste fino | Integración modelos en app + validación datos propios |
| 6 | Sáb 30/05 | Memoria secciones 1–5 + slides técnica | Memoria secciones 6–10 + slides pitch cliente |
| 7 | Dom 31/05 | Revisión conjunta + ensayo pitch | ← mismo |

---

## 8. Entregables finales

- [ ] `notebooks/01_eda_activities.ipynb`
- [ ] `notebooks/02_eda_falls.ipynb`
- [ ] `notebooks/03_har_training.ipynb`
- [ ] `notebooks/04_fall_detection.ipynb`
- [ ] `notebooks/05_tflite_benchmark.ipynb`
- [ ] `models/tflite/har_model_int8.tflite`
- [ ] `models/tflite/fall_model_int8.tflite`
- [ ] `app/` — Flutter app con inferencia on-device funcional
- [ ] `docs/MEMORIA.pdf` — Memoria técnica completa (ES)
- [ ] Presentación (slides) para el jurado

---

## 9. Estrategia para los jueces y ventaja competitiva vs Santi-Sheimae

**Argumento precio:**
- CapEx ~34k€ + OpEx ~567 €/mes (transparente, desglosado). Las alternativas de terceros cuestan 10× más en OpEx y sin privacidad on-device.

**Argumento robustez:**
- LOSO cross-validation demuestra generalización real. Datos de nuestros propios móviles validan en condiciones reales (distintos teléfonos, colocaciones).
- Cascada de caídas con prompt "¿estás bien?" demuestra que el equipo pensó en el usuario, no solo en el modelo.

**Argumento ajuste al contexto:**
- Único grupo con dataset de **ancianos reales** (SisFall: 15 sujetos 60–75 años) — el enunciado enfatiza el segmento 65+.
- RGPD Art. 9 por diseño: señal cruda nunca sale del teléfono. La competencia que envíe datos a la nube tiene un problema legal con Vitalia.
- ROI calculado sobre las 180k pólizas reales del enunciado.

**Diferenciador on-device:**
- Sin coste de API externa de reconocimiento de actividad. Sin dependencia de terceros. Sin riesgo RGPD. El modelo se actualiza OTA sin pasar por los stores.
