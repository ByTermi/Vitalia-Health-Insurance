---
name: legal
description: "Legal consultant for Spanish websites: generates compliant Aviso Legal, Política de Privacidad, Política de Cookies, and AdSense-specific compliance documents. Covers GDPR, LOPDGDD, LSSI, and AEPD guidelines. Trigger: /legal"
trigger: /legal
---

# /legal

Legal compliance for websites operating under Spanish law. Generates all required legal pages, audits existing ones, and handles the specific requirements of GDPR (EU), LOPDGDD (Spanish GDPR adaptation), LSSI (Spanish e-commerce law), and AdSense compliance.

## Jurisdiction: Spain

**Applicable laws:**
- **GDPR** (Reglamento General de Protección de Datos, UE 2016/679)
- **LOPDGDD** (Ley Orgánica 3/2018 de Protección de Datos Personales y Garantía de Derechos Digitales)
- **LSSI** (Ley 34/2002 de Servicios de la Sociedad de la Información y de Comercio Electrónico)
- **AEPD** guidelines (Agencia Española de Protección de Datos)
- **Google EU User Consent Policy** (for AdSense/AdMob publishers)

## Usage

```
/legal                                # full legal audit of current project
/legal --aviso-legal                  # generate Aviso Legal (required by LSSI)
/legal --privacidad                   # generate Política de Privacidad (GDPR/LOPDGDD)
/legal --cookies                      # generate Política de Cookies (LSSI)
/legal --cookies --adsense            # cookie policy specifically for AdSense sites
/legal --terminos                     # generate Términos y Condiciones
/legal --audit                        # audit existing legal pages for compliance gaps
/legal --consent                      # generate cookie consent banner config
/legal --checklist                    # full legal checklist for a new Spanish website
/legal --question "<question>"        # answer a specific legal question (non-binding guidance)
```

**Important:** This skill provides guidance based on current law and best practices. It is not a substitute for advice from a licensed Spanish lawyer (abogado). For matters with significant legal or financial risk, consult a qualified professional.

---

## What You Must Do When Invoked

Ask for the following before generating any document if not provided:

```
Para generar los documentos legales necesito:

1. Nombre del sitio web y URL completa
2. Nombre completo del titular (persona física o razón social)
3. NIF/CIF del titular
4. Dirección postal completa
5. Email de contacto
6. ¿El sitio usa Google AdSense? (sí/no)
7. ¿El sitio recoge algún dato de usuarios? (formularios, newsletter, comentarios...)
8. ¿Tiene domicilio social en España? (necesario para LSSI)
```

---

### /legal --checklist — Full legal checklist for a new Spanish website

```
Legal Checklist — Sitio web español con AdSense
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OBLIGATORIO por LSSI (Ley 34/2002)
  [ ] Aviso Legal publicado y accesible desde todas las páginas (footer)
  [ ] Contiene: nombre/razón social, NIF, dirección, email, datos de inscripción
        si es empresa mercantil

OBLIGATORIO por GDPR + LOPDGDD
  [ ] Política de Privacidad publicada y accesible
  [ ] Registros de actividades de tratamiento (aunque sea solo AdSense cookies)
  [ ] Si usas formularios: base jurídica para cada tratamiento de datos
  [ ] Si envías newsletters: consentimiento explícito previo

OBLIGATORIO por LSSI + GDPR para cookies
  [ ] Política de Cookies publicada
  [ ] Banner de consentimiento de cookies ANTES de que se cargue ninguna cookie
  [ ] El rechazo debe ser igual de fácil que la aceptación (AEPD 2023)
  [ ] Botón "Rechazar" o "Continuar sin aceptar" visible en el banner
  [ ] Opción de gestionar preferencias granulares (por categoría de cookie)
  [ ] Enlace a "Configuración de cookies" siempre accesible (footer)
  [ ] Consentimiento almacenado en cookie propia (no localStorage)
  [ ] No se carga AdSense hasta recibir consentimiento

ESPECÍFICO para AdSense
  [ ] Política de Privacidad menciona explícitamente a Google AdSense
  [ ] Enlace a política de privacidad de Google incluido
  [ ] Menciona uso de cookies de publicidad personalizada (DoubleClick)
  [ ] Enlace al opt-out de Google: https://www.google.com/settings/ads
  [ ] Cumples con la Google EU User Consent Policy
  [ ] Cuenta de AdSense en buen estado (no incumples políticas de contenido)

RECOMENDADO (no obligatorio pero protege de reclamaciones)
  [ ] Términos y Condiciones si los usuarios pueden interactuar con el contenido
  [ ] Aviso de afiliación si usas links de afiliados además de AdSense
  [ ] Fecha de última actualización en todos los documentos legales
```

