# Memoria Técnica — Secciones Jaime (§6–10)

**Caso:** Vitalia Health Insurance — HAR on-device + Detección de Caídas
**Autor:** Jaime · Equipo Íñigo + Jaime

---

## §6 · Detección de Caídas — Sub-problema Binario (V6)

### 6.1 Por qué un sub-problema binario independiente

La detección de caídas no puede tratarse como una clase más en el clasificador HAR multiclase (5 clases: walking, upstairs, downstairs, stationary, running) por tres razones:

**1. Desbalanceo extremo.**
En cualquier dataset de vida real, las caídas son eventos raros. En SisFall: 3.984 ventanas de caída frente a 49.608 de ADL (ratio 1:12,5). Un softmax de 7 clases colapsa la clase minoritaria sin técnicas específicas; un modelo binario dedicado puede aplicar class_weight y SMOTE sin interferir con el resto de clases.

**2. Asimetría de coste FN/FP.**
Para el sub-problema HAR, un error de clasificación entre "walking" y "stairs_up" tiene coste mínimo (error en VitaPoints). Para caídas, un falso negativo (FN) significa que un anciano no recibe asistencia: consecuencia potencialmente grave. Esta asimetría exige optimizar recall de forma independiente, lo que es incompatible con un softmax global que comparte el umbral de decisión.

**3. Ventaneo diferente.**
Las actividades usan ventana deslizante de 128 muestras (2,56 s, 50 % solapamiento). Las caídas son eventos transitorios: se usa una ventana de 100 muestras (2 s) **centrada en el pico de impacto**, lo que maximiza la información discriminativa del momento de la caída. No es posible usar la misma estrategia de ventaneo para ambos sub-problemas.

### 6.2 Datos — SisFall (dataset principal de caídas)

Se prioriza SisFall por incluir **15 sujetos ancianos reales (60–75 años)**, el segmento crítico 65+ del enunciado. MobiAct v2 (66 sujetos, smartphone bolsillo) queda como ampliación futura para robustez de colocación (actualmente no adquirido — requiere solicitud formal al grupo BMI de HMU).

| Parámetro | Valor |
|-----------|-------|
| Sujetos | 38 (23 adultos jóvenes SA01–SA23; 15 ancianos SE01–SE15) |
| Frecuencia | 200 Hz → resampling a 50 Hz |
| Factor conversión accel | `(2 × 16) / 2^13` g/bit (ADXL345, ±16g, 13 bits) |
| Factor conversión gyro | `(2 × 2000) / 2^16` °/s/bit (ITG3200, ±2000°/s) |
| Tipos de caída | 15 (F01–F15): resbalones, tropezones, síncopes, caídas sentándose |
| ADL | 19 tipos (D01–D19): caminar, sentarse, escaleras, etc. |
| Ventanas totales extraídas | 53.592 (3.984 caídas, 49.608 ADL) |

**Observación clave sobre ancianos:** Los sujetos SE (60–75 años) presentan picos SVM de caída medianamente menores que los adultos jóvenes SA. El umbral de 3g es conservador para el segmento 65+; el sistema permite configurar un umbral inferior para este segmento sin modificar el modelo CNN.

### 6.3 Arquitectura del modelo CNN binario

```
Input: (batch, 100, 6)  — ventana 2s @ 50Hz, canales [ax, ay, az, gx, gy, gz]
│
├── Conv1D(32, kernel=3, relu, padding='same')
├── BatchNormalization()
├── MaxPooling1D(2)                              → (batch, 50, 32)
│
├── Conv1D(64, kernel=3, relu, padding='same')
├── BatchNormalization()
├── MaxPooling1D(2)                              → (batch, 25, 64)
│
├── GlobalAveragePooling1D()                     → (batch, 64)
├── Dense(32, relu)
├── Dropout(0.3)
└── Dense(1, sigmoid)                            → probabilidad de caída ∈ [0, 1]

Parámetros totales: ~9.300 → TFLite INT8: 22 KB
```

**Manejo del desbalanceo (M2 del enunciado):**
- `class_weight = {0: 1.0, 1: 12.5}` en `model.fit()` — penaliza más los FN
- SMOTE sobre espacio de features (señal aplanada) → equilibra 1:1 antes del entrenamiento CNN
- Augmentation de ventanas de caída: rotación de ejes, ruido gaussiano, time-warping (×3 por ventana)

**Resultados (validación holdout 20% tras SMOTE):**

