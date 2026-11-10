# CLAUDE.md — eortega-dev (portal personal)

## Qué es esto

Portal personal de portafolio para mostrar los proyectos de Esteban (incluido telemetry-pipeline una vez listo). En vivo en **https://eortega.dev**.

## Regla de autoría

División de trabajo explícita:

- **Claude** ayuda con la generación del frontend: estructura, diseño, scaffold de React, configuración de deployment/CI. Esto es presentación, no la pieza que demuestra código propio.
- **Esteban** construye el backend de este servicio: la API, la autenticación JWT, el acceso a datos. Claude ayuda a diseñar el contrato de la API y revisa cuando hay código (igual que en telemetry-pipeline: solo hallazgos, nunca corrige), pero no escribe la implementación del backend.

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
  - A `www` → 20.75.112.13 (IP fija de Azure, auto-creado por Cloudflare). Pendiente: cambiarlo a CNAME hacia el hostname de Static Web Apps para no depender de esa IP.
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
- `.github/workflows/frontend.yml`: build con Node 20 (`npm ci && npm run build`) y deploy de `dist/` con `Azure/static-web-apps-deploy`. El token de deploy se pide a Azure en cada corrida vía OIDC, así que recrear el recurso no exige actualizar secretos. Previews por PR y cierre al cerrar el PR.
- El workflow que Azure generó al crear el recurso desde el portal (`azure-static-web-apps-polite-hill-0de7df110.yml`, usa el secreto `AZURE_STATIC_WEB_APPS_API_TOKEN_POLITE_HILL_0DE7DF110`) se conserva en el repo como referencia, por decisión de Esteban — no borrarlo. Mientras esté activo, cada push a main dispara dos deploys del frontend (el viejo y `frontend.yml`); la opción para que quede solo como referencia es deshabilitarlo con `gh workflow disable` sin tocar el archivo.
- Estado (10 nov 2026): bootstrap corrido y Bicep aplicado manualmente con éxito sobre el recurso existente (deployment `swa-manual-bootstrap`); sitio y dominio verificados después (HTTP 200, dominio `Ready`). Lecciones de esa primera corrida:
  - El recurso estaba conectado a GitHub (lo creó el portal). Se desconectó con `az staticwebapp disconnect` (lo corrió Esteban); ahora `provider: None`, sin repositoryUrl/branch.
  - `deploymentAuthPolicy` quedó en `GitHub` tras el disconnect. Con esa política el deploy falla de las dos formas: con `github_id_token` el servidor busca el sitio por el nombre del archivo de workflow (exige `azure-static-web-apps-<adj>-<noun>-<hex>.yml`), y con solo el token responde "api key invalid". Se cambió a `DeploymentToken` una sola vez con `az rest --method patch` sobre el recurso, pasando `repositoryToken` (PAT fine-grained temporal, ya descartable) + `buildProperties` (appLocation `/`, outputLocation `dist`, `skipGithubActionWorkflowGeneration: true`); sin ambos ARM lo rechaza. Bicep no declara la propiedad por eso mismo. `frontend.yml` deploya solo con el token.
  - El `az` de Windows emite CRLF: en Git Bash cada `$(az ...)` trae un `\r` pegado (rompía comparaciones y el appId). `bootstrap.sh` lo limpia con un wrapper de `az`. `gh` no estaba en el PATH del bash lanzado desde PowerShell; las variables del repo se cargaron desde otra shell.
  - El repo usa subjects OIDC inmutables (`use_immutable_subject`): GitHub firma con `repo:e-ortega@8528679/eortega-dev@1452146082:...`, no `repo:e-ortega/eortega-dev:...`. `bootstrap.sh` lee el prefijo real de `repos/{repo}/actions/oidc/customization/sub` y crea/actualiza las federated credentials con él.
  - El `disconnect` regeneró el token de deploy: el secreto del workflow generado por Azure quedó inválido. Ese workflow se deshabilitó (`gh workflow disable`, estado `disabled_manually`); el archivo se conserva como referencia.
  - PR #1 validado: what-if con OIDC `pull_request` ✓, deploy de preview de `frontend.yml` ✓ (HTTP 200), producción intacta.
- Importante al recrear desde cero (después de un destroy): el hostname `*.azurestaticapps.net` cambia, así que hay que actualizar el CNAME `@` en Cloudflare y el TXT de validación del dominio. Con el proxy naranja activo, la validación TXT del dominio raíz es la que aplica.

## Páginas del portal

- Home: quién es, stack, enlace a proyectos destacados
- Proyectos: lista que viene de la API (no hardcodeada en el frontend)
- Sobre mí
- Contacto: formulario que pega a la API
- /admin: protegida con JWT, para dar de alta/editar proyectos sin re-deployar

## Modelo de datos

- `Projects`: nombre, descripción, stack, repo_url, demo_url, destacado
- `Users`: solo la cuenta de admin de Esteban

## Contrato de API

- `POST /api/auth/login` → devuelve el JWT
- `GET /api/projects` → público
- `POST /api/projects/{id}`, `PUT /api/projects/{id}`, `DELETE /api/projects/{id}` → protegidos con JWT

## Diseño visual (decidido)

- Mockup del Home hecho con el Artifact tool (tipo Design/canvas), aesthetic "blueprint / cuaderno de ingeniería": grilla sutil, IBM Plex Sans/Mono, paneles con borde fino sin sombra, acento azul (#2E5BFF editable). Aprobado como base.

## Estado del frontend

- Vite + React 18 scaffolded a mano (sin `npm create vite`, para no arriesgar el CLAUDE.md). Fuentes IBM Plex vía Google Fonts en `index.html`.
- Componentes en `src/components/` (Header, Hero, Projects, About, Contact, Footer) replicando el mockup, CSS modules por componente, tokens de color/tipografía en `src/index.css`.
- Proyectos en `src/data/projects.js` como arreglo estático (CanastaCRApp en producción, Pipeline de Telemetría en construcción) — placeholder intencional hasta que exista la API.
- El backend NO existe todavía, a propósito (regla de autoría).

## Pendiente / sin decidir

- Mergear PR #1 y verificar el primer deploy a producción desde `main` (credencial OIDC `main-branch`, `infra.yml` deploy + `frontend.yml`).
- Cambiar el A record de `www` a CNAME.
- Contenido real: trayectoria (hardware @ Intel → backend → DevOps/platform engineering, docencia), stack con más detalle, y explicación de cada proyecto (CanastaCRApp, pipeline de telemetría).
- Sin decidir: si el portal lanza mostrando solo CanastaCRApp o espera a tener algo de telemetry-pipeline listo.
- Backend (Esteban): ASP.NET Core + JWT, aprovisionar la VM de Oracle, `cloudflared` para `api.eortega.dev`, health-check anti-reclamo, y conectar Projects a la API real.