---

### /legal --aviso-legal — Generate Aviso Legal

The Aviso Legal is required by LSSI Art. 10. Generate using the user's data:

```markdown
# Aviso Legal

En cumplimiento de lo dispuesto en el artículo 10 de la Ley 34/2002, de 11 de julio, 
de Servicios de la Sociedad de la Información y de Comercio Electrónico (LSSI-CE), 
se informa a los usuarios del sitio web de los siguientes datos identificativos:

## Datos del titular

- **Titular:** [NOMBRE COMPLETO / RAZÓN SOCIAL]
- **NIF/CIF:** [NIF]
- **Domicilio:** [DIRECCIÓN COMPLETA, CP, CIUDAD, ESPAÑA]
- **Email:** [EMAIL]
- **Sitio web:** [URL]

[Si es empresa: **Datos registrales:** Inscrita en el Registro Mercantil de [Ciudad], 
tomo [X], folio [X], sección [X], hoja [X].]

## Objeto

El presente Aviso Legal regula el acceso y uso del sitio web **[URL]** (en adelante, 
"el Sitio"), del que es titular [NOMBRE].

## Condiciones de uso

El acceso al Sitio es gratuito y no requiere registro previo. El usuario se compromete 
a hacer un uso adecuado de los contenidos y servicios que se ofrecen a través del Sitio 
y con carácter enunciativo, pero no limitativo, a no emplearlos para incurrir en 
actividades ilícitas o contrarias a la buena fe y al orden público.

## Propiedad intelectual e industrial

El titular es propietario de todos los derechos de propiedad intelectual e industrial 
del Sitio, así como de los elementos contenidos en el mismo (a título enunciativo: imágenes, 
sonido, audio, vídeo, software o textos; marcas o logotipos, combinaciones de colores, 
estructura y diseño, selección de materiales usados, programas de ordenador necesarios 
para su funcionamiento, acceso y uso, etc.).

Todos los derechos reservados. En virtud de lo dispuesto en los artículos 8 y 32.1, 
párrafo segundo, de la Ley de Propiedad Intelectual, quedan expresamente prohibidas 
la reproducción, la distribución y la comunicación pública, incluida su modalidad de 
puesta a disposición, de la totalidad o parte de los contenidos de este sitio web, 
con fines comerciales, en cualquier soporte y por cualquier medio técnico, sin la 
autorización del titular.

## Exclusión de garantías y responsabilidad

El titular no se hace responsable, en ningún caso, de los daños y perjuicios de 
cualquier naturaleza que pudieran ocasionar, a título enunciativo: errores u omisiones 
en los contenidos, falta de disponibilidad del portal o la transmisión de virus o 
programas maliciosos o lesivos en los contenidos, a pesar de haber adoptado todas 
las medidas tecnológicas necesarias para evitarlo.

## Publicidad

El Sitio puede incluir espacios publicitarios gestionados por terceros (Google AdSense). 
Dichos anunciantes pueden utilizar cookies y tecnologías similares para mostrar 
publicidad basada en sus visitas previas al presente sitio web y a otros sitios web. 
Para más información, consulte la [Política de Cookies](#) y la [Política de Privacidad](#).

## Ley aplicable y jurisdicción

Para la resolución de todas las controversias o cuestiones relacionadas con el presente 
sitio web o de las actividades en él desarrolladas, será de aplicación la legislación 
española, a la que se someten expresamente las partes, siendo competentes para la 
resolución de todos los conflictos derivados o relacionados con su uso los Juzgados 
y Tribunales de [CIUDAD DEL TITULAR].

*Última actualización: [FECHA]*
```

---

### /legal --privacidad — Generate Política de Privacidad

