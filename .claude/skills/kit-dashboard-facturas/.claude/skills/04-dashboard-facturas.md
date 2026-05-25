---
name: dashboard-facturas
description: "Lee facturas PDF de una carpeta y genera un dashboard visual completo con balances, ingresos, gastos, IVA, evolución temporal y métricas del negocio. Usa esta skill cuando el usuario quiera analizar facturas, ver su facturación, crear un dashboard financiero, revisar ingresos y gastos, o cualquier análisis de documentos contables. Triggers: 'analiza mis facturas', 'dashboard de facturas', 'cuánto he facturado', 'resumen financiero', 'balance de ingresos y gastos', 'métricas de mi negocio', 'gráficos de facturación', 'lee mis facturas PDF'."
---

# Dashboard de Facturas

El usuario te señala una carpeta con facturas en PDF. Tú las lees una a una, extraes todos los datos y generas un dashboard HTML visual con el análisis financiero completo del negocio.

**Regla fundamental: solo reporta datos reales extraídos de las facturas.** No inventes cifras, no redondees para que quede bonito, no asumas datos que no están en los documentos.

---

## Paso 1 — Localizar las facturas

Pregunta al usuario:
- **¿Dónde están tus facturas?** — ruta de la carpeta (ej: `~/facturas/`, `./facturas/`, `/Users/juan/Documents/facturas 2025/`)
- **¿Son todas facturas emitidas (ingresos) o también hay facturas recibidas (gastos)?** — esto cambia completamente el análisis

Si no tiene una carpeta preparada:
> "Crea una carpeta y mete ahí todos tus PDFs de facturas. Puedo leer facturas emitidas (lo que cobras) y recibidas (lo que pagas). Si tienes ambas, ponlas en subcarpetas separadas: `facturas/ingresos/` y `facturas/gastos/`."

```bash
mkdir -p facturas/ingresos facturas/gastos
```

---

## Paso 2 — Leer las facturas

Lee cada PDF de la carpeta directamente con la herramienta Read (Claude Code puede leer PDFs nativamente). No necesitas instalar pdfplumber ni ninguna librería Python.

Para cada factura PDF:
1. Lee el archivo con la herramienta Read
2. Extrae del texto estos campos:

**Datos a extraer de cada factura:**
- **Tipo**: ingreso (factura emitida) o gasto (factura recibida) — inferir del contexto o preguntar al usuario
- **Número de factura**
- **Fecha de emisión**
- **Emisor** (quién factura)
- **Receptor** (a quién se factura)
- **Concepto / descripción de las líneas**
- **Base imponible / subtotal / neto** (importe sin IVA)
- **IVA** (porcentaje y cantidad)
- **IRPF / retenciones** (si aplica — común en España para autónomos)
- **Total factura**
- **Moneda**

**Patrones comunes a buscar:**
- Fechas: `dd/mm/yyyy`, `dd-mm-yyyy`, `dd de mes de yyyy`
- Importes: números seguidos de €, EUR, $, USD
- IVA: "IVA 21%", "I.V.A.", "Tax", porcentajes cerca de importes
- IRPF: "Retención", "IRPF", "-15%", "-7%"
- Totales: "Total", "TOTAL", "Importe total", "Total factura", "Amount due"
- Base: "Base imponible", "Subtotal", "Neto", "Net amount"
- Factura nº: "Factura nº", "Invoice #", "Nº:", patrones tipo F-2025-001, INV-001

**Si un campo no se puede extraer**, márcalo como desconocido. No inventes. Al final del proceso, muestra al usuario las facturas con datos incompletos para que valide.

### Guardar datos extraídos

Guarda todos los datos en un JSON intermedio (`facturas_datos.json`) para que el usuario pueda revisar y corregir si hay errores de extracción:

```json
[
  {
    "archivo": "factura-001.pdf",
    "tipo": "ingreso",
    "numero": "F-2025-001",
    "fecha": "2025-01-15",
    "emisor": "Mi Empresa SL",
    "receptor": "Cliente XYZ",
    "concepto": "Consultoría tecnológica enero",
    "base_imponible": 1500.00,
    "iva_porcentaje": 21,
    "iva_cantidad": 315.00,
    "irpf_porcentaje": -15,
    "irpf_cantidad": -225.00,
    "total": 1590.00,
    "moneda": "EUR"
  }
]
```

