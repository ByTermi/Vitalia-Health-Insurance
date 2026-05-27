# B9 — Modelo de Coste CapEx + OpEx (Self-hosted)

## CapEx — Construcción (one-time)

Asunciones: equipo júnior (100 €/h), 40 h/semana, proyecto nuevo desde cero.

| Rol | Esfuerzo | Coste |
|-----|----------|-------|
| Data engineering (pipelines, loaders, preprocesado) | 3 persona-semanas | 12.000 € |
| Modelado ML — HAR (6 clases) | 3 persona-semanas | 12.000 € |
| Modelado ML — Fall detector (CNN + cascada) | 3 persona-semanas | 12.000 € |
| Mobile dev — Flutter + TFLite + sensores | 3 persona-semanas | 12.000 € |
| Backend self-hosted (FastAPI + Docker + PostgreSQL + Redis + MinIO) | 4 persona-semanas | 16.000 € |
| MLOps (MLflow + Prometheus/Grafana + pipeline OTA + monitoring) | 2 persona-semanas | 8.000 € |
| Legal / DPIA / DPO | 1 persona-semana | 4.000 € |
| QA + pruebas de campo | 2 persona-semanas | 8.000 € |
| **Total CapEx** | **21 persona-semanas** | **~84.000 €** |

> Nota: en el prototipo académico (1 semana, 2 personas) el alcance es ~10% del total.
> El CapEx real incluye QA exhaustivo, certificaciones médicas (si aplica) y lanzamiento.

## OpEx — Operación mensual (estimado 180.000 usuarios activos)

La carga del backend es ligera: inferencia on-device → solo eventos derivados (tipo
actividad, duración, alertas de caída). Un servidor mid-tier + réplica HA cubre 180k
usuarios con amplio margen.

### Infraestructura self-hosted EEE — detalle de costes

| Componente | Especificación | Coste/mes |
|------------|---------------|-----------|
| Servidor principal | Hetzner AX42: 12-core AMD, 64 GB RAM, 2× 1.92 TB NVMe — Frankfurt (EEE) | ~75 € |
| Servidor réplica HA | Hetzner CX42 standby + PostgreSQL streaming replication | ~30 € |
| Backups | Hetzner Object Storage 1 TB/mes | ~5 € |
| Dominio + TLS | Let's Encrypt (gratuito) + registro dominio | ~2 € |
| Ancho de banda | 1 TB/mes incluido en Hetzner | 0 € |
| Ops/sysadmin | 0.1 FTE — mantenimiento mínimo con Docker Compose | ~400 € |
| **Total OpEx** | | **~512 €/mes** |

### Coste por usuario activo

```
Infraestructura pura:  112 € / 180.000 usuarios = 0,0006 €/usuario/mes
Total con ops:         512 € / 180.000 usuarios = 0,003 €/usuario/mes
```

Completamente absorbible en cualquier prima mensual.

### Ventaja de coste fijo vs cloud variable

Con cloud gestionado, el coste escala con el número de peticiones y usuarios. Con
self-hosted, el coste es fijo: los mismos servidores sirven 180k o 500k usuarios
sin cambio de coste de infraestructura (hasta el límite de capacidad del servidor).

## Comparativa: build vs buy

| Opción | Coste mensual (180k usuarios) | Problemas RGPD |
|--------|-------------------------------|----------------|
| **Vitalia build (self-hosted, on-device)** | **~512 €/mes** | **Ninguno — EEE completo, sin transferencias** |
| API terceros (ej. Withings Health) | ~5.000 €/mes (0.028 €/usuario) | RGPD: señal de movimiento sale del dispositivo y va a EE.UU. |
| API terceros (ej. Apple HealthKit backend) | Ecosistema cerrado | Solo iOS, dependencia vendor, datos en servidores Apple |
| SDK HAR genérico (licencia) | ~2.000–8.000 €/mes (flat fee) | No personalizable, datos en terceros |
| Cloud gestionado (AWS/GCP) con inferencia API | ~548 €/mes + riesgo RGPD | Transferencias internacionales (SCC obligatorias), vendor lock-in |

**Build-vs-buy: 9× más barato** que API de terceros + elimina el riesgo RGPD +
soberanía de datos total (datos en EEE, sin proveedores cloud extracomunitarios).

## ROI estimado

### Hipótesis de negocio

- Vitalia tiene 180.000 asegurados en el segmento senior (60+)
- Siniestralidad media por caída grave: 8.500 € (hospitalización + rehab)
- Incidencia anual de caídas graves en 60+: ~2 % (dato epidemiológico España)
- El sistema detecta y permite intervención temprana en 30 % de los casos
- Reducción de siniestralidad: 180.000 × 2 % × 30 % × 8.500 € = **9.180.000 €/año**

### Break-even

```
CapEx:           84.000 €  (construcción)
OpEx año 1:      512 €/mes × 12 = 6.144 €
Total año 1:    ~90.144 €

Ahorro año 1:   9.180.000 €

ROI año 1:      (9.180.000 - 90.144) / 90.144 ≈ 10.082 %
Break-even:     < 1 semana de operación tras lanzamiento
```

> Este ROI es conservador: no incluye mejora de retención de asegurados,
> reducción de primas por menor siniestralidad, ni valor diferencial frente a competidores.

## Comparativa competitiva

| Producto | HAR | Caídas | On-device | RGPD | Self-hosted | Prima dinámica |
|----------|-----|--------|-----------|------|-------------|----------------|
| **Vitalia (propuesta)** | ✅ 6 clases | ✅ cascada 3 etapas | ✅ TFLite | ✅ by design | ✅ EEE | ✅ VitaPoints |
| Vitality (Discovery/Prudential) | ✅ pasos | ❌ | ❌ (cloud) | Parcial | ❌ | ✅ |
| Generali Vitality | ✅ pasos | ❌ | ❌ (cloud) | Parcial | ❌ | ✅ |
| Apple Watch Fall Detection | ❌ | ✅ | ✅ | Parcial | ❌ (Apple infra) | ❌ |
| Google Fit | ✅ | ❌ | Parcial | Parcial | ❌ | ❌ |

**Ventaja diferencial:** único sistema que combina HAR + detección de caídas + privacidad
by-design + self-hosted EEE + integración directa con modelo actuarial de primas.