| Modelo | Recall | Precision | F1 | AUC-ROC |
|--------|--------|-----------|-----|---------|
| Logistic Regression (LOSO) | 0.85 | 0.22 | 0.36 | 0.88 |
| Random Forest (LOSO) | 0.81 | 0.87 | 0.84 | 0.99 |
| **CNN (val holdout)** | **1.000** | **0.953** | **0.976** | — |
| TFLite INT8 | 1.000 | 0.965 | 0.982 | — |

### 6.4 Cascada anti-FP de 3 etapas (B5)

```
┌─────────────────────────────────────────────────────────────────────┐
│  STAGE 1: SVM Threshold Detector  (always-on, < 1 mW adicional)    │
│  max(SVM sobre ventana 2s) > 3g?                                    │
└──────────────────┬──────────────────────────────────────────────────┘
                   │ YES                       NO → descartar
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│  STAGE 2: CNN Confirmer  (activado bajo demanda — on-demand)        │
│  sigmoid(output) > umbral_modo?                                     │
│    Conservador (65+): umbral 0.30 → recall ≥ 0.95                  │
│    Equilibrado:       umbral 0.50 → F1 máximo                       │
│    Estricto:          umbral 0.70 → precision ≥ 0.90               │
└──────────────────┬──────────────────────────────────────────────────┘
                   │ YES
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│  STAGE 3: Inmovilidad post-caída (30 s de monitorización)          │
│  Varianza de SVM baja → escalar alerta                              │
└──────────────────┬──────────────────────────────────────────────────┘
                   │
                   ▼
          "¿Estás bien?" — 30 s timeout
          Sin respuesta → alerta contacto emergencia + SMTP
```

**Efecto de la cascada:**
- Stage 1 descarta el 53% de las ventanas sin activar la CNN, ahorrando batería.
- Stage 2 confirma con el modelo más preciso solo cuando hay sospecha real.
- Stage 3 + prompt ACK reduce FP sin aumentar FN: el usuario puede cancelar si está bien.

---

## §7 · Trade-off FP/FN — Curva Precision-Recall y Puntos de Operación (R4, V3)

### 7.1 La asimetría de costes

La elección del umbral de decisión no es una cuestión técnica neutral: es una **decisión de negocio** con consecuencias directas sobre el asegurado.

| Tipo de error | Descripción | Consecuencia |
|---------------|-------------|--------------|
| **FN — Falso Negativo** (caída no detectada) | El sistema no genera alerta | Anciano sin asistencia → riesgo vital; responsabilidad potencial de Vitalia |
| **FP — Falso Positivo** (alarma falsa) | Alerta enviada sin caída real | Desconfianza del usuario → desinstalación; mala experiencia familiar |

No existe un umbral universalmente correcto: la elección depende del **segmento de asegurado**.

### 7.2 Curva Precision-Recall

La curva PR sintetiza el trade-off entre precision (= 1 − tasa FP) y recall (= 1 − tasa FN) en todos los umbrales posibles:

- **Average Precision (AP): > 0.98** — el modelo discrimina caídas de ADL con alta fiabilidad
- La curva se mantiene alta en la zona recall ∈ [0.80, 1.00], lo que indica que el modelo puede configurarse agresivamente (recall ≥ 0.95) sin colapsar la precision por debajo de 0.70

### 7.3 Los tres puntos de operación (V3)

| Modo | Umbral CNN | Recall (estimado) | Precision (estimado) | Perfil de asegurado |
|------|-----------|-------------------|---------------------|---------------------|
| **Conservador (65+)** | 0.30 | ≥ 0.95 | ~0.70 | Anciano con riesgo elevado de caída; prioridad absoluta: no perder ningún evento |
| **Equilibrado** | 0.50 | ~0.88 | ~0.85 | Adulto activo 45–65; balance entre sensibilidad y falsas alarmas |
| **Estricto** | 0.70 | ~0.75 | ≥ 0.90 | Usuario joven activo; prefiere pocas alarmas aunque alguna caída menor no se detecte |

**Configuración por Vitalia:** el modo se asigna automáticamente al perfil de la póliza (segmento de edad, historial médico) o puede ser ajustado por el asegurado o su médico de cabecera. El umbral no requiere reentrenar el modelo: es un parámetro de inferencia en la app Flutter.

### 7.4 La cascada como solución de ingeniería al trade-off

En lugar de elegir un único umbral global, la cascada de 3 etapas actúa como un **filtro progresivo** que:
1. Nunca pierde un impacto real (Stage 1 con umbral bajo 3g).
2. Confirma con el modelo CNN (Stage 2 — configurable por segmento).
3. Añade el factor humano: el usuario puede cancelar la alerta en 30 s (Stage 3 + prompt ACK).