```markdown
# Política de Privacidad

*Última actualización: [FECHA]*

En cumplimiento del Reglamento (UE) 2016/679 del Parlamento Europeo y del Consejo 
(RGPD) y de la Ley Orgánica 3/2018 de Protección de Datos Personales y Garantía 
de Derechos Digitales (LOPDGDD), le informamos sobre el tratamiento de sus datos 
personales.

## Responsable del tratamiento

| Dato | Información |
|------|-------------|
| Responsable | [NOMBRE / RAZÓN SOCIAL] |
| NIF/CIF | [NIF] |
| Dirección | [DIRECCIÓN] |
| Email | [EMAIL] |
| DPD | No obligatorio para este tipo de sitio |

## Datos que tratamos

**El presente sitio web no recoge ni almacena datos personales identificativos 
de sus usuarios de forma directa.**

Sin embargo, al navegar por este sitio puede producirse el tratamiento de datos 
de forma indirecta a través de:

### Cookies y tecnologías de seguimiento

Google AdSense, el servicio de publicidad utilizado en este sitio, puede utilizar 
cookies para mostrar anuncios relevantes. Google actúa como responsable independiente 
del tratamiento de datos a través de estos servicios.

Para más información sobre cómo Google utiliza los datos: 
https://policies.google.com/privacy

### Datos de acceso (logs del servidor)

Nuestro proveedor de hosting registra automáticamente datos técnicos como:
- Dirección IP (anonimizada tras 24h)
- Navegador y sistema operativo
- Páginas visitadas y tiempo de sesión
- Fecha y hora de acceso

**Base jurídica:** Interés legítimo (Art. 6.1.f RGPD) en la seguridad del sitio.

**Plazo de conservación:** 30 días.

[INCLUIR SI HAY FORMULARIO DE CONTACTO:]
### Formulario de contacto
Si nos envía un mensaje a través del formulario de contacto, tratamos:
- Nombre
- Email
- Contenido del mensaje

**Base jurídica:** Consentimiento del interesado (Art. 6.1.a RGPD).
**Plazo de conservación:** Mientras dure la relación y 3 años adicionales.

## Publicidad de Google AdSense

Este sitio web utiliza Google AdSense, un servicio de publicidad de Google Ireland 
Limited (Gordon House, Barrow Street, Dublín 4, Irlanda).

Google AdSense utiliza las denominadas "cookies publicitarias" para mostrar anuncios 
basados en sus visitas anteriores a este y otros sitios web.

Puede desactivar el uso de cookies por parte de Google accediendo a:
https://www.google.com/settings/ads

Puede encontrar más información sobre la política de privacidad de Google en:
https://policies.google.com/privacy

## Sus derechos

Tiene derecho a:
- **Acceso:** conocer qué datos tratamos sobre usted
- **Rectificación:** corregir datos inexactos
- **Supresión:** solicitar la eliminación de sus datos
- **Limitación:** restringir el tratamiento en determinadas circunstancias
- **Portabilidad:** recibir sus datos en formato estructurado
- **Oposición:** oponerse al tratamiento basado en interés legítimo

Para ejercer estos derechos, contacte en: [EMAIL]

También tiene derecho a presentar una reclamación ante la **Agencia Española de 
Protección de Datos (AEPD)**: www.aepd.es

## Transferencias internacionales

Google AdSense puede transferir datos a servidores fuera del Espacio Económico 
Europeo. Google garantiza estas transferencias mediante las Cláusulas Contractuales 
Tipo aprobadas por la Comisión Europea.

## Cambios en esta política

Nos reservamos el derecho a modificar esta política para adaptarla a novedades 
legislativas o jurisprudenciales. Le recomendamos revisarla periódicamente.
```

---

### /legal --cookies --adsense — Cookie Policy for AdSense sites

```markdown
# Política de Cookies

*Última actualización: [FECHA]*

## ¿Qué son las cookies?

Las cookies son pequeños archivos de texto que los sitios web almacenan en su 
dispositivo cuando los visita. Se utilizan ampliamente para hacer que los sitios 
web funcionen correctamente y para proporcionar información a los propietarios del sitio.

## Cookies que utilizamos

### Cookies propias

| Cookie | Finalidad | Duración |
|--------|-----------|----------|
| `cc_cookie` | Almacena su preferencia de consentimiento de cookies | 1 año |

### Cookies de terceros — Google AdSense

Este sitio web utiliza Google AdSense para mostrar publicidad. Google utiliza 
cookies para mostrar anuncios basados en sus visitas a este y otros sitios web.

| Cookie | Origen | Finalidad | Duración |
|--------|--------|-----------|----------|
| `IDE` | doubleclick.net | Publicidad personalizada | 13 meses |
| `DSID` | doubleclick.net | Identificación de usuario para publicidad | 2 semanas |
| `_gads` | google.com | Vinculación actividad a dispositivo para publicidad | 13 meses |
| `ar_debug` | google.com | Debug de anuncios | Sesión |

Para más información sobre las cookies de Google:
https://policies.google.com/technologies/cookies

## Su elección

Al acceder por primera vez a este sitio, se le mostrará un banner donde podrá:

- **Aceptar todas las cookies:** permitir todas las cookies, incluyendo las publicitarias
- **Rechazar:** solo se instalarán las cookies técnicas estrictamente necesarias
- **Configurar:** elegir qué categorías de cookies acepta

Su elección se recuerda durante 1 año. Puede cambiarla en cualquier momento 
desde el enlace "Configuración de cookies" en el pie de página.

**Si rechaza las cookies publicitarias**, la publicidad que aparezca será 
publicidad no personalizada (contextual). La funcionalidad del sitio no se verá afectada.

## Cómo eliminar cookies

Puede eliminar o bloquear cookies desde la configuración de su navegador:
- [Chrome](https://support.google.com/chrome/answer/95647)
- [Firefox](https://support.mozilla.org/es/kb/habilitar-y-deshabilitar-cookies-que-los-sitios-we)
- [Safari](https://support.apple.com/es-es/guide/safari/sfri11471/mac)
- [Edge](https://support.microsoft.com/es-es/windows/eliminar-y-administrar-cookies-168dab11-0753-043d-7c16-ede5947fc64d)

## Opt-out de publicidad de Google

Para desactivar la publicidad personalizada de Google:
https://www.google.com/settings/ads

Para desactivar el uso de cookies por parte de redes publicitarias:
http://www.youronlinechoices.com/es/

## Base jurídica

El tratamiento de datos mediante cookies publicitarias se basa en su 
**consentimiento** (Art. 6.1.a RGPD). Puede retirarlo en cualquier momento.

## Más información

Consulte también nuestra [Política de Privacidad](#privacidad) y el 
[Aviso Legal](#aviso-legal).

Para cualquier consulta: [EMAIL]
```

