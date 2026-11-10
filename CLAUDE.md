# CLAUDE.md — eortega-dev (portal personal)

## Qué es esto

Portal personal de portafolio para mostrar los proyectos de Esteban (incluido telemetry-pipeline una vez listo). En vivo en **https://eortega.dev**.

## Regla de autoría

División de trabajo explícita:

- **Claude** ayuda con la generación del frontend: estructura, diseño, scaffold de React, configuración de deployment/CI. Esto es presentación, no la pieza que demuestra código propio.
- **Esteban** construye el backend de este servicio: la API, la autenticación JWT, el acceso a datos. Claude ayuda a diseñar el contrato de la API y revisa cuando hay código (igual que en telemetry-pipeline: solo hallazgos, nunca corrige), pero no escribe la implementación del backend.

## Regla de idioma

- **Este CLAUDE.md puede estar en español.**
- **Todo lo demás va en inglés**: código, identificadores (incluidos IDs/anchors HTML como `#about`), comentarios, mensajes de scripts, nombres y descripciones de workflows, mensajes de commit, títulos y descripciones de PRs, y cualquier documentación del repo (README, docs/). Es el estándar y el público objetivo son mayormente multinacionales.
- Excepción temporal: el **texto visible del sitio** sigue en español hasta implementar i18n (ver pendientes); con i18n pasa a archivos de traducción por idioma.
- El historial de git anterior a esta regla (10 nov 2026) quedó en español; no se reescribe.

## Stack decidido

- Frontend: React 18 (Vite)
- Backend: ASP.NET Core Web API (stack habitual de Esteban) con JWT

## Hosting y presupuesto (decidido)

- **Frontend**: Azure Static Web Apps, SKU Free ($0), en la cuenta **personal** de Azure (eortega1793@hotmail.com, suscripción Pay-As-You-Go), resource group `eortega-dev`, región **Central US** (tanto el RG como el Static Web App; antes este archivo decía West Europe por error). Al ser PAYG: no añadir recursos facturables sin confirmarlo explícitamente.
  - No se usa la suscripción "Azure for Students" (tenant ULatina): tiene una Azure Policy institucional que solo permite belgiumcentral, switzerlandnorth, norwayeast, germanywestcentral, spaincentral, y Static Web Apps solo existe en centralus, eastus2, westus2, westeurope, eastasia — cero intersección. Esteban podría modificar esa política pero decidió no tocarla.
  - Ojo: el `az` local por defecto queda logueado en la cuenta de ULatina. Para operar el portal hay que `az login` / `az account set` a la suscripción personal.
- **Backend**: VM Always Free de Oracle Cloud (VM.Standard.A1.Flex, 2 OCPU / 12GB RAM, ARM) corriendo el backend en Docker. Se eligió sobre Azure Container Apps porque el portal debe estar siempre disponible para reclutadores sin demora de cold-start. Costo: $0 de por vida.
  - Riesgo a mitigar: Oracle puede reclamar la instancia si se mantiene con menos del 20% de uso de CPU/red durante 7 días seguidos. Se resuelve con un health-check programado que la toque periódicamente.
  - Exposición: Cloudflare Tunnel (`cloudflared`) hacia `api.eortega.dev` — sin abrir puertos ni manejar IP pública/firewall, SSL gestionado en el borde.
- **Evaluado y descartado**: Hostinger Premium (shared hosting, no soporta ASP.NET Core) y Hostinger VPS (funcionaría vía Docker, pero se prefirió la opción gratuita de Oracle).
- La cuenta Azure for Students ($100 USD de crédito) queda reservada para telemetry-pipeline (SQL Server, Log Analytics), no para el portal.

## Dominio y DNS (en vivo)

- **eortega.dev** registrado en **Cloudflare Registrar** ($8.20 primer año / $12.20 renovación), vence el 9 nov 2027, auto-renovación activada. Se eligió Cloudflare sobre Porkbun principalmente por Cloudflare Tunnel gratis para el backend. Cloudflare Registrar obliga a usar su DNS, lo cual no es problema.
  - Descartado: dominio gratis vía GitHub Student Developer Pack (la cuenta estebanortega-ulatina está verificada como Faculty, no Student; la cuenta e-ortega no tiene beneficio educativo). También descartados Name.com (renovaciones infladas) y el "dominio gratis" de Hostinger (atado a su hosting).
