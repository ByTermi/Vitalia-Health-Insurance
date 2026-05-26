# B9 — Modelo de Coste CapEx + OpEx

## CapEx — Construcción (one-time)

Asunciones: equipo júnior (100 €/h), 40 h/semana, proyecto nuevo desde cero.

| Rol | Esfuerzo | Coste |
|-----|----------|-------|
| Data engineering (pipelines, loaders, preprocesado) | 3 persona-semanas | 12.000 € |
| Modelado ML — HAR (6 clases) | 3 persona-semanas | 12.000 € |
| Modelado ML — Fall detector (CNN + cascada) | 3 persona-semanas | 12.000 € |
| Mobile dev — Flutter + TFLite + sensores | 3 persona-semanas | 12.000 € |
| Backend serverless (AWS Lambda, DynamoDB, SNS) | 4 persona-semanas | 16.000 € |
| MLOps (SageMaker pipeline, OTA, monitoring) | 2 persona-semanas | 8.000 € |
| Legal / DPIA / DPO | 1 persona-semana | 4.000 € |
| QA + pruebas de campo | 2 persona-semanas | 8.000 € |
| **Total CapEx** | **21 persona-semanas** | **~84.000 €** |

> Nota: en el prototipo académico (1 semana, 2 personas) el alcance es ~10% del total.
> El CapEx real incluye QA exhaustivo, certificaciones médicas (si aplica) y lanzamiento.

## OpEx — Operación mensual (estimado 180.000 usuarios activos)

### AWS serverless — detalle de costes

| Componente | Volumen/mes | Coste/mes |
|------------|-------------|-----------|
| API Gateway | 180k usuarios × 30 días × 10 eventos/día = 54M peticiones | ~190 € |
| Lambda (VitaPoints + FallAlert) | 54M invocaciones × 200ms × 128MB | ~120 € |
| DynamoDB (on-demand) | 54M escrituras + 10M lecturas | ~150 € |
| SNS (alertas caída) | ~500 alertas reales/mes (0.003% FPR) | < 1 € |
| S3 (modelos + datos entrenamiento) | ~10 GB almacenamiento + transferencia | ~25 € |
| CloudFront (OTA updates) | 1 update/trimestre × 180k usuarios × 200 KB | ~15 € |
| CloudWatch + X-Ray | Logs + métricas custom | ~30 € |
| SageMaker (entrenamiento trimestral) | ml.m5.xlarge × 4h × 4 veces/año ÷ 12 | ~17 € |
| **Total OpEx** | | **~548 €/mes** |

### Coste por usuario activo

```
548 € / 180.000 usuarios = 0,003 €/usuario/mes = 0,036 €/usuario/año
```

Completamente absorbible en cualquier prima mensual.

## Comparativa: build vs buy

| Opción | Coste mensual (180k usuarios) | Problemas |
|--------|-------------------------------|-----------|
| **Vitalia build (on-device)** | **548 €/mes** | — |
| API terceros (ej. Withing Health) | ~5.000 €/mes (0.028 €/usuario) | RGPD: señal sale del dispositivo |
| API terceros (ej. Apple HealthKit backend) | Ecosistema cerrado | Solo iOS, dependencia vendor |
| SDK HAR genérico (licencia) | ~2.000–8.000 €/mes (flat fee) | No personalizable, no on-device |

**Build-vs-buy: 9x más barato** que API de terceros + elimina el riesgo RGPD.

## ROI estimado

### Hipótesis de negocio

- Vitalia tiene 180.000 asegurados en el segmento senior (60+)
- Siniestralidad media por caída grave: 8.500 € (hospitalización + rehab)
- Incidencia anual de caídas graves en 60+: ~2% (dato epidemiológico España)
- El sistema detecta y permite intervención temprana en 30% de los casos
- Reducción de siniestralidad: 180.000 × 2% × 30% × 8.500 € = **9.180.000 €/año**

### Break-even

```
CapEx:          84.000 €  (construcción)
OpEx año 1:     84.000 × 548 €/12 ≈ 6.576 €  (12 meses)
Total año 1:   ~90.576 €

Ahorro año 1:  9.180.000 €

ROI año 1:     (9.180.000 - 90.576) / 90.576 ≈ 10.034%
Break-even:    < 1 semana de operación tras lanzamiento
```

> Este ROI es conservador: no incluye mejora de retención de asegurados,
> reducción de primas por menor siniestralidad, ni valor diferencial frente a competidores.

## Comparativa competitiva

| Producto | HAR | Caídas | On-device | RGPD | Prima dinámica |
|----------|-----|--------|-----------|------|----------------|
| **Vitalia (propuesta)** | ✅ 6 clases | ✅ cascada 3 etapas | ✅ TFLite | ✅ by design | ✅ VitaPoints |
| Vitality (Discovery/Prudential) | ✅ pasos | ❌ | ❌ (cloud) | Parcial | ✅ |
| Generali Vitality | ✅ pasos | ❌ | ❌ (cloud) | Parcial | ✅ |
| Apple Watch Fall Detection | ❌ | ✅ | ✅ | ✅ | ❌ (no seguro) |
| Google Fit | ✅ | ❌ | Parcial | Parcial | ❌ (no seguro) |

**Ventaja diferencial:** único sistema que combina HAR + detección de caídas + privacidad
by-design + integración directa con modelo actuarial de primas.