---

### /legal --consent — Generate consent banner configuration

Generate the `vanilla-cookieconsent` configuration for a Spanish AdSense site:

```ts
// src/lib/cookieconsent.ts
import 'vanilla-cookieconsent/dist/cookieconsent.css'
import * as CookieConsent from 'vanilla-cookieconsent'

export function initCookieConsent() {
  CookieConsent.run({
    guiOptions: {
      consentModal: {
        layout: 'box',
        position: 'bottom left',
        flipButtons: false,
        equalWeightButtons: true, // AEPD requirement: reject = same prominence as accept
      },
      preferencesModal: {
        layout: 'box',
        position: 'right',
      },
    },

    categories: {
      necessary: {
        enabled: true,
        readOnly: true, // cannot be disabled
      },
      analytics: {
        enabled: false, // off by default — user must opt in
        autoClear: {
          cookies: [{ name: /^_ga/ }, { name: '_gid' }],
        },
      },
      advertising: {
        enabled: false, // off by default — AdSense requires consent
        autoClear: {
          cookies: [
            { name: 'IDE', domain: '.doubleclick.net' },
            { name: '_gads' },
            { name: 'ar_debug' },
          ],
        },
        onAccept: () => {
          // Load AdSense script after consent
          const script = document.createElement('script')
          script.async = true
          script.src = 'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-XXXXXXXX'
          script.crossOrigin = 'anonymous'
          document.head.appendChild(script)
        },
        onReject: () => {
          // Non-personalized ads — tell AdSense to serve contextual only
          window.adsbygoogle = window.adsbygoogle || []
          window.adsbygoogle.push({ google_ad_client: 'ca-pub-XXXXXXXX', enable_page_level_ads: true })
          // Set non-personalized ads flag
          window.googletag = window.googletag || { cmd: [] }
          window.googletag.cmd.push(() => {
            window.googletag.pubads().setRequestNonPersonalizedAds(1)
          })
        },
      },
    },

    language: {
      default: 'es',
      translations: {
        es: {
          consentModal: {
            title: 'Usamos cookies',
            description:
              'Utilizamos cookies propias y de terceros para mostrar publicidad personalizada. ' +
              'Puede aceptarlas, rechazarlas o configurar sus preferencias. ' +
              'Si rechaza, solo se utilizarán cookies técnicas y la publicidad no será personalizada.',
            acceptAllBtn: 'Aceptar todas',
            acceptNecessaryBtn: 'Continuar sin aceptar', // AEPD 2023: must be visible
            showPreferencesBtn: 'Gestionar preferencias',
            footer: '<a href="/politica-privacidad">Privacidad</a> · <a href="/politica-cookies">Cookies</a>',
          },
          preferencesModal: {
            title: 'Preferencias de cookies',
            acceptAllBtn: 'Aceptar todas',
            acceptNecessaryBtn: 'Rechazar todas',
            savePreferencesBtn: 'Guardar preferencias',
            closeIconLabel: 'Cerrar',
            sections: [
              {
                title: 'Cookies necesarias',
                description: 'Estas cookies son imprescindibles para el funcionamiento del sitio y no pueden desactivarse.',
                linkedCategory: 'necessary',
              },
              {
                title: 'Cookies publicitarias',
                description:
                  'Utilizadas por Google AdSense para mostrar publicidad personalizada basada en su historial de navegación. ' +
                  'Si las rechaza, seguirá viendo publicidad pero no personalizada.',
                linkedCategory: 'advertising',
              },
            ],
          },
        },
        en: {
          consentModal: {
            title: 'We use cookies',
            description:
              'We use cookies to show personalized advertising. You can accept, reject, or manage your preferences.',
            acceptAllBtn: 'Accept all',
            acceptNecessaryBtn: 'Continue without accepting',
            showPreferencesBtn: 'Manage preferences',
          },
          // ... (add all 7 locales)
        },
      },
    },
  })
}
```