- DNS en Cloudflare:
  - CNAME `@` → `polite-hill-0de7df110.5.azurestaticapps.net`, **Proxied** (naranja), SSL/TLS mode **Full**, IPv6 Compatibility **desactivado**.
  - TXT `@` de validación del dominio custom de Static Web Apps.
  - CNAME `www` → `eortega.dev`, **Proxied** (10 nov 2026; antes era un A a 20.75.112.13, una IP de Azure). La redirección la hace una Cloudflare Redirect Rule (plantilla "Redirect from WWW to root", 301 a `https://eortega.dev/...` preservando el path) en el borde: Azure no conoce `www` (responde 404 a ese Host), así que el registro solo existe para que Cloudflare atienda el host y **tiene que seguir Proxied**. Apunta a la raíz y no a Azure para sobrevivir a un destroy/recreate del Static Web App.
  - `http://www.eortega.dev` responde 404 (la regla solo matchea https). Impacto real casi nulo porque `.dev` está en la lista HSTS preload (los navegadores siempre usan https), pero se arregla activando "Always Use HTTPS" en SSL/TLS → Edge Certificates.
- Por qué Proxied (fix del 10 nov 2026): el sitio no cargaba en laptops Windows (Chrome/Edge) pero sí en iPhone. Causa probable: registros AAAA vía Cloudflare + Windows prefiriendo IPv6 por una ruta que fallaba en esa red. Con Proxied + IPv6 Compatibility off quedó resuelto.
- TLS: el borde lo sirve Cloudflare; Azure además gestiona su certificado del dominio custom (renovación automática).

## Email del dominio (configurado y probado)

- Cloudflare Email Routing activo, catch-all (y hola@) reenviando a eortega1793@hotmail.com.
- Un solo registro SPF (`include:_spf.mx.cloudflare.net`). Hubo un conflicto inicial por tener además un `v=spf1 -all` viejo; se borró — no volver a agregar un segundo SPF.
- DMARC `p=reject` con alineación estricta (adkim=s; aspf=s), soportado por el DKIM que Cloudflare auto-generó (`cf2024-1._domainkey`).
- Confirmado con correo de prueba real el 10 nov 2026.

## Infraestructura como código + CI/CD

Pedido explícito de Esteban: reproducibilidad y poder "escalar a 0"/recrear limpio durante la etapa de desarrollo.