El FP se reduce en Stage 3 sin afectar al recall del Stage 2. El FN solo ocurre si la caída no genera un pico SVM > 3g (caídas controladas lentas, que son las de menor riesgo).

---

## §8 · Arquitectura de Producción — Self-hosted (E4)

### 8.1 Principio de diseño: on-device first

El diseño parte de una restricción no negociable: **la señal cruda de los sensores nunca abandona el dispositivo** (RGPD Art. 9, datos de salud). Toda la inferencia se ejecuta en el smartphone; solo los eventos derivados (tipo de actividad, duración, alertas de caída) viajan al backend.

### 8.2 Diagrama de arquitectura

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SMARTPHONE (ON-DEVICE)                          │
│                                                                      │
│  Accel+Gyro @50 Hz                                                   │
│       │                                                              │
│       ▼                                                              │
│  SlidingWindowBuffer                                                 │
│  ├─► Stage 1: SVM > 3g? ─────► FallDetector CNN ──► Alert Flow      │
│  └─► HarClassifier CNN ──────────────────────────► VitaPoints UI    │
│                                                                      │
│  RAW SIGNAL NEVER LEAVES DEVICE  (RGPD Art. 9)                      │
│  Solo salen: {activity, duration_s}   {fall_alert}                  │
└─────────────────────────────┬────────────────────────────────────────┘
                              │ HTTPS + TLS 1.3 + JWT (eventos derivados)
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│          BACKEND SELF-HOSTED (EEE — Hetzner Frankfurt)              │
│                                                                      │
│  FastAPI (uvicorn)                                                   │
│  ├─► POST /events/activity  ─► PostgreSQL (vitapoints_ledger)       │
│  ├─► POST /events/fall      ─► Redis (cola alertas)                 │
│  ├─► POST /events/fall/{id}/ack  ─► cancela alerta                  │
│  ├─► GET  /models/latest    ─► MinIO (model registry)               │
│  └─► DELETE /users/{id}/data ─► derecho al olvido (Art. 17)         │
│                                                                      │
│  Redis ──► Worker ──► espera 30s ACK                                 │
│                   ├─► ntfy push (contacto emergencia)               │
│                   └─► SMTP email (respaldo)                         │
└─────────────────────────────┬────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       ML OPS PIPELINE                               │
│                                                                      │
│  Entrenamiento local (notebooks) → validación LOSO                  │
│  recall ≥ 0.95 AND size < 500 KB AND latency < 50ms                 │
│  MLflow: registro de modelo + métricas                              │
│  MinIO 'models': har_model_int8_v{N}.tflite                         │
│  App: GET /models/latest → OTA → swap en siguiente arranque         │
│  Rollback: FPR > 0.10 en 48h → versión anterior en MinIO           │
│                                                                      │
│  Monitoring: Prometheus (scrape /metrics) + Grafana                 │
│  ├─► fall_fpr · activity_drift · api_latency_p99                   │
└─────────────────────────────────────────────────────────────────────┘
```

### 8.3 Servicios del backend (docker-compose, 9 servicios)

| Servicio | Puerto | Rol |
|----------|--------|-----|
| `api` (FastAPI) | 8000 | REST: eventos, VitaPoints, OTA, RGPD delete |
| `db` (PostgreSQL 16) | 5432 | Persistencia: eventos, ledger, consentimientos |
| `redis` | 6379 | Cola de alertas de caída |
| `worker` | — | Procesa alertas (30s ACK → ntfy+SMTP); cron TTL RGPD |
| `minio` | 9000/9001 | S3-compatible: modelos TFLite OTA + datos opt-in |
| `ntfy` | 8080 | Push notifications self-hosted |
| `mlflow` | 5000 | Model registry + tracking de métricas |
| `prometheus` | 9090 | Scrape de métricas de API y worker |
| `grafana` | 3000 | Dashboards: fall_fpr, drift, latencia, throughput |

### 8.4 Flujo OTA de modelos

```
1. Entrenar modelo local (notebook) → validar: recall ≥ 0.95, size < 500 KB
2. Registrar en MLflow: versión + métricas + artefacto .tflite
3. Subir a MinIO bucket 'models': har_model_int8_v{N}.tflite
4. App Flutter: GET /models/latest en startup → descarga en background
5. Swap en siguiente arranque (sin interrupción del servicio)
6. Monitorización Grafana: si FPR > 0.10 en 48h → rollback a versión anterior
```

**Ventaja clave OTA:** no depende de App Store/Play Store. El modelo se actualiza directamente desde MinIO. Tiempo de propagación: < 1 hora frente a semanas con revisión de tiendas.

### 8.5 Decisiones de diseño vs alternativas

| Decisión | Alternativa descartada | Razón |
|----------|------------------------|-------|
| On-device inference | API inference (señal al backend) | RGPD Art. 9: señal fisiológica = dato sensible; latencia; funciona offline |
| TFLite INT8 | TFLite FP32 | 4× menor tamaño, 2× más rápido, <0.5% pérdida accuracy |
| Self-hosted EEE | Cloud AWS/GCP/Azure | Soberanía total: sin SCC, sin vendor lock-in, coste fijo |
| PostgreSQL | DynamoDB / Firestore | Transacciones ACID; queries de retención RGPD complejas |
| Redis + worker | Servicio cloud de mensajería | Sin lock-in; latencia < 1ms local; control del flujo de alerta |
| MinIO | AWS S3 | S3-compatible; self-hosted EEE; sin egress fees |
| ntfy self-hosted | Twilio / Firebase Cloud Messaging | Sin coste por mensaje; sin datos de usuarios en terceros |
| MLflow | SageMaker Model Registry | Open source; sin GPU gestionada de pago; training local |

---

## §9 · RGPD y Gobernanza de Datos de Salud (R3)

### 9.1 Clasificación de los datos

Los datos de acelerómetro y giroscopio usados para inferir actividad física y detectar caídas se clasifican como **datos de salud** según **RGPD Art. 9**, al revelar información sobre el estado físico del asegurado. Su tratamiento exige:

- **Art. 9(2)(a):** consentimiento explícito del titular
- **Art. 9(2)(h):** tratamiento necesario para prestación de asistencia sanitaria (alertas de emergencia)
- **Art. 5(1)(c):** principio de minimización — solo recoger lo estrictamente necesario
- **Art. 25:** privacidad por diseño — la arquitectura on-device lo implementa de forma radical

### 9.2 Tabla de datos — qué, dónde, cuánto, cómo

| Dato | Dónde se almacena | Retención | Protección |
|------|-------------------|-----------|------------|
| Señal cruda accel/gyro (50 Hz) | RAM del dispositivo | < 10 s | **Nunca sale del dispositivo** |
| Ventanas procesadas | RAM del dispositivo | < 5 s | Nunca sale del dispositivo |
| Probabilidad de actividad/caída | RAM del dispositivo | < 1 s | Nunca sale del dispositivo |
| Evento de actividad `{tipo, duración}` | PostgreSQL on-prem, Frankfurt (EEE) | 2 años | Pseudonimizado por `user_id_hash` |
| Alerta de caída `{stage, svm_peak}` | PostgreSQL on-prem, Frankfurt (EEE) | 90 días | Acceso restringido a centralita |
| Datos de reentrenamiento (opt-in) | MinIO on-prem, Frankfurt (EEE) | Hasta revocación | Anonimizados antes de ingesta |
| `user_id_hash` | PostgreSQL + dispositivo | Vida del contrato | SHA-256(DNI + salt rotativo) |

### 9.3 Consentimiento — dos cláusulas separadas

| Cláusula | Texto (resumen) | Obligatoria para |
|----------|-----------------|-----------------|
| **A — VitaPoints** | "Autorizo el proceso de mis eventos de actividad (tipo, duración, sin señal cruda) para calcular mi puntuación VitaPoints." | Usar el programa de incentivos |
| **B — Alertas de emergencia** | "Autorizo el envío de alerta a mi contacto de emergencia si se detecta posible caída sin respuesta en 30 s." | Activar alertas de caída |

La Cláusula B es **independiente** de la A: el asegurado puede usar VitaPoints sin activar alertas de caída.

### 9.4 DPIA — obligatoria (Art. 35)

La **Evaluación de Impacto** (DPIA) es obligatoria por concurrir dos criterios de la lista AEPD:
- Tratamiento a escala de datos de salud (Art. 35(3)(b))
- Perfilado sistemático de asegurados con efectos sobre las condiciones de la póliza

| Sección DPIA | Contenido |
|-------------|-----------|
| Descripción | HAR + fall detection on-device; solo eventos derivados al backend self-hosted EEE |
| Finalidad y necesidad | VitaPoints + alertas emergencia; alternativas menos intrusivas valoradas |
| Riesgos | Re-identificación por patrones de movilidad; FP en alertas; fuga de ritmos de vida |
| Medidas mitigadoras | On-device inference; pseudonimización; TTL cortos; cifrado TLS 1.3 en tránsito; LUKS en disco |
| Consulta DPO | Antes del lanzamiento |
| Revisión | Anual o ante cambios de arquitectura/modelos |

### 9.5 Derecho al olvido (Art. 17)

El endpoint `DELETE /users/{id}/data` garantiza el derecho de supresión en < 30 días (plazo legal):

```
DELETE /users/{user_id_hash}/data
  → Cascada PostgreSQL: activity_events, fall_events, vitapoints_ledger, consents, users
  → Elimina datos de reentrenamiento en MinIO (bucket training-data/{user_id_hash}/)
  → Respuesta: 204 No Content
