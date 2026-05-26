# B7 — Arquitectura de Producción

## Diagrama general

```
┌─────────────────────────────────────────────────────────────────────┐
│                         SMARTPHONE (ON-DEVICE)                       │
│                                                                       │
│  Accel+Gyro @50 Hz                                                    │
│       │                                                               │
│       ▼                                                               │
│  SlidingWindowBuffer                                                  │
│  ├─► Stage 1: SVM > 3g? ─────► FallDetector CNN ──► Alert Flow       │
│  └─► HarClassifier CNN ──────────────────────────► VitaPoints UI     │
│                                                                       │
│  RAW SIGNAL NEVER LEAVES DEVICE  (RGPD Art. 9)                       │
│  Only derived events exit: {activity, duration, fall_alert}          │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ HTTPS + JWT (eventos derivados solamente)
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AWS BACKEND (serverless)                     │
│                                                                       │
│  API Gateway                                                          │
│  ├─► POST /events/activity  ─► Lambda (VitaPoints) ─► DynamoDB      │
│  ├─► POST /events/fall      ─► Lambda (Alert)       ─► SNS ─► 112   │
│  └─► GET  /models/latest    ─► S3 (Model Registry)                  │
│                                                                       │
│  CloudWatch Logs + X-Ray tracing                                     │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         ML OPS PIPELINE                              │
│                                                                       │
│  DynamoDB (eventos anonimizados) ──► S3 (raw training data)         │
│  S3 ──► SageMaker Training Job (trimestral o drift-triggered)        │
│  SageMaker ──► Model Registry (versionado, A/B testing)             │
│  Model Registry ──► S3 + CloudFront CDN ──► OTA update mobile       │
│                                                                       │
│  Monitoring: CloudWatch custom metrics                                │
│  ├─► fall_fpr (False Positive Rate en producción)                   │
│  ├─► activity_drift (distribución de actividades por semana)        │
│  └─► model_latency_p99                                               │
└─────────────────────────────────────────────────────────────────────┘
```

## Componentes on-device

| Componente | Responsabilidad | Tecnología |
|------------|-----------------|------------|
| `SensorService` | Stream accel+gyro @50 Hz, duty-cycled | `sensors_plus` Flutter |
| `SlidingWindowBuffer` | Buffer circular 128/100 samples | Dart |
| `HarClassifier` | Inferencia actividad (6 clases) | TFLite INT8 |
| `FallDetector` | Cascada 3 etapas | TFLite INT8 + Dart |
| `LocalStore` | Caché de VitaPoints offline | SharedPreferences |

**Duty cycling:** inferencia HAR cada 5 s (no cada ventana). FallDetector siempre activo pero Stage 1 (SVM check) es O(1) — activa CNN solo si SVM > 3g.

**Latencia estimada:** < 15 ms por inferencia (INT8, XNNPACK, Pixel 7).

## Backend serverless

### Lambda: VitaPoints
```
Input: {user_id_hash, activity, duration_s, timestamp}
Logic: VitaPoints += duration_s/60 * points_per_minute[activity]
Output: {total_vita_points, streak_days}
Store: DynamoDB tabla vitalia-events (TTL 2 años)
```

### Lambda: FallAlert
```
Input: {user_id_hash, fall_stage, svm_peak, timestamp, location_city}
Logic:
  1. Espera 30s ACK del usuario ("¿Estás bien?" prompt)
  2. Si no ACK → SNS topic → SMS/llamada a contacto de emergencia
  3. Opcionalmente → integración 112 (futuro)
Store: DynamoDB tabla vitalia-falls (TTL 90 días)
```

### OTA Model Updates
```
1. SageMaker entrena modelo nuevo → valida en hold-out set
2. Si recall ≥ 0.95 → sube a S3/models/fall_model_int8_v{N}.tflite
3. Mobile app comprueba GET /models/latest en cada startup
4. Si versión > local → descarga background → swap en siguiente arranque
5. Rollback automático si FPR > 0.10 en las primeras 48h (CloudWatch alarm)
```

## Training Pipeline (SageMaker)

```
Trigger: cron trimestral O CloudWatch alarm (drift > 0.15)

1. Data Ingestion:
   - DynamoDB export → S3 raw (solo eventos con consentimiento)
   - Anonimización: user_id → hash, drop timestamps absolutos

2. Feature Store: SageMaker Feature Store
   - Ventanas preprocesadas (no señal cruda)
   - Versionadas por dataset_version

3. Training:
   - SageMaker Training Job (ml.m5.xlarge, ~30 min)
   - Hyperparameter tuning: threshold conservador (recall target = 0.95)
   - LOSO CV con datos nuevos

4. Export:
   - Keras → TFLite → INT8 quantization
   - Validate: size < 500 KB, latency < 50 ms (SageMaker Profiler)

5. Registry:
   - Model card con métricas por segmento (65+, general)
   - A/B flag: 5% usuarios en nueva versión 1 semana antes de rollout
```

## Decisiones de diseño clave

| Decisión | Alternativa descartada | Razón |
|----------|------------------------|-------|
| On-device inference | API inference (enviar señal al backend) | RGPD Art. 9: señal fisiológica = dato sensible; latencia; funciona offline |
| TFLite INT8 | TFLite FP32 | 4x menor tamaño, 2x más rápido, < 0.5% pérdida de accuracy |
| Serverless (Lambda) | EC2 siempre encendido | 0 coste cuando sin tráfico; escala automático |
| DynamoDB | RDS PostgreSQL | Sin esquema fijo para eventos heterogéneos; TTL nativo; coste |
| SNS para alertas | Twilio | AWS-native, menor latencia, integrable con Step Functions |
