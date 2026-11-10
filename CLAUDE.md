# CLAUDE.md — eortega-dev (portal personal)

## Qué es esto

Portal personal de portafolio para mostrar los proyectos de Esteban (incluido telemetry-pipeline una vez listo). Nombre tentativo de dominio: eortega.dev (disponibilidad sin confirmar todavía).

## Regla de autoría

División de trabajo explícita:

- **Claude** ayuda con la generación del frontend: estructura, diseño, scaffold de React, configuración de deployment/CI. Esto es presentación, no la pieza que demuestra código propio.
- **Esteban** construye el backend de este servicio: la API, la autenticación JWT, el acceso a datos. Claude ayuda a diseñar el contrato de la API y revisa cuando hay código (igual que en telemetry-pipeline: solo hallazgos, nunca corrige), pero no escribe la implementación del backend.

## Stack decidido

- Frontend: React (Vite)
- Backend: ASP.NET Core Web API (stack habitual de Esteban) con JWT

## Hosting y presupuesto (decidido)

- **Frontend**: Azure Static Web Apps, tier gratuito — CDN, SSL y CI/CD con GitHub Actions incluidos, sin tocar crédito
- **Backend**: VM Always Free de Oracle Cloud (VM.Standard.A1.Flex, 2 OCPU / 12GB RAM, ARM) corriendo el backend en Docker. Se eligió sobre Azure Container Apps porque el portal debe estar siempre disponible para reclutadores sin demora de cold-start — una VM real no tiene ese problema, a diferencia de un plan serverless que escala a cero. Costo: $0 de por vida.
  - Riesgo a mitigar: Oracle puede reclamar la instancia si se mantiene con menos del 20% de uso de CPU/red durante 7 días seguidos. Se resuelve con un health-check programado que la toque periódicamente.
- **Evaluado y descartado**: Hostinger plan Premium (shared/cloud hosting) — no soporta ASP.NET Core, solo PHP/Node en servidores Linux sin runtime .NET. Hostinger VPS (KVM 1, ~$6.29-13.79/mes) sí funcionaría técnicamente vía Docker, pero se descartó a favor de la opción gratuita de Oracle.
- **Dominio**: revisar primero si Esteban califica para el GitHub Student Developer Pack (dominio gratis 1 año vía Name.com, incluye extensión .dev) antes de comprarlo. Alternativa de pago: Porkbun, ~$8.75 primer año / $12.87 renovación para .dev, o $11.81/año fijo para .com. Comprar aparte del hosting, no vía Azure ni Hostinger, para no atar el dominio a un proveedor de infraestructura.
- Esteban tiene una cuenta Azure for Students con $100 USD de crédito, reservado para el proyecto telemetry-pipeline (SQL Server, Log Analytics), no para el portal.

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

## Pendiente / sin decidir todavía

- Tono visual del portal: sobrio/corporate vs. con más personalidad — no decidido
- Si el portal lanza mostrando solo CanastaCRApp o espera a tener algo de telemetry-pipeline listo — no decidido
- Aprovisionar la VM de Oracle Cloud y configurar el health-check — no hecho todavía

## Dominio: decisión final

Se descartó la ruta del dominio gratis vía GitHub Student Developer Pack: la cuenta estebanortega-ulatina tiene beneficios educativos verificados como **Faculty**, no como Student (confirmado en github.com/settings/education/benefits — solo desbloquea upgrade a GitHub Teams y Copilot, no el marketplace de partners con dominios). La cuenta personal e-ortega (Gmail) no tiene ningún beneficio educativo aplicado. Se compra el dominio directo en Porkbun (~$8.75 el primer año para .dev).

Dominio final: **eortega.dev**, comprado directo en Porkbun ($8.75 primer año / $12.87 renovación), standalone, sin bundle de hosting. Se revisaron y descartaron alternativas: eortegadev.* en Name.com (precios de entrada baratos pero renovaciones infladas en .life/.lol/.bio/.email), y el "dominio gratis" de Hostinger para eortegacr.dev (en realidad viene atado a comprar su plan de hosting Unlimited/Premium — el mismo hosting ya descartado por no soportar ASP.NET Core). El nombre exacto de la variante (eortega.dev vs. eortegacr.dev) no le importa a Esteban; se queda con eortega.dev por ser el que ya estaba confirmado disponible con precio transparente.

## Registrador final: Cloudflare

Decisión cerrada: **eortega.dev se registra en Cloudflare** ($8.20 primer año / $12.20 renovación), no en Porkbun. Motivo principal, más allá del precio: Cloudflare Tunnel (cloudflared) es gratis y resuelve la exposición del backend en la VM de Oracle sin abrir puertos ni manejar IP pública/firewall — el backend se conecta hacia afuera por un túnel cifrado hacia un subdominio (ej. api.eortega.dev), con SSL gestionado automáticamente en el borde.

Implicación técnica: Cloudflare Registrar obliga a usar su propio DNS (no se puede usar otro proveedor mientras el dominio esté registrado ahí). No es un problema acá porque de todos modos se va a usar el DNS de Cloudflare para enrutar:
- `eortega.dev` (raíz) → Azure Static Web Apps (frontend)
- `api.eortega.dev` (o similar) → Cloudflare Tunnel hacia el backend en la VM Always Free de Oracle

**Comprado y activo**: eortega.dev registrado en Cloudflare, vence el 9 de noviembre de 2027, auto-renovación activada ($12.20/año). Pendiente: configurar la zona DNS (raíz → Static Web Apps, api.eortega.dev → Cloudflare Tunnel) y, al aprovisionar la VM de Oracle, instalar `cloudflared` para el túnel.

## Mockup visual (decidido)
- Mockup del Home hecho con el Artifact tool (tipo Design/canvas), aesthetic "blueprint / cuaderno de ingeniería": grilla sutil, IBM Plex Sans/Mono, paneles con borde fino sin sombra, acento azul (#2E5BFF editable).
- Aprobado como base por ahora. Pendiente: trabajar el contenido real — explicar su trayectoria (hardware @ Intel -> backend -> DevOps/platform engineering, docencia) y el stack con más detalle, y desarrollar la explicación de cada proyecto (CanastaCRApp, pipeline de telemetría) antes de construir el código React definitivo.
