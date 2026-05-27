# B8 — RGPD y Gobernanza de Datos de Salud

## Base legal

Los datos de acelerómetro y giroscopio, cuando se usan para inferir estado de salud
(detección de caídas, actividad física), se clasifican como **datos de salud** bajo
**RGPD Art. 9** (categoría especial). Su tratamiento requiere:

- Base legal Art. 9(2)(a): **consentimiento explícito** para el tratamiento
- Base legal Art. 9(2)(h): tratamiento **necesario para prestación de asistencia sanitaria**
  (aplicable al programa de alertas de emergencia)
- Principio de **minimización** (Art. 5(1)(c)): solo recoger lo estrictamente necesario
- Principio de **privacidad por diseño** (Art. 25): arquitectura on-device + self-hosted
  lo implementa de forma radical

## Tabla de datos — qué/dónde/cuánto/cómo

| Dato | Dónde se almacena | Tiempo retención | Protección |
|------|-------------------|-----------------|------------|
| Señal cruda accel/gyro (200 Hz) | RAM del dispositivo | < 10 segundos | **Nunca sale del dispositivo** |
| Ventanas procesadas (50 Hz) | RAM del dispositivo | < 5 segundos | Nunca sale del dispositivo |
| Probabilidad de actividad (float) | RAM del dispositivo | < 1 segundo | Nunca sale del dispositivo |
| Evento de actividad `{tipo, duración}` | PostgreSQL on-prem (EEE, Frankfurt) | 2 años | Pseudonimizado por `user_id_hash` |
| Alerta de caída `{stage, svm_peak}` | PostgreSQL on-prem (EEE, Frankfurt) | 90 días | Acceso restringido a centralita |
| Datos de reentrenamiento | MinIO on-prem (EEE, mismo servidor) | Hasta revocación | Anonimizados antes de ingesta |
| `user_id_hash` | PostgreSQL + dispositivo | Vida del contrato | SHA-256 del DNI + salt rotativo |

## Consentimiento

Se requieren **dos cláusulas separadas** en el onboarding:

1. **Cláusula A — VitaPoints:** "Autorizo a Vitalia a procesar mis eventos de actividad
   física (tipo y duración, sin señal cruda) para calcular mi puntuación VitaPoints."

2. **Cláusula B — Alertas de emergencia:** "Autorizo a Vitalia a enviar una alerta a mi
   contacto de emergencia y/o servicios de emergencia si se detecta una posible caída y
   no respondo en 30 segundos."

La Cláusula B es **independiente** de la A — el usuario puede usar VitaPoints sin
activar alertas de emergencia.

## DPIA (Evaluación de Impacto — Art. 35)

La DPIA es **obligatoria** porque concurren dos criterios del listado AEPD:
- Tratamiento a escala de datos de salud (Art. 35(3)(b))
- Perfilado sistemático de asegurados con efectos jurídicos (modificación de prima)

### Contenido mínimo de la DPIA

| Sección | Contenido |
|---------|-----------|
| Descripción del tratamiento | HAR + fall detection on-device, eventos al backend self-hosted EEE |
| Finalidad y necesidad | VitaPoints + alertas emergencia; alternativas menos intrusivas valoradas |
| Riesgos identificados | Re-identificación, falsos positivos en alertas, fuga de patrones de vida |
| Medidas mitigadoras | On-device inference, pseudonimización, TTL cortos, cifrado en tránsito y en reposo |
| Consulta al DPO | Sí, antes del lanzamiento |
| Revisión periódica | Anual o cuando cambien arquitectura/modelos |

## Derecho al olvido (Art. 17)

Endpoint obligatorio en el backend:
```
DELETE /users/{user_id}/data
  → Borra en cascada: activity_events, fall_events, vitapoints_ledger, consents, users
  → Elimina datos de reentrenamiento opt-in en MinIO (bucket training-data)
  → Respuesta: 204 No Content en < 30 días (plazo legal)
```

El `user_id_hash` en dispositivo se elimina al desinstalar la app o en la
opción "Eliminar mi cuenta" de la UI.

## Privacidad por diseño — cumplimiento técnico

| Principio RGPD | Implementación técnica |
|----------------|----------------------|
| Minimización | Señal cruda nunca sale del dispositivo; solo eventos derivados al backend |
| Limitación de finalidad | Datos de actividad ≠ datos de caída; TTL distintos; acceso diferenciado |
| Exactitud | Modelos re-entrenados trimestralmente (MLflow); usuario puede corregir eventos erróneos |
| Limitación de conservación | Jobs cron en worker: `DELETE WHERE expires_at < NOW()` (2 años actividad, 90 días caídas) |
| Integridad y confidencialidad | TLS 1.3 en tránsito; cifrado de disco (LUKS) en servidor; autenticación JWT en API |
| Responsabilidad proactiva | DPIA, DPO designado, registros de tratamiento (Art. 30) |

## Sin transferencias internacionales — ventaja clave

El backend está **self-hosted en Hetzner Frankfurt (Alemania, EEE)**. Todos los datos
permanecen en territorio europeo. No se requiere ningún mecanismo adicional del Art. 46
RGPD (no SCC, no BCR, no decisión de adecuación).

Esto contrasta con soluciones cloud que utilizan SageMaker u otros servicios en us-east-1,
que requieren cláusulas contractuales tipo y suponen un riesgo regulatorio en el contexto
de las relaciones UE-EE.UU. tras el fallo Schrems II.

**Soberanía de datos total** = argumento diferencial frente a cualquier competidor que
use cloud americano para procesar datos de salud de asegurados españoles.

## Retención automática (jobs del worker)

Worker ejecuta dos jobs cron internos (schedule: semanal, domingos 03:00):

```sql
-- Retención actividades: 2 años (Art. 5(1)(e) RGPD)
DELETE FROM activity_events WHERE expires_at < NOW();

-- Retención alertas de caída: 90 días
DELETE FROM fall_events WHERE expires_at < NOW();
```

Los campos `expires_at` son columnas generadas automáticamente en PostgreSQL:
- `activity_events.expires_at = ts + INTERVAL '2 years'`
- `fall_events.expires_at = ts + INTERVAL '90 days'`

## Resumen ejecutivo para la memoria

> Vitalia procesa datos de salud (Art. 9 RGPD) bajo un esquema de **privacidad por
> diseño radical**: la señal cruda de los sensores nunca abandona el dispositivo del
> asegurado, y los eventos derivados se almacenan en infraestructura **self-hosted en
> EEE (Frankfurt, Alemania)**, bajo control directo de Vitalia, sin ningún proveedor
> cloud extracomunitario. Este diseño elimina de raíz el mayor riesgo de re-identificación,
> elimina la necesidad de SCC o cualquier mecanismo del Art. 46, y reduce el alcance de
> la DPIA. La DPIA sigue siendo obligatoria por el tratamiento a escala, pero su riesgo
> residual es mínimo.
