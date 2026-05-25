# Vitalia Health Insurance — Project Instructions

## Project Overview

**Caso 06 de competición académica** (1 semana, jurado: compañeros de clase).
**Equipo:** Íñigo S + Jaime · **Rival (mismo caso):** Santi-Sheimae
Objetivo: construir un sistema de **reconocimiento de actividad física (HAR) on-device** a partir de acelerómetro y giroscopio del smartphone, más **detección de caídas**, para automatizar el programa VitaPoints de Vitalia Health Insurance.

**Stack real del proyecto:**
- **ML pipeline:** Python 3.11 · NumPy · pandas · SciPy · scikit-learn · TensorFlow/Keras → TFLite (inferencia on-device)
- **Demo app:** Flutter (Android) · `tflite_flutter` · `sensors_plus`
- **Notebooks:** Jupyter para EDA, entrenamiento y evaluación
- **Docs:** `docs/PLAN.md` · `docs/TAREAS_INIGO.md` · `docs/TAREAS_JAIME.md`

> **Nota:** El repo arrancó con una plantilla React/Next.js/RTK — ignora esas referencias. El proyecto real es Python/ML + Flutter.

---

## Repo layout

```
├── data/
│   ├── raw/           # Datasets descargados sin modificar
│   └── processed/     # Ventanas preprocesadas, numpy arrays
├── notebooks/         # EDA, entrenamiento, evaluación
├── src/
│   ├── preprocessing/ # Módulo compartido: windowing, normalización, augmentation
│   └── models/        # Definición de arquitecturas HAR y fall detector
├── models/
│   └── tflite/        # Modelos exportados y cuantizados
├── app/               # Flutter demo app (on-device inference)
├── docs/              # Plan y tareas (ver abajo)
├── requirements.txt
└── CLAUDE.md
```

---

## Datasets

| Uso | Dataset | URL | Sensores | Frecuencia | Sujetos |
|-----|---------|-----|----------|------------|---------|
| Actividades (principal) | **UCI HAR #240** | https://archive.ics.uci.edu/dataset/240/human+activity+recognition+using+smartphones | Accel+Gyro smartphone (cintura) | 50 Hz | 30 |
| Actividades (placement) | **MotionSense** | https://github.com/mmalekzadeh/motion-sense | Accel+Gyro smartphone (bolsillo) | 50 Hz | 24 |
| Running + Cycling | **PAMAP2** | https://archive.ics.uci.edu/dataset/231/pamap2+physical+activity+monitoring | Accel+Gyro (body-worn) | 100 Hz → resample 50 | 9 |
| Caídas (principal) | **MobiAct v2** | https://bmi.hmu.gr/the-mobifall-and-mobiact-datasets-2/ | Accel+Gyro smartphone (bolsillo) | ~87 Hz → resample 50 | 66 |
| Caídas (mayores) | **SisFall** | https://pmc.ncbi.nlm.nih.gov/articles/PMC5298771/ | Accel+Gyro (cintura) | 200 Hz → resample 50 | 38 (15 ancianos) |

> **¿Por qué no DSADS (#256)?** Usa 5 unidades Xsens en el cuerpo (no smartphone), solo 25 Hz, 8 sujetos, sin caídas. No aplica para inferencia on-device.

---

## Decisiones técnicas clave

- **Ventaneo:** 2.56 s / 128 muestras @50 Hz, solapamiento 50 % para actividades; ventanas más cortas y detector de pico para caídas.
- **Invarianza de colocación:** signal vector magnitude √(x²+y²+z²) + augmentation por rotación/permutación de ejes + ruido gaussiano + time-warping.
- **Modelo HAR:** 1D-CNN (primario). Justificar vs. RF/SVM baseline, LSTM puro y Transformer.
- **Caídas:** sub-problema binario independiente. Optimizar recall. Cascada: detector de impacto barato → confirmador CNN.
- **Compresión:** TFLite + cuantización int8. Objetivo: <500 KB, <50 ms latencia, duty-cycled para batería.
- **RGPD:** procesado 100 % on-device; solo eventos derivados al backend.

---

## Skills útiles para ESTE proyecto

### Prioritarias
| Skill | Cuándo usarla |
|-------|---------------|
| `/legal` | Sección RGPD/datos de salud en la memoria — **obligatoria** |
| `/security` | Revisar privacidad on-device, secrets, exposición de datos |
| `/serverless-backend` | Diseñar arquitectura de producción teórica (backend alertas, OTA modelos) |
| `/graphify` | Generar diagrama de arquitectura para la memoria |
| `/market-analysis` | Modelo de coste CapEx+OpEx y análisis competitivo (vs Vitality, Generali) |
| `/cross-platform-dev` | Flutter demo app con TFLite on-device |
| `/android-development` | Si se necesita código nativo Android |
| `/research` | Buscar papers, benchmarks de modelos HAR ligeros |
| `/verify` | Verificar fuentes de datasets y papers antes de citar |
| `/find-skills` | Descubrir e instalar skills adicionales si se necesita algo (ML, data-science, etc.) |

### Calidad de código
`/bug-finder` · `/code-review` · `/security-review` · `/dep-audit`

### Workflow y docs
`/project` · `/capture` · `/loop` (entrenamientos largos) · `/schedule` · `/forge-skill`

### No relevantes para este proyecto
`/seo`, `/marketing`, `/i18n`, `/ad-supported-frontend`, `/a11y`, `/lighthouse`, `/visual-qa`, `/perf-profiler` (son skills de proyectos web)

---

## Skills disponibles en `.claude/skills/`

Todas las skills globales están copiadas aquí para que ambos miembros del equipo las tengan disponibles sin instalar nada extra. La skill `/find-skills` también está en `.agents/skills/find-skills/` (con symlink en `.claude/skills/`).

> **Nota de portabilidad:** las skills que escriben al Obsidian Vault (`E:\obsidian\…`) solo funcionan completamente en el PC propietario de la vault. En otros equipos, la lógica de modelado funciona igual; solo fallan las llamadas de escritura al vault.

> **Excluidas de la copia:** `proficiently/` (job-search personal) y `travel-hub` (proyecto no relacionado).

---

## Comandos de desarrollo

```bash
# Entorno Python
python -m venv .venv && source .venv/bin/activate   # Linux/Mac
python -m venv .venv && .venv\Scripts\activate       # Windows
pip install -r requirements.txt

# Notebooks
jupyter notebook notebooks/

# Flutter app
cd app && flutter pub get && flutter run

# Tests rápidos del pipeline
python -m pytest src/
```

---

## Flujo de trabajo en equipo

1. Íñigo trabaja en rama `inigo/...`; Jaime en `jaime/...`.
2. Usar `/code-review` antes de mergear a `main`.
3. Documentar decisiones relevantes en `docs/PLAN.md`.
4. **Punto de sincronización:** fin del Día 1 — acordar módulo de preprocesado compartido antes de separarse.
5. **Punto de integración:** Día 5 — ambos modelos TFLite integrados en la app Flutter.

---

## Plan y tareas

- **Plan global:** `docs/PLAN.md`
- **Tareas Íñigo** (actividades + compresión): `docs/TAREAS_INIGO.md`
- **Tareas Jaime** (caídas + arquitectura + app): `docs/TAREAS_JAIME.md`

---

## Sesión — protocolo de inicio

1. Leer este archivo.
2. `git log --oneline -5` para ver el estado reciente.
3. Revisar qué tareas quedan en tu archivo de tareas.
