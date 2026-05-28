# Servicios del Backend — Referencia para la app

## §1 Endpoints HTTP

| Método | Ruta | Función general | Usado en la app | Payload → Respuesta |
|--------|------|-----------------|-----------------|---------------------|
| `GET` | `/health` | Estado de todos los servicios (api, db, redis, minio) | `api_service.dart:checkHealth()` → icono cloud AppBar + test tab | — → `{status, db, redis, minio}` |
| `POST` | `/events/activity` | Registra un evento de actividad y calcula VitaPoints | `home_page.dart:_pointsTimer` cada 60 s de actividad activa | `{user_id_hash, activity, duration_s}` → `{vitapoints_earned, total_vitapoints, streak_days, level}` |
| `POST` | `/events/fall` | Registra caída y la encola en Redis para que el worker espere ACK 30 s | `home_page.dart:_onSample` cuando `stage >= 2` | `{user_id_hash, stage, svm_peak}` → `{fall_id, status, ack_deadline_s}` |
| `POST` | `/events/fall/{fall_id}/ack` | Cancela la alerta — el usuario respondió "Estoy bien" | `home_page.dart:_triggerFallAlert` cuando el usuario pulsa el botón | — → `{fall_id, status: "acked"}` |
| `GET` | `/users/{id}/vitapoints` | Devuelve total, semana, racha y nivel del usuario | `home_page.dart:_init()` al arrancar + `_testGetVitaPoints()` | — → `{total, this_week, streak_days, level}` |
| `GET` | `/models/latest` | Devuelve metadatos del modelo TFLite más reciente en MinIO | `model_update_service.dart:checkAndUpdate()` al arrancar + test tab | — → `{name, version, size_kb, filename}` |
| `GET` | `/models/{filename}` | Descarga el fichero `.tflite` desde MinIO (streaming) | `api_service.dart:downloadModel()` si `getLatestModel` reporta versión nueva | — → `application/octet-stream` |
| `DELETE` | `/users/{id}/data` | Derecho al olvido (Art. 17 RGPD): borra usuario en cascada + objetos en MinIO | `settings_screen.dart:_deleteBackendData()` + test tab | — → `204 No Content` |
| `GET` | `/metrics` | Métricas Prometheus (latencia por endpoint, contadores de eventos) | No consumido por la app — sólo Prometheus scraping | — → texto Prometheus |

---

## §2 Contenedores Docker

| Servicio | Puerto | Rol general | Depende de | Flujos de la app que lo usan |
|----------|--------|-------------|------------|------------------------------|
| `api` (FastAPI) | **8000** | API REST principal — recibe todas las peticiones HTTP de la app | `db`, `redis`, `minio` | Todos los endpoints |
| `db` (PostgreSQL 16) | 5432 | Persistencia de usuarios, eventos, VitaPoints, consentimientos, caídas | — | `POST /events/*`, `GET /users/*/vitapoints`, `DELETE /users/*/data` |
| `redis` | 6379 | Cola `vitalia:falls` — buffer entre API y worker para el pipeline de alertas | — | `POST /events/fall` → encola `fall_id` |
| `worker` | — | Consume la cola Redis, espera 30 s ACK, envía ntfy + SMTP si no hay respuesta. Cron RGPD los domingos a las 03:00. | `db`, `redis`, `ntfy` | `POST /events/fall` (side-effect asíncrono) |
| `minio` | 9000 / 9001 | Almacén S3-compatible: modelos TFLite OTA (`models/`) + datos de reentrenamiento opt-in (`training-data/`) | — | `GET /models/latest`, `GET /models/{filename}`, `DELETE /users/*/data` |
| `ntfy` | 8080 | Push notifications self-hosted. Configurado con `ntfy/server.yml`: caché SQLite 24h (WAL), retención de adjuntos 1h. Worker publica alertas en `vitalia-falls-{hash[:8]}`. **App suscribe vía SSE** (`NtfyService`) para recibir notificaciones cuando el backend escala la alerta. | — | Alertas de caída no ACK tras 30 s; `NtfyService.subscribe()` al arrancar la app |
| `mlflow` | 5000 | Model registry + experiment tracking. **Activo:** los notebooks 03/04/05 loguean experimentos, métricas por fold, artefactos y registran modelos en el model registry (`vitalia-har`, `vitalia-fall`). La sección de promoción en notebook 05 sube `.tflite` + `model_meta.json` a MinIO. | `minio` | No consumido por la app — pipeline de entrenamiento |
| `prometheus` | 9090 | Scraping de `/metrics` cada 15 s. **Activo:** gauges `active_users_24h`, `fall_fpr_ratio` y métricas de calidad del modelo (`har_f1_macro`, `fall_recall_balanced`, etc.) se actualizan cada 60 s desde PostgreSQL y MinIO vía thread daemon en la API. Reglas de alerta en `prometheus/alerts.yml`. | `api` | No consumido por la app — monitorización interna |
| `grafana` | 3000 | Dashboard de monitorización. **Activo:** 12 paneles — 6 de operación (FPR, usuarios, eventos, latencia) + row collapsable "Calidad del Modelo Desplegado" con gauges de recall/precision/F1/tamaño. | `prometheus` | No consumido por la app — monitorización interna |

