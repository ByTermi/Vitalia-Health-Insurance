# B7 — Arquitectura de Producción (Self-hosted · sin cloud)

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
│  Only derived events exit: {activity, duration_s}  {fall_alert}      │
└───────────────────────────┬─────────────────────────────────────────┘
                            │ HTTPS + TLS 1.3 + JWT (eventos derivados)
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│               BACKEND SELF-HOSTED (EEE — Hetzner Frankfurt)          │
│                                                                       │
│  FastAPI (uvicorn)                                                    │
│  ├─► POST /events/activity  ─► PostgreSQL (vitapoints_ledger)        │
│  ├─► POST /events/fall      ─► Redis (cola alertas)                  │
│  ├─► POST /events/fall/{id}/ack  ─► cancela alerta                   │
│  ├─► GET  /models/latest    ─► MinIO (model registry)                │
│  └─► DELETE /users/{id}/data ─► derecho al olvido (Art. 17)          │
│                                                                       │
│  Redis ──► Worker ──► espera 30s ACK                                  │
│                   ├─► ntfy push (contacto emergencia)                │
│                   └─► SMTP email (respaldo)                          │
│                                                                       │
│  PostgreSQL: vitapoints_ledger, activity_events, fall_events         │
│  MinIO: bucket 'models' (OTA) + bucket 'training-data' (opt-in)      │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         ML OPS PIPELINE                              │
│                                                                       │
│  Entrenamiento local (notebooks) → evaluación LOSO                  │
│  ↓ recall ≥ 0.95 AND size < 500 KB AND latency < 50ms               │
│  MLflow: registro de modelo + métricas + artefactos en MinIO        │
│  MinIO bucket 'models': har_model_int8_v{N}.tflite                  │
│  App Flutter: GET /models/latest en startup → OTA descarga          │
│  Rollback: si FPR > 0.10 en 48h → volver a versión anterior MinIO   │
│                                                                       │
│  Monitoring: Prometheus (scrape /metrics) + Grafana                  │
│  ├─► fall_fpr (False Positive Rate en producción)                   │
│  ├─► activity_drift (distribución semanal vs baseline)              │
│  └─► api_latency_p99                                                 │
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

**Duty cycling:** inferencia HAR cada 5 s. FallDetector: Stage 1 (SVM check) siempre activo, O(1). Activa CNN solo si SVM > 3g.

**Latencia estimada:** < 15 ms por inferencia (INT8, XNNPACK, Pixel 7).

## Backend self-hosted — servicios (docker-compose)

| Servicio | Imagen | Puerto | Rol |
|----------|--------|--------|-----|
| `api` | build ./api | 8000 | FastAPI: ingesta eventos, VitaPoints, OTA, RGPD delete |
| `db` | postgres:16-alpine | 5432 | Persistencia eventos, ledger, consentimientos |
| `redis` | redis:7-alpine | 6379 | Cola de alertas de caída |
| `worker` | build ./worker | — | Procesa alertas: ACK 30s → ntfy + SMTP; cron TTL RGPD |
| `minio` | minio/minio | 9000/9001 | Object store S3-compat: modelos TFLite + datos opt-in |
| `ntfy` | binwiederhier/ntfy | 8080 | Push self-hosted: alertas contacto emergencia |
| `mlflow` | ghcr.io/mlflow/mlflow | 5000 | Model registry + tracking + A/B testing |
| `prometheus` | prom/prometheus | 9090 | Scrape /metrics de api + worker |
| `grafana` | grafana/grafana-oss | 3000 | Dashboards: fall_fpr, drift, latencia, throughput |

Repo backend separado: `E:\repos_claude_code\Vitalia Health Insurance Backend`

## Lógica de los endpoints principales

### POST /events/activity
```
Input:  {user_id_hash, activity, duration_s}
Logic:  VitaPoints += duration_s/60 × points_per_minute[activity]
Output: {vitapoints_earned, total_vitapoints, streak_days, level}
Store:  PostgreSQL: activity_events + vitapoints_ledger
```

### POST /events/fall → Worker (alerta)
```
Input:  {user_id_hash, fall_stage, svm_peak}
Logic:
  1. Inserta fall_event(status=pending) en PostgreSQL
  2. Encola fall_id en Redis
  3. Worker consume: espera 30s ACK
  4. Si no ACK → ntfy push al contacto emergencia + email SMTP
  5. Prompt "¿Estás bien?" desde app → POST /events/fall/{id}/ack → cancela alerta
Store:  PostgreSQL: fall_events (TTL 90 días)
```

### OTA Model Updates
```
1. Entrenar modelo nuevo localmente (notebooks) → validar: recall ≥ 0.95
2. Registrar en MLflow: versión + métricas + artefacto .tflite
3. Subir a MinIO bucket 'models': har_model_int8_v{N}.tflite
4. App comprueba GET /models/latest en cada startup
5. Si versión > local → descarga background → swap en siguiente arranque
6. Rollback: si FPR > 0.10 en 48h (alerta Grafana) → volver a versión anterior en MinIO
```

## Decisiones de diseño clave

| Decisión | Alternativa descartada | Razón |
|----------|------------------------|-------|
| On-device inference | API inference (señal al backend) | RGPD Art. 9: señal fisiológica = dato sensible; latencia; funciona offline |
| TFLite INT8 | TFLite FP32 | 4× menor tamaño, 2× más rápido, < 0.5 % pérdida accuracy |
| Self-hosted (EEE) | Cloud gestionado (AWS/GCP/Azure) | Soberanía de datos total: sin transferencias internacionales (no SCC); coste fijo predecible; sin vendor lock-in |
| PostgreSQL | DynamoDB | Transacciones ACID; queries complejas de retención RGPD; sin coste por operación |
| Redis + worker | Servicio de mensajería cloud | Sin vendor lock-in; latencia < 1ms local; control total del flujo de alerta |
| MinIO | S3 | S3-compatible; self-hosted; sin egress fees; en EEE |
| ntfy self-hosted | Twilio/Firebase | Sin coste por mensaje; sin datos de usuarios en terceros |
| MLflow | SageMaker | Open source; sin coste de instancia GPU gestionada; entrenamiento local/on-prem |
| Prometheus + Grafana | CloudWatch + X-Ray | Open source; sin coste por métrica; paneles personalizados para fall_fpr y drift |
