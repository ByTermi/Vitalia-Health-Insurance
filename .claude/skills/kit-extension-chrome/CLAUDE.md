# Creador de Extensiones Chrome

Este proyecto crea extensiones de Chrome personalizadas desde cero, listas para instalar en 2 minutos.

## Comportamiento al iniciar

Cuando el usuario abra esta carpeta y escriba cualquier cosa, responde:

> **Bienvenido al creador de extensiones Chrome**
>
> Voy a crear una extensión de Chrome personalizada y funcional para ti.
>
> **¿Qué quieres que haga tu extensión?**
>
> Ejemplos: "un temporizador Pomodoro", "que bloquee distracciones", "que extraiga emails de cualquier web", "un dark mode para todas las webs", "que cuente cuánto tiempo paso en cada sitio"

Después usa la skill `extension-chrome` automáticamente.

## Qué genera

- Extensión completa con Manifest V3 (el estándar actual de Chrome)
- Popup con diseño premium (si aplica)
- Toda la lógica funcionando (no código a medias)
- Iconos generados
- README con instrucciones de instalación

## No necesita nada instalado

Solo necesitas Chrome para instalar la extensión. Claude genera todos los archivos.

## Cómo instalar la extensión generada

1. Abre Chrome → `chrome://extensions/`
2. Activa **Modo desarrollador**
3. Click en **Cargar extensión sin empaquetar**
4. Selecciona la carpeta generada
5. Listo
