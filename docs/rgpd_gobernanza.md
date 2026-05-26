# B8 — RGPD y Gobernanza de Datos de Salud

## Base legal

Los datos de acelerómetro y giroscopio, cuando se usan para inferir estado de salud
(detección de caídas, actividad física), se clasifican como **datos de salud** bajo
**RGPD Art. 9** (categoría especial). Su tratamiento requiere:

- Base legal Art. 9(2)(a): **consentimiento explícito** para el tratamiento
- Base legal Art. 9(2)(h): tratamiento **necesario para prestación de asistencia sanitaria**
  (aplicable al programa de alertas de emergencia)
- Principio de **minimización** (Art. 5(1)(c)): solo recoger lo estrictamente necesario
- Principio de **privacidad por diseño** (Art. 25): arquitectura on-device lo implementa

## Tabla de datos — qué/dónde/cuánto/cómo

| Dato | Dónde se almacena | Tiempo retención | Protección |
|------|-------------------|-----------------|------------|
| Señal cruda accel/gyro (200 Hz) | RAM del dispositivo | < 10 segundos | **Nunca sale del dispositivo** |
| Ventanas procesadas (50 Hz) | RAM del dispositivo | < 5 segundos | Nunca sale del dispositivo |
| Probabilidad de actividad (float) | RAM del dispositivo | < 1 segundo | Nunca sale del dispositivo |
| Evento de actividad `{tipo, duración}` | Backend DynamoDB | 2 años | Pseudonimizado por `user_id_hash` |
| Alerta de caída `{stage, svm_peak}` | Backend DynamoDB | 90 días | Acceso restringido a centralita |
| Datos de reentrenamiento | S3 (opt-in) | Hasta revocación | Anonimizados antes de ingesta |
| `user_id_hash` | DynamoDB + dispositivo | Vida del contrato | SHA-256 del DNI + salt rotativo |

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
| Descripción del tratamiento | HAR + fall detection on-device, eventos al backend |
| Finalidad y necesidad | VitaPoints + alertas emergencia; alternativas menos intrusivas valoradas |
| Riesgos identificados | Re-identificación, falsos positivos en alertas, fuga de patrones de vida |
| Medidas mitigadoras | On-device inference, pseudonimización, TTL cortos, cifrado en tránsito |
| Consulta al DPO | Sí, antes del lanzamiento |
| Revisión periódica | Anual o cuando cambien arquitectura/modelos |

## Derecho al olvido (Art. 17)

Endpoint obligatorio en el backend:
```
DELETE /users/{user_id}/data
  → Borra todos los eventos en DynamoDB (actividad + caídas)
  → Revoca consentimiento en tabla de consentimientos
  → Elimina datos de S3 de reentrenamiento (si los hubiera cedido)
  → Respuesta: 204 No Content en < 30 días (plazo legal)
```

El `user_id_hash` en dispositivo se elimina al desinstalar la app o en la
opción "Eliminar mi cuenta" de la UI.

## Privacidad por diseño — cumplimiento técnico

| Principio RGPD | Implementación técnica |
|----------------|----------------------|
| Minimización | Señal cruda nunca sale del dispositivo; solo eventos derivados al backend |
| Limitación de finalidad | Datos de actividad ≠ datos de caída; TTL distintos; acceso diferenciado |
| Exactitud | Modelos re-entrenados trimestralmente; usuario puede corregir eventos erróneos |
| Limitación de conservación | TTL nativo en DynamoDB (2 años actividad, 90 días caídas) |
| Integridad y confidencialidad | TLS 1.3 en tránsito; AES-256 en reposo (DynamoDB + S3) |
| Responsabilidad proactiva | DPIA, DPO designado, registros de tratamiento (Art. 30) |

## Transferencias internacionales

AWS eu-west-1 (Irlanda) — dentro del EEE. No se requiere mecanismo adicional.
Si se usa SageMaker en us-east-1 para entrenamiento: aplicar cláusulas contractuales
tipo (SCC) o usar instancias en eu-central-1 (Frankfurt).

## Resumen ejecutivo para la memoria

> Vitalia procesa datos de salud (Art. 9 RGPD) bajo un esquema de **privacidad por
> diseño radical**: la señal cruda de los sensores nunca abandona el dispositivo del
> asegurado. Solo eventos derivados de bajo riesgo (tipo de actividad, duración, alerta
> de caída) se transmiten al backend, pseudonimizados. Este diseño elimina de raíz el
> mayor riesgo de re-identificación y reduce el alcance de la DPIA. La DPIA sigue siendo
> obligatoria por el tratamiento a escala, pero su riesgo residual es bajo.