- `infra/main.bicep` (scope: resource group) + `infra/main.bicepparam`: Static Web App (SKU Free, previews por PR habilitados) y el dominio custom `eortega.dev`. El nombre del recurso viene de la variable de repo `SWA_NAME`.
- `infra/bootstrap.sh`: lo que Bicep no maneja, se corre una vez desde Git Bash con sesión en la cuenta personal: crea el RG, una app registration `github-actions-eortega-dev` con federated credentials OIDC (rama main + pull_request, sin secretos), rol **Contributor solo sobre el RG** (no sobre la suscripción PAYG), y las variables del repo (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, `SWA_NAME`). Detecta el Static Web App existente para que Bicep lo adopte en vez de crear otro.
- `.github/workflows/infra.yml`: what-if en PRs que tocan `infra/`, deploy en push a main, y `workflow_dispatch` con `deploy` / `destroy` (destroy borra solo el Static Web App, pide escribir su nombre para confirmar; RG e identidad se quedan para poder recrear).
- `.github/workflows/frontend.yml`: build con Node 22 LTS (`npm ci && npm run build`) y deploy de `dist/` con `Azure/static-web-apps-deploy`. El token de deploy se pide a Azure en cada corrida vía OIDC, así que recrear el recurso no exige actualizar secretos. Previews por PR y cierre al cerrar el PR.
- El workflow que Azure generó al crear el recurso desde el portal (`azure-static-web-apps-polite-hill-0de7df110.yml`, usa el secreto `AZURE_STATIC_WEB_APPS_API_TOKEN_POLITE_HILL_0DE7DF110`) se conserva en el repo como referencia, por decisión de Esteban — no borrarlo. Mientras esté activo, cada push a main dispara dos deploys del frontend (el viejo y `frontend.yml`); la opción para que quede solo como referencia es deshabilitarlo con `gh workflow disable` sin tocar el archivo.
- Estado (10 nov 2026): bootstrap corrido y Bicep aplicado manualmente con éxito sobre el recurso existente (deployment `swa-manual-bootstrap`); sitio y dominio verificados después (HTTP 200, dominio `Ready`). Lecciones de esa primera corrida:
  - El recurso estaba conectado a GitHub (lo creó el portal). Se desconectó con `az staticwebapp disconnect` (lo corrió Esteban); ahora `provider: None`, sin repositoryUrl/branch.
  - `deploymentAuthPolicy` quedó en `GitHub` tras el disconnect. Con esa política el deploy falla de las dos formas: con `github_id_token` el servidor busca el sitio por el nombre del archivo de workflow (exige `azure-static-web-apps-<adj>-<noun>-<hex>.yml`), y con solo el token responde "api key invalid". Se cambió a `DeploymentToken` una sola vez con `az rest --method patch` sobre el recurso, pasando `repositoryToken` (PAT fine-grained temporal, ya descartable) + `buildProperties` (appLocation `/`, outputLocation `dist`, `skipGithubActionWorkflowGeneration: true`); sin ambos ARM lo rechaza. Bicep no declara la propiedad por eso mismo. `frontend.yml` deploya solo con el token.
  - El `az` de Windows emite CRLF: en Git Bash cada `$(az ...)` trae un `\r` pegado (rompía comparaciones y el appId). `bootstrap.sh` lo limpia con un wrapper de `az`. `gh` no estaba en el PATH del bash lanzado desde PowerShell; las variables del repo se cargaron desde otra shell.
  - El repo usa subjects OIDC inmutables (`use_immutable_subject`): GitHub firma con `repo:e-ortega@8528679/eortega-dev@1452146082:...`, no `repo:e-ortega/eortega-dev:...`. `bootstrap.sh` lee el prefijo real de `repos/{repo}/actions/oidc/customization/sub` y crea/actualiza las federated credentials con él.
  - El `disconnect` regeneró el token de deploy: el secreto del workflow generado por Azure quedó inválido. Ese workflow se deshabilitó (`gh workflow disable`, estado `disabled_manually`); el archivo se conserva como referencia.
  - PR #1 validado y mergeado: what-if con OIDC `pull_request` ✓, preview ✓, y en `main` `infra.yml` deploy ✓ + `frontend.yml` deploy a producción ✓ (OIDC `main-branch`). **El pipeline IaC está completo y en uso.**
  - Al mergear, el evento "closed" del PR llega con `github.ref = refs/heads/main` y caía en el mismo grupo de concurrencia que el push → canceló el deploy a producción (se relanzó a mano). Corregido: grupo por evento + número de PR, y `cancel-in-progress` solo para PRs.
- Importante al recrear desde cero (después de un destroy): el hostname `*.azurestaticapps.net` cambia, así que hay que actualizar el CNAME `@` en Cloudflare y el TXT de validación del dominio. Con el proxy naranja activo, la validación TXT del dominio raíz es la que aplica.

## Backend: alcance decidido (10 nov 2026)

Objetivo: mostrar dominio de varias tecnologías, no solo un CRUD. La autenticación se aprovecha con **dos flujos y dos roles**:

| | Admin (Esteban) | Reclutador / persona interesada |
|---|---|---|
| Entrada | email + contraseña (hash) | código de un solo uso (OTP) por correo, sin contraseña |
| Sesión | JWT rol `admin` | JWT rol `recruiter`, vida corta |
| Puede | CRUD de proyectos, ver solicitudes de acceso y mensajes | ver el contenido extra |

Decisiones:
- **Todo el sitio es público.** El acceso de reclutador es un extra opcional, nunca un muro. Aviso tipo: "Reclutadores: implementamos autenticación con roles — solicitá acceso para ver contenido extra".
- **Acceso automático** (sin aprobación de Esteban), con aviso a Esteban por cada solicitud: sirve además como registro de quién mira el portafolio.
- **OTP de 6 dígitos, no magic link**: los escáneres de correo corporativos abren los links y consumen un link de un solo uso antes que la persona.
- **Contenido extra = la propia auth funcionando**: la sesión del visitante por dentro (claims decodificados, rol, expiración, por qué cookie HttpOnly), diagrama del flujo que acaba de recorrer con links al código, demo en vivo de 401 vs 200 en un endpoint protegido, y un par de datos extra (CV en PDF, LinkedIn/teléfono directo, disponibilidad).
- **Base de datos: PostgreSQL en Docker**, en la misma VM de Oracle que la API.

