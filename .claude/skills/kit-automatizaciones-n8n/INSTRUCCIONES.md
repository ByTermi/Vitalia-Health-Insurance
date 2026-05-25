# Cómo usar este kit

## Requisitos

1. **Visual Studio Code** instalado (descarga en https://code.visualstudio.com)
2. **Extensión de Claude Code** instalada desde el marketplace de VS Code (busca "Claude Code" en extensiones)
3. **Node.js** instalado (descarga en https://nodejs.org — versión LTS)
4. **Una instancia de n8n** funcionando (opcional pero recomendado)

## Paso 1 — Abrir este proyecto

1. Abre VS Code
2. Archivo → Abrir carpeta → selecciona esta carpeta (`kit-automatizaciones-n8n`)
3. Abre Claude Code desde el panel lateral de VS Code

## Paso 2 — Preparar tu n8n (opcional)

Si tienes n8n, necesitas tu API key:
1. Abre tu n8n (ej: http://localhost:5678)
2. Ve a **Settings → API**
3. Click en **Create API Key**
4. Copia la key

Si no tienes n8n, puedes instalarlo gratis:
```bash
npx n8n
```
Esto arranca n8n en http://localhost:5678

## Paso 2 — Abrir en Claude Code

Abre Claude Code y navega hasta esta carpeta.

## Paso 3 — Decir qué quieres automatizar

Escribe algo como:

> "Quiero automatizar la captación de leads: cuando alguien rellena el formulario de mi web, que se guarde en Google Sheets, me llegue un aviso a Slack y se le envíe un email de bienvenida"

O si quieres revisar lo que ya tienes:

> "Revisa mis workflows de n8n y dime qué puedo mejorar"

Claude se encarga de:
1. Instalar las herramientas necesarias (MCP + skills de n8n)
2. Conectar con tu n8n si le das la URL y API key
3. Diseñar el workflow paso a paso
4. Crearlo directamente en tu n8n (o generar JSON para importar)
5. Generar documentación visual del flujo

## Ideas de automatizaciones

Si no sabes por dónde empezar, dile:

> "¿Qué automatizaciones me recomiendas para mi negocio?"

Y Claude te propondrá ideas según tu sector.

## Primera vez

La primera vez que uses este kit, Claude instalará dependencias (~1-2 minutos). Después te pedirá reiniciar Claude Code una vez. A partir de ahí, todo funciona al instante.

## Estructura

```
kit-automatizaciones-n8n/
├── CLAUDE.md                              <- Claude lo lee automáticamente
├── INSTRUCCIONES.md                       <- Este archivo
├── .claude/
│   └── skills/
│       └── 05-automatizaciones-n8n.md     <- La skill
└── .mcp.json                              <- Se crea automáticamente con tu config de n8n
```
