# Cómo usar este kit

## Requisitos

1. **Visual Studio Code** instalado (descarga en https://code.visualstudio.com)
2. **Extensión de Claude Code** instalada desde el marketplace de VS Code (busca "Claude Code" en extensiones)
3. **Google Chrome** para instalar la extensión generada

## Paso 1 — Abrir este proyecto

1. Abre VS Code
2. Archivo → Abrir carpeta → selecciona esta carpeta (`kit-extension-chrome`)
3. Abre Claude Code desde el panel lateral de VS Code

## Paso 2 — Describir tu extensión

Escribe algo como:

> "Crea una extensión que bloquee YouTube y Twitter de 9 a 17h de lunes a viernes"

> "Quiero una extensión que extraiga todos los emails de cualquier página web"

> "Hazme un Pomodoro timer como extensión de Chrome"

> "Extensión que ponga modo oscuro en cualquier web"

Claude genera todos los archivos de la extensión.

## Paso 3 — Instalar en Chrome

1. Abre Chrome y ve a `chrome://extensions/`
2. Activa **Modo desarrollador** (esquina superior derecha)
3. Click en **Cargar extensión sin empaquetar**
4. Selecciona la carpeta que Claude generó (ej: `extension-pomodoro/`)
5. Verás el icono en la barra de herramientas

## Paso 4 — Ajustar

Si quieres cambiar algo:

> "Cambia el color del popup a azul"
> "Añade que también bloquee Reddit"
> "Que guarde las estadísticas por semana"

## Estructura

```
kit-extension-chrome/
├── CLAUDE.md                          <- Claude lo lee automáticamente
├── INSTRUCCIONES.md                   <- Este archivo
└── .claude/
    └── skills/
        └── 09-extension-chrome.md     <- La skill
```
