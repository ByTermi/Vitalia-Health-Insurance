---
name: extension-chrome
description: "Crea extensiones de Chrome personalizadas desde cero, listas para instalar. Usa esta skill cuando el usuario quiera crear una extensión de navegador, plugin para Chrome, herramienta que funcione en el navegador, o automatizar algo dentro de una web. Triggers: 'extensión Chrome', 'plugin para el navegador', 'extensión que haga X', 'add-on de Chrome', 'herramienta para el navegador', 'quiero una extensión', 'crear extensión', 'chrome extension'."
---

# Extensión Chrome Personalizada

Le dices qué necesitas y Claude genera una extensión de Chrome completa y funcional, lista para instalar en 2 minutos. Manifest V3, popup con diseño premium, y toda la lógica funcionando.

**Regla fundamental: la extensión debe funcionar al instalarla.** Nada de código a medias o funciones placeholder. Todo lo que generes debe ser funcional y testeado.

---

## Paso 1 — Entender qué necesita el usuario

Pregunta:
- **¿Qué quieres que haga la extensión?** — describe el comportamiento que quieres
- **¿En qué webs debe funcionar?** — todas, solo YouTube, solo LinkedIn, webs específicas...
- **¿Necesita una ventanita (popup)?** — si necesita interfaz visible al clickar el icono
- **¿Necesita guardar datos?** — configuración, historial, contadores, notas...

Si el usuario no sabe qué extensión crear, proponle ideas según su contexto:

**Para productividad:** Pomodoro timer, bloqueador de distracciones, contador de tiempo en webs, quick notes
**Para ventas/marketing:** Extractor de emails, extractor de datos de LinkedIn, tracker de precios, captura de leads
**Para desarrollo:** Color picker, inspector de fuentes, medidor de elementos, captura de pantalla
**Para contenido:** Resaltador de texto, traductor hover, lector de artículos limpio, guardador de referencias
**Para uso personal:** Dark mode universal, custom CSS injector, bloqueador de cookies popups, speed controller de vídeos

---

## Paso 2 — Generar la extensión completa

Crea una carpeta con todos los archivos. La estructura depende de lo que necesite:

```
extension-[nombre]/
├── manifest.json       → Configuración (siempre Manifest V3)
├── popup.html          → Interfaz del popup (si aplica)
├── popup.css           → Estilos
├── popup.js            → Lógica del popup
├── content.js          → Script inyectado en las webs (si aplica)
├── background.js       → Service worker (si aplica)
├── styles.css          → Estilos inyectados en webs (si aplica)
└── icons/
    ├── icon16.svg      → Icono 16x16
    ├── icon48.svg      → Icono 48x48
    └── icon128.svg     → Icono 128x128
```

### Manifest V3 (obligatorio)

Siempre usa Manifest V3 (V2 está deprecado). Solo incluye los permisos que realmente necesita:

- `"storage"` — guardar datos del usuario
- `"activeTab"` — acceder a la pestaña actual (al hacer click en la extensión)
- `"tabs"` — gestionar pestañas
- `"scripting"` — inyectar scripts dinámicamente
- `"alarms"` — temporizadores y alarmas
- `"notifications"` — notificaciones del sistema
- `"contextMenus"` — menú click derecho

No pidas `"<all_urls>"` ni permisos amplios si no son necesarios — Chrome los penaliza en la revisión.

### Popup con diseño premium

Si la extensión tiene popup, haz que se vea profesional. Libertad creativa total, pero:
- Ancho fijo razonable (320-400px)
- Tema oscuro o claro según la función
- Fuentes del sistema (no Google Fonts — no se cargan en popups)
- Transiciones suaves
- Estados claros (on/off, activo/inactivo)
- Footer con versión

### Iconos

Genera iconos como SVG — funcionan directamente en Chrome sin conversión:

```svg
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <rect width="128" height="128" rx="28" fill="#667eea"/>
  <text x="50%" y="55%" font-size="56" fill="white" text-anchor="middle" dominant-baseline="middle" font-family="Arial" font-weight="bold">🔥</text>
</svg>
```

Adapta el color y el emoji/texto al propósito de la extensión.

### Content Scripts (si modifica webs)

Si la extensión inyecta contenido en páginas web:
- Usa `matches` específicos, no `"<all_urls>"` cuando sea posible
- Aísla los estilos para no romper la web (usa prefijos únicos en clases CSS)
- Limpia los elementos cuando la extensión se desactiva
- Maneja errores — la web puede cambiar su estructura

### Background Service Worker

Si necesita lógica en segundo plano:
- Recuerda que en Manifest V3 los service workers se duermen — no confíes en variables globales persistentes
- Usa `chrome.storage` para persistir estado
- Usa `chrome.alarms` para tareas periódicas (no `setInterval`)

### Comunicación entre componentes

Si popup, content script y background necesitan comunicarse:
- Popup ↔ Background: `chrome.runtime.sendMessage`
- Content ↔ Background: `chrome.runtime.sendMessage`
- Background → Content: `chrome.tabs.sendMessage`

---

## Paso 3 — Testear

Después de generar todos los archivos:

1. Verifica que `manifest.json` es JSON válido
2. Verifica que todos los archivos referenciados existen
3. Verifica que los permisos son los mínimos necesarios
4. Si puedes, abre la extensión en Chrome para verificar que no hay errores de consola

---

## Paso 4 — Instrucciones de instalación

Crea un `README.md` dentro de la carpeta de la extensión:

```markdown
# [Nombre de la Extensión]

[Descripción de una línea]

## Instalación (2 minutos)

1. Abre Chrome y ve a `chrome://extensions/`
2. Activa **Modo desarrollador** (interruptor en la esquina superior derecha)
3. Click en **Cargar extensión sin empaquetar**
4. Selecciona esta carpeta
5. Verás el icono de la extensión en la barra de herramientas

## Cómo usar

[Instrucciones específicas de la extensión]

## Personalización

[Si aplica: cómo cambiar configuración, colores, webs objetivo, etc.]
```

---

## Paso 5 — Presentar el resultado

Muestra:
1. Nombre de la carpeta generada
2. Lista de archivos creados
3. Funcionalidades implementadas
4. Instrucciones de instalación en 5 pasos
5. Pregunta si quiere ajustar algo (diseño, funcionalidad, webs objetivo)

No muestres precios sugeridos ni consejos de venta.