---

### /legal --audit — Audit existing legal pages

Read the project's legal pages (look in `src/app/`, `public/`, or ask for URLs). Check:

**Aviso Legal:**
- [ ] Nombre/razón social del titular
- [ ] NIF/CIF presente
- [ ] Dirección postal española
- [ ] Email de contacto
- [ ] Datos registrales si es empresa
- [ ] Accessible from footer on every page

**Política de Privacidad:**
- [ ] Identifica al responsable del tratamiento
- [ ] Menciona Google AdSense explícitamente si se usa
- [ ] Incluye enlace a configuración de anuncios de Google
- [ ] Lista los derechos del usuario (ARCO+)
- [ ] Menciona la AEPD como organismo de reclamación
- [ ] Indica plazo de conservación de datos

**Política de Cookies:**
- [ ] Lista todas las cookies (propias y de terceros)
- [ ] Identifica la finalidad de cada cookie
- [ ] Indica duración de cada cookie
- [ ] Incluye instrucciones para eliminar/bloquear cookies
- [ ] Base jurídica: consentimiento para cookies no esenciales
- [ ] Enlace a opt-out de Google Ads

**Banner de consentimiento:**
- [ ] Aparece antes de que se cargue cualquier cookie no esencial
- [ ] Botón de rechazo visible e igual de prominente que el de aceptación
- [ ] No hay casillas pre-marcadas
- [ ] Enlace a Política de Cookies en el banner
- [ ] Opción de gestionar preferencias por categoría

Output: pass/fail per item with specific fix instructions.

---

### /legal --question "<question>" — Legal question

Answer the legal question with guidance based on Spanish law. Always end with:

"*Este texto es orientativo y no constituye asesoramiento jurídico. Para situaciones con implicaciones legales o económicas significativas, consulta con un abogado especializado en derecho digital.*"

Common questions to handle well:
- "¿Necesito registro de actividades de tratamiento si solo uso AdSense?" → Sí, aunque sea mínimo
- "¿Puedo usar Google Analytics sin consentimiento en España?" → No desde 2022 (resolución AEPD)
- "¿Necesito Terms of Service si es solo un blog?" → No obligatorio, pero recomendable
- "¿Puedo tener el sitio en inglés y cumplir la LSSI?" → El Aviso Legal debe estar accesible, la lengua es flexible pero el contenido obligatorio debe ser comprensible
- "¿AdSense funciona con cookies de rechazo?" → Sí, muestra publicidad contextual no personalizada

---

## Key Spanish legal facts (always apply)

- **LSSI Aviso Legal** is mandatory even if you collect zero data — it identifies the website owner. Fine for omission: up to €30,000.
- **AEPD (2023 guideline):** The reject button must be as visible and easy as the accept button. "X to close = accept" is NOT compliant.
- **Google Analytics + Spain:** The AEPD issued resolutions in 2022 declaring GA4 non-compliant without explicit consent due to US data transfers. Use Plausible or configure GA4 with server-side proxying + consent.
- **Cookies from AdSense:** Even if you don't "collect" user data yourself, AdSense sets cookies = you need a cookie banner and policy.
- **Newsletter opt-in:** Double opt-in is required (Law 34/2002 + GDPR). Pre-checked boxes are illegal.
- **Age:** Content accessible to minors under 14 requires specific protections under LOPDGDD Art. 7.

---

## Honesty Rules

- Always label guidance as non-binding. Spanish law changes — verify with the AEPD website for current guidance.
- Never tell the user they are "fully compliant" — compliance is a continuous process, not a checkbox.
- AEPD has fined companies up to €300,000 for GDPR violations. Undersell risk at your peril.
- Recommend consulting an abogado especializado en derecho digital for anything involving personal data collection, employee data, or significant commercial transactions.