```

### 9.6 Privacidad por diseño — cumplimiento técnico

| Principio RGPD | Implementación |
|----------------|----------------|
| Minimización | Señal cruda nunca sale del dispositivo; solo eventos derivados |
| Limitación de finalidad | Eventos de actividad vs caída: TTL distintos, acceso diferenciado |
| Limitación de conservación | Worker cron: `DELETE WHERE ts < NOW() - INTERVAL '2 years'` (actividad) / `'90 days'` (caídas) |
| Integridad y confidencialidad | TLS 1.3 en tránsito; LUKS en disco servidor; JWT en API |
| Responsabilidad proactiva | DPIA, DPO designado, registros de tratamiento Art. 30 |

### 9.7 Sin transferencias internacionales — ventaja clave

El backend está **self-hosted en Hetzner Frankfurt (Alemania, EEE)**. Todos los datos permanecen en territorio europeo. No se requiere ningún mecanismo del Art. 46 (no SCC, no BCR, no decisión de adecuación).

Esto contrasta con soluciones cloud que procesan datos de salud en us-east-1 (AWS) o us-central1 (GCP), que requieren Cláusulas Contractuales Tipo y suponen un riesgo regulatorio a la luz del fallo *Schrems II* (C-311/18, TJUE 2020).

**Soberanía de datos total = argumento diferencial** frente a cualquier competidor que use cloud americano para datos de salud de asegurados españoles.

---

## §10 · Modelo de Coste y ROI (M4)

### 10.1 CapEx — Construcción (coste one-time)

Asunciones: equipo júnior (100 €/h), 40 h/semana, proyecto nuevo desde cero.

| Rol | Esfuerzo | Coste estimado |
|-----|----------|----------------|
| Data engineering (pipelines, loaders, preprocesado) | 3 persona-semanas | 12.000 € |
| Modelado ML — HAR (6 clases, 1D-CNN + baseline) | 3 persona-semanas | 12.000 € |
| Modelado ML — Fall detector (CNN + cascada + TFLite) | 3 persona-semanas | 12.000 € |
| Mobile dev — Flutter + TFLite + sensores | 3 persona-semanas | 12.000 € |
| Backend self-hosted (FastAPI + Docker + PostgreSQL + Redis + MinIO) | 4 persona-semanas | 16.000 € |
| MLOps (MLflow + Prometheus/Grafana + pipeline OTA + monitoring) | 2 persona-semanas | 8.000 € |
| Legal / DPIA / DPO | 1 persona-semana | 4.000 € |
| QA + pruebas de campo | 2 persona-semanas | 8.000 € |
| **Total CapEx** | **21 persona-semanas** | **~84.000 €** |

### 10.2 OpEx — Operación mensual (estimado 180.000 usuarios)

La carga del backend es ligera: inferencia on-device → solo eventos derivados. Un servidor mid-tier + réplica HA cubre 180k usuarios activos con amplio margen.

| Componente | Especificación | Coste/mes |
|------------|---------------|-----------|
| Servidor principal | Hetzner AX42: 12-core AMD, 64 GB RAM, 2× 1.92 TB NVMe (Frankfurt, EEE) | ~75 € |
| Servidor réplica HA | Hetzner CX42 + PostgreSQL streaming replication | ~30 € |
| Backups | Hetzner Object Storage 1 TB/mes | ~5 € |
| Dominio + TLS | Let's Encrypt (gratuito) + registro dominio | ~2 € |
| Ancho de banda | 1 TB/mes incluido en Hetzner | 0 € |
| Ops/sysadmin | 0.1 FTE — mantenimiento mínimo con Docker Compose | ~400 € |
| **Total OpEx** | | **~512 €/mes** |

**Coste por usuario:**
```
Infraestructura pura:  112 € / 180.000 = 0,0006 €/usuario/mes
Total con ops:         512 € / 180.000 = 0,003 €/usuario/mes
```

Completamente absorbible en cualquier prima mensual.

### 10.3 Comparativa: build vs buy

| Opción | Coste/mes (180k usuarios) | Problemas RGPD |
|--------|--------------------------|----------------|
| **Vitalia self-hosted (esta propuesta)** | **~512 €/mes** | **Ninguno — EEE completo, sin transferencias** |
| API terceros (ej. Withings Health) | ~5.000 €/mes (0,028 €/usuario) | Señal de movimiento sale del dispositivo y va a EE.UU. |
| SDK HAR de licencia (flat fee) | ~2.000–8.000 €/mes | No personalizable; datos en terceros |
| Cloud gestionado (AWS/GCP) con inferencia API | ~548 €/mes + riesgo RGPD | Transferencias internacionales (SCC obligatorias); vendor lock-in |
| Apple Watch Fall Detection | Ecosistema cerrado | Solo iOS; datos en servidores Apple; sin integración con prima |

**Build-vs-buy: 9× más barato** que API de terceros + elimina el riesgo RGPD + soberanía de datos total.

### 10.4 ROI estimado

**Hipótesis de negocio:**
- 180.000 asegurados en el segmento senior (60+)
- Siniestralidad media por caída grave: 8.500 € (hospitalización + rehabilitación)
- Incidencia anual de caídas graves en 60+: ~2 % (dato epidemiológico España)
- El sistema permite intervención temprana en 30 % de los casos detectados

```
Ahorro anual = 180.000 × 2% × 30% × 8.500 € = 9.180.000 €/año