Después de extraer todas las facturas, muestra un resumen al usuario:
> "He leído X facturas. Y se leyeron correctamente, Z tuvieron datos incompletos. ¿Quieres revisar los datos antes de generar el dashboard?"

---

## Paso 3 — Calcular métricas

Con los datos extraídos, calcula todo lo que los datos permitan. No fuerces métricas si no hay datos suficientes.

### Métricas principales (si hay datos)

**Ingresos:**
- Facturación total bruta (con IVA)
- Facturación total neta (base imponible)
- IVA repercutido total
- IRPF retenido total (si aplica)
- Factura media
- Factura más alta / más baja

**Gastos (si hay facturas recibidas):**
- Gasto total bruto
- Gasto total neto
- IVA soportado total

**Balance (si hay ingresos y gastos):**
- Balance neto (ingresos netos - gastos netos)
- IVA a pagar/devolver (repercutido - soportado)
- Beneficio antes de impuestos
- Margen (ingresos / gastos)

**Temporal:**
- Evolución mensual de ingresos
- Evolución mensual de gastos (si los hay)
- Mejor mes / peor mes
- Tendencia (comparar últimos 3 meses con anteriores)
- Media mensual
- Meses sin facturación (gaps)

**Clientes:**
- Top clientes por facturación
- Nº de facturas por cliente
- % de facturación que representa cada cliente
- Dependencia de cliente (si un cliente supone >40% del total, alertar)

**IVA trimestral (si son facturas españolas):**
- Desglose Q1, Q2, Q3, Q4
- IVA repercutido por trimestre
- IVA soportado por trimestre (si hay gastos)
- Liquidación estimada por trimestre

---

## Paso 4 — Generar el dashboard HTML

Crea un único archivo HTML autocontenido con todo el análisis. Libertad creativa total en el diseño, pero debe incluir:

### Contenido obligatorio

1. **Header** — Rango de fechas, total de facturas procesadas, facturas con errores si las hay

2. **KPIs principales** — Tarjetas grandes con las cifras más importantes. Adapta las KPIs según lo que haya en los datos:
   - Si solo hay ingresos: facturación total, neto, IVA, ticket medio, nº facturas, nº clientes
   - Si hay ingresos y gastos: añade balance, beneficio, margen, IVA a liquidar
   - Los números deben ser claros, grandes y con formato local (1.234,56 € para España)

3. **Gráfico de evolución temporal** — Barras o líneas mostrando la evolución mes a mes. Si hay ingresos y gastos, mostrar ambos en el mismo gráfico con colores diferentes. Implementar con CSS/SVG puro, sin Chart.js.

4. **Balance por trimestre** — Si los datos lo permiten, desglose trimestral con IVA repercutido, soportado y liquidación estimada

5. **Top clientes** — Tabla ordenada por facturación con barra de progreso visual. Alertar si hay dependencia excesiva de un cliente.

6. **Distribución de conceptos** — Si los conceptos son variados, agrupar por tipo de servicio

7. **Tabla de detalle** — Todas las facturas en una tabla completa con:
   - Fecha, número, emisor/receptor, concepto, neto, IVA, total
   - Ordenable por columna
   - Filtrable por tipo (ingreso/gasto), cliente, mes
   - Indicador visual de ingreso (verde) vs gasto (rojo)

8. **Alertas y observaciones** — Cosas que el usuario debería saber:
   - Facturas sin IVA detectado
   - Meses sin facturación
   - Dependencia de cliente (>40% en uno solo)
   - Tendencia ascendente/descendente
   - Facturas que no se pudieron leer bien
   - IRPF: total retenido en el año (para la declaración)

### Requisitos del dashboard

- Responsive (móvil y escritorio)
- Autocontenido (CSS y JS inline)
- Imprimible / exportable a PDF
- Navegación interna entre secciones
- Números con formato local (separador de miles, decimales, símbolo €)
- Colores: verde para ingresos, rojo para gastos, azul/neutro para totales

---

## Paso 5 — Guardar y presentar

- Guarda el dashboard como `dashboard-facturacion.html`
- Guarda los datos en `facturas_datos.json` (para que el usuario pueda reusar)
- Abre el dashboard automáticamente en el navegador

Presenta un resumen:

1. Facturas leídas correctamente vs con errores
2. Las 3-4 métricas más relevantes en una frase
3. Alertas importantes si las hay
4. Pregunta si quiere ajustar algo o corregir datos de alguna factura

No muestres precios sugeridos ni consejos de venta.