Tecnologías que quedan a la vista: ASP.NET Core (authorization policies por rol, rate limiting nativo, health checks), EF Core + PostgreSQL (migraciones, arrays), JWT en cookie, Cloudflare Turnstile, correo transaccional (Resend) con SPF/DKIM/DMARC alineados, Docker Compose, Cloudflare Tunnel.

## Páginas del portal

- Home, Proyectos, Sobre mí, Contacto — **públicas**. Proyectos viene de la API (no hardcodeado).
- Aviso/CTA de acceso para reclutadores → pantalla de solicitar código (email + Turnstile) → pantalla de ingresar código.
- `/extra` (rol `recruiter` o `admin`): contenido extra descrito arriba.
- `/admin` (rol `admin`): CRUD de proyectos, solicitudes de acceso, mensajes de contacto.

## Modelo de datos (PostgreSQL / EF Core)

- `Users`: id, email (único), password_hash (solo admin; null para reclutadores), role (`admin` | `recruiter`), created_at, last_login_at. El usuario reclutador se crea al verificar su primer código.
- `OtpRequests`: id, email, code_hash, expires_at, attempts, consumed_at, created_at, request_ip, country (header `CF-IPCountry`). Sirve también como log de "quién pidió acceso".
- `Projects`: id, slug (único), name, description, stack (`text[]`), repo_url, demo_url, featured, status (`production` | `in_progress`), sort_order, created_at, updated_at.
- `ContactMessages`: id, name, email, message, created_at, request_ip.
- El admin se siembra desde configuración (email + hash por variable de entorno), no hay registro público de admin.

## Contrato de API (`https://api.eortega.dev`)

Auth — la sesión viaja en cookie, nunca en el body:
- `POST /api/auth/login` `{email, password}` → 200 `{role, expiresAt}` + `Set-Cookie`; 401 genérico (no revela si el email existe).
- `POST /api/auth/otp/request` `{email, turnstileToken}` → **202 siempre** (misma respuesta exista o no la cuenta). Rate limit por IP y por email + cooldown entre envíos. Envía el código por correo y avisa a Esteban.
- `POST /api/auth/otp/verify` `{email, code}` → 200 `{role, expiresAt}` + `Set-Cookie`; 401 si es inválido o expiró; tras 5 intentos fallidos el código se invalida.
- `POST /api/auth/logout` → 204, borra la cookie.
- `GET /api/auth/me` → 200 `{email, role, issuedAt, expiresAt, claims}` | 401. Alimenta la vista "tu sesión por dentro": como la cookie es HttpOnly el frontend no puede leer el JWT, así que la API devuelve los claims decodificados (no el token crudo).

Proyectos:
- `GET /api/projects` (público, `?featured=true` opcional), `GET /api/projects/{slug}` (público).
- `POST /api/projects`, `PUT /api/projects/{id}`, `DELETE /api/projects/{id}` → rol `admin`. (El contrato anterior decía `POST /api/projects/{id}`; crear va sin id.)

Contacto:
- `POST /api/contact` `{name, email, message, turnstileToken}` → 202. Se guarda y se avisa a Esteban por correo. Rate limit por IP.

Contenido extra (rol `recruiter` o `admin`):
- `GET /api/extras` → datos extra (LinkedIn, teléfono, disponibilidad, etc.).
- `GET /api/extras/cv` → PDF servido por la API (no es un archivo público del frontend).
- `GET /api/extras/protected-demo` → 200 con sesión, 401 sin ella (el frontend lo llama con y sin credenciales para la demo en vivo).

Admin (rol `admin`):
- `GET /api/admin/access-requests`, `GET /api/admin/contact-messages`.

Operación:
- `GET /health/live` (proceso arriba) y `GET /health/ready` (incluye PostgreSQL). Los usa el healthcheck de Docker y el health-check periódico anti-reclamo de Oracle.

Errores en formato ProblemDetails (RFC 9457), que ASP.NET Core trae nativo.

## Detalles de diseño a respetar