---

## §3 Flujos end-to-end

### 3.1 Actividad detectada → VitaPoints

```
App (cada 60 s si actividad activa)
  │
  ├─ POST /events/activity {user_id_hash, activity, duration_s}
  │         │
  │         ├─ api: calcula points = duration_s/60 × POINTS_PER_MINUTE[activity]
  │         ├─ db:  INSERT activity_event + INSERT vitapoints_ledger
  │         ├─ db:  SELECT SUM(points) → total, streak
  │         └─ → {vitapoints_earned, total_vitapoints, streak_days, level}
  │
  └─ App actualiza _vitaPoints, _streakDays, _level en UI
```

### 3.2 Caída detectada → alerta

```
App (sensor stream)
  │
  ├─ Stage 1: SVM > 3 g → Stage 2: CNN prob > threshold
  │
  ├─ POST /events/fall {user_id_hash, stage, svm_peak}
  │         │
  │         ├─ api: INSERT fall_event (status="pending")
  │         ├─ redis: LPUSH vitalia:falls fall_id
  │         └─ → {fall_id, status="pending", ack_deadline_s=30}
  │
  ├─ App muestra dialog "¿Estás bien?" (30 s)
  │
  ├─ Si usuario pulsa "Estoy bien":
  │     POST /events/fall/{fall_id}/ack
  │     → api: UPDATE fall_event status="acked"
  │     → worker: detecta status != "pending" → no alerta
  │
  └─ Si NO hay respuesta en 30 s:
        worker: BRPOP vitalia:falls → espera 30 s → SELECT status
        → status="pending" → _send_ntfy() + _send_email()
        → UPDATE fall_event status="alerted"
```

### 3.3 OTA de modelos al arrancar

```
App (inicio)
  │
  ├─ GET /models/latest → {name, version, size_kb, filename}
  │
  ├─ Si version != SharedPreferences["ota_model_version"]:
  │     GET /models/{filename} → stream → File(getApplicationDocumentsDirectory()/filename)
  │     SharedPreferences["ota_model_version"] = version
  │
  └─ Interpreter.fromFile(localPath) en lugar de fromAsset
     (fallback a bundled asset si falla)
```

### 3.4 Derecho al olvido (RGPD Art. 17)

```
App (Settings → "Borrar mis datos del servidor")
  │
  ├─ DELETE /users/{user_id_hash}/data
  │         │
  │         ├─ api: db.delete(user) con CASCADE
  │         │       → borra: users, activity_events, fall_events,
  │         │                vitapoints_ledger, consents
  │         ├─ minio: remove_objects training-data/{user_id_hash}/*
  │         └─ → 204 No Content
  │
  └─ App reset: _vitaPoints=0, _streakDays=0, _level="bronze"
```