CapEx:           84.000 €
OpEx año 1:      512 €/mes × 12 = 6.144 €
Total año 1:    ~90.144 €

ROI año 1:       (9.180.000 − 90.144) / 90.144 ≈ 10.082%
Break-even:      < 1 semana de operación tras lanzamiento
```

> Este ROI es conservador: no incluye mejora de retención de asegurados, reducción de primas por menor siniestralidad, ni valor diferencial frente a competidores.

### 10.5 Posicionamiento competitivo

| Producto | HAR | Caídas | On-device | RGPD | Self-hosted | Prima dinámica |
|----------|-----|--------|-----------|------|-------------|----------------|
| **Vitalia (esta propuesta)** | ✅ 6 clases | ✅ cascada 3 etapas | ✅ TFLite INT8 | ✅ by design | ✅ EEE | ✅ VitaPoints |
| Vitality (Discovery/Prudential) | ✅ pasos | ❌ | ❌ cloud | Parcial | ❌ | ✅ |
| Generali Vitality | ✅ pasos | ❌ | ❌ cloud | Parcial | ❌ | ✅ |
| Apple Watch Fall Detection | ❌ | ✅ | ✅ | Parcial | ❌ (Apple infra) | ❌ |
| Google Fit | ✅ | ❌ | Parcial | Parcial | ❌ | ❌ |

**Ventaja diferencial única:** el único sistema que combina HAR on-device + detección de caídas con cascada 3 etapas + privacidad by-design + self-hosted EEE + integración directa con modelo actuarial de primas (VitaPoints).

---

## §11 · Limitaciones conocidas del MVP y trabajo futuro

| Limitación | Impacto en MVP | Trabajo futuro |
|------------|----------------|----------------|
| **Sin clase cycling** | Enunciado la menciona; no entrenada en v1 (PAMAP2 no integrado) | Integrar PAMAP2 #231, resamplear 100→50 Hz, reentrenar HAR |
| **Caídas solo con SisFall** | Dataset de cintura (sensor body-worn), no smartphone bolsillo | Solicitar MobiAct v2 (BMI-HMU); añadir ADLs vigorosos (jogging, jumping) como hard-negatives |
| **Sin validación con datos propios** | V5 del enunciado pendiente | Grabar con Phyphox (~5 min/actividad), inferir con `har_model_int8.tflite`, analizar errores |
| **Modelo HAR v1: 6 clases** | sitting y standing aún separados; Sprint 2 en curso los fusiona en *stationary* | Íñigo I-1: reentrenar a 5 clases; Íñigo I-4: re-exportar TFLite |

> Presentar estas limitaciones proactivamente al jurado refuerza la credibilidad técnica y demuestra capacidad crítica — parte del argumento de robustez.