- **Cookie**: `HttpOnly`, `Secure`, `SameSite=Lax`, host-only en `api.eortega.dev`. `eortega.dev` y `api.eortega.dev` son el mismo *site*, así que funciona; pero son orígenes distintos → CORS con `AllowCredentials` solo para `https://eortega.dev`. Consecuencia: en los previews de PR (`*.azurestaticapps.net`, otro site) el login no va a funcionar; es aceptable.
- **Correo saliente (Resend)**: enviar desde el subdominio `send.eortega.dev` (ej. `no-reply@send.eortega.dev`), verificado en Resend con su propio SPF/DKIM. Así no se toca el SPF de la raíz (que es el de Email Routing y **no puede haber dos**), y con DMARC estricto (`adkim=s; aspf=s`) el From y la firma DKIM quedan en el mismo dominio exacto → alineado. El subdominio hereda `p=reject` vía `sp=reject`, así que si la verificación queda mal, los correos se rechazan en silencio: probar con un envío real antes de darlo por hecho. Los avisos a Esteban van a `hola@eortega.dev` (Email Routing los reenvía a Hotmail).
- **OTP**: guardado como hash, expira a los 10 min, un solo uso, máx. 5 intentos.
- **Abuso del endpoint de OTP** (alguien podría usarlo para bombardear correos ajenos y quemar la cuota/reputación del dominio): Turnstile + rate limiting obligatorios desde el día uno.
- **Despliegue**: `docker compose` en la VM de Oracle con tres servicios: `api`, `postgres` (volumen persistente, **sin puerto expuesto**) y `cloudflared` (túnel a `api.eortega.dev`). Secretos (clave de firma JWT, API key de Resend, secret de Turnstile, contraseña de Postgres, hash del admin) en un archivo de entorno en la VM, nunca en el repo.
- **Privacidad**: se guardan correos de terceros → aclararlo en la pantalla de solicitud de acceso (para qué se usan) y definir retención.

Pendiente de definir: duración exacta de cada JWT (sugerido: admin 8 h, recruiter 24 h), límites exactos de rate limiting, retención de `OtpRequests`/`ContactMessages`, y el contenido concreto de `/api/extras`.

## Diseño visual (decidido)

- Mockup del Home hecho con el Artifact tool (tipo Design/canvas), aesthetic "blueprint / cuaderno de ingeniería": grilla sutil, IBM Plex Sans/Mono, paneles con borde fino sin sombra, acento azul (#2E5BFF editable). Aprobado como base.

## Estado del frontend

- Vite 8 (+ @vitejs/plugin-react 6) + React 18, scaffolded a mano (sin `npm create vite`, para no arriesgar el CLAUDE.md). Fuentes IBM Plex vía Google Fonts en `index.html`.
- Componentes en `src/components/` (Header, Hero, Projects, About, Contact, Footer) replicando el mockup, CSS modules por componente, tokens de color/tipografía en `src/index.css`.
- Proyectos en `src/data/projects.js` como arreglo estático (CanastaCRApp en producción, Pipeline de Telemetría en construcción) — placeholder intencional hasta que exista la API.
- El backend NO existe todavía, a propósito (regla de autoría).
- `README.md` (en inglés) con tres diagramas Mermaid: arquitectura, CI/CD y flujo de acceso de reclutadores. Lo que aún no existe va con línea punteada (`classDef planned`) y marcado *planned*. Mantenerlo al día cuando cambie la arquitectura (p. ej. quitar el *planned* cuando el backend esté desplegado).

## Pendiente / sin decidir

- Activar "Always Use HTTPS" en Cloudflare (cierra el 404 de `http://www`).
- Siguiente foco: pensar/diseñar el backend antes que el contenido real (decisión de Esteban, 10 nov 2026).
- **i18n del frontend** (después): selector de idioma (al menos español / inglés), sacar todo el texto visible a archivos de traducción, `<html lang>` dinámico. Encaja con la regla de idioma: hoy el texto del sitio es el único lugar que sigue en español.
- Futuro (sin urgencia mientras todo esté en tier Free, $0): poder apagar los recursos desde el pipeline. Hoy ya existe `infra.yml` → `workflow_dispatch` → `destroy` (borra el Static Web App), pero recrear implica actualizar CNAME/TXT en Cloudflare a mano. Pendiente diseñar un "apagar/encender" más completo (p. ej. automatizar el DNS de Cloudflare con su API, y extenderlo a los recursos del backend cuando existan).
- Contenido real: trayectoria (hardware @ Intel → backend → DevOps/platform engineering, docencia), stack con más detalle, y explicación de cada proyecto (CanastaCRApp, pipeline de telemetría).
- Sin decidir: si el portal lanza mostrando solo CanastaCRApp o espera a tener algo de telemetry-pipeline listo.
- Backend (Esteban): ASP.NET Core + JWT, aprovisionar la VM de Oracle, `cloudflared` para `api.eortega.dev`, health-check anti-reclamo, y conectar Projects a la API real.
