# Backend build guide

A step-by-step plan for building the eortega.dev API. It defines **what** to build, in which order, and how to know each step is done — the implementation is yours. The API contract, data model and design constraints live in `CLAUDE.md` (sections *Backend*, *Modelo de datos*, *Contrato de API*, *Detalles de diseño*); this guide turns them into milestones.

Each milestone ends with a working, testable slice. Open one PR per milestone (or smaller); reviews are findings-only.

---

## 0. Decisions to confirm before starting

These have a suggested default. Change them here if you disagree, so the guide stays the source of truth.

| Topic | Suggested default | Why |
|---|---|---|
| Repo location | `api/` folder in this repo | One PR can change contract + API + frontend together; workflows already filter by path. |
| Runtime | .NET 10 (LTS) | Current LTS; you already have the SDK. |
| API style | Minimal APIs with route groups (`MapGroup`), organized by feature | Less ceremony than controllers, modern idiom, groups map 1:1 to the contract sections. Controllers are fine too if you prefer — just be consistent. |
| Admin JWT lifetime | 8 h | A working session; no refresh tokens needed for one user. |
| Recruiter JWT lifetime | 24 h | Long enough to browse, short enough to expire on its own. |
| OTP request limits | 5/hour per IP, 3/hour per email, 60 s cooldown per email | Stops email bombing without bothering a real person. |
| OTP verify limits | 10 per 15 min per IP; code dies after 5 wrong attempts | Brute-forcing 6 digits becomes impractical. |
| Contact form limit | 5/hour per IP | |
| Retention | `OtpRequests` 180 days, `ContactMessages` 1 year | State it on the request-access screen. |

---

## 1. Target structure

```
api/
  Eortega.Api.sln
  src/Eortega.Api/
    Program.cs                 composition root only: services, middleware, endpoint groups
    Features/
      Auth/                    login, otp request/verify, logout, me
      Projects/
      Contact/
      Extras/
      Admin/
    Infrastructure/
      Data/                    DbContext, entity configurations, migrations
      Email/                   IEmailSender + console (dev) and Resend (prod) implementations
      Turnstile/               verification client
      Security/                token issuing, OTP hashing, client IP resolution
    appsettings.json           non-secret defaults only
  tests/Eortega.Api.Tests/     integration tests
  Dockerfile
  compose.yaml                 local dev: api + postgres
```

Feature folders keep each endpoint group, its request/response records and its validation together. `Infrastructure` holds everything that talks to the outside world, behind small interfaces so tests can swap them.

### Packages you will need

| Need | Package |
|---|---|
| PostgreSQL + EF Core | `Npgsql.EntityFrameworkCore.PostgreSQL`, `Microsoft.EntityFrameworkCore.Design` |
| JWT validation | `Microsoft.AspNetCore.Authentication.JwtBearer` |
| Password hashing | `Microsoft.Extensions.Identity.Core` (only for `PasswordHasher<T>` — don't roll your own) |
| DB health check | `Microsoft.Extensions.Diagnostics.HealthChecks.EntityFrameworkCore` |
| OpenAPI document | `Microsoft.AspNetCore.OpenApi` (built in) — optionally a UI like Scalar in Development |
| Tests | `xunit`, `Microsoft.AspNetCore.Mvc.Testing`, `Testcontainers.PostgreSql` |

Rate limiting, ProblemDetails, CORS, health checks and the options pattern are all built into ASP.NET Core — no extra packages.

### Prerequisites

- .NET 10 SDK (installed).
- **Docker Desktop** (not installed yet) — needed for local Postgres and for Testcontainers.
- `dotnet tool install --global dotnet-ef` for migrations.

---

## 2. Milestones

### M0 — Skeleton, database and health checks

Build:
- Solution, API project and test project (`dotnet new sln`, `dotnet new web`, `dotnet new xunit`).
- `compose.yaml` with Postgres for local dev (port published to localhost **only in the dev compose file**).
- `DbContext` wired to Postgres via a connection string from configuration.
- `GET /health/live` (no dependencies) and `GET /health/ready` (includes the database check).
- ProblemDetails enabled globally, so every error — including unhandled exceptions — returns RFC 9457 JSON.
- Strongly typed options (`JwtOptions`, `TurnstileOptions`, `EmailOptions`, …) with validation on startup, so a missing secret fails at boot instead of at the first request.
- Secrets locally via `dotnet user-secrets`; nothing secret in `appsettings.json`.

Done when:
- `/health/ready` returns 200 with Postgres up and 503 when you stop the container.
- The app refuses to start if a required option is missing, with a clear message.
- One integration test boots the app against a Testcontainers Postgres and hits `/health/ready`.

### M1 — Projects (public read)

Build:
- `Project` entity per the data model (`stack` as a Postgres `text[]`, unique `slug`).
- First migration, plus seed data for CanastaCRApp and the telemetry pipeline (same content as `src/data/projects.js`).
- `GET /api/projects` (with optional `?featured=true`) and `GET /api/projects/{slug}`.
- Response records that are **not** the entity (don't leak EF types or internal columns).
- CORS policy allowing only `https://eortega.dev` (plus `http://localhost:5173` in Development), with credentials.

Done when:
- Unknown slug returns a 404 ProblemDetails.
- Tests cover list, featured filter, by-slug, and 404.
- *(Claude)* The frontend reads projects from the API instead of `projects.js` when `VITE_API_URL` is set.

### M2 — Admin login, JWT in a cookie, project CRUD

Build:
- `User` entity. The admin is seeded from configuration (email + password **hash**), created or updated at startup — no sign-up endpoint.
- `POST /api/auth/login`: verify with `PasswordHasher<T>`, issue a JWT with `sub`, `email`, `role`, `iat`, `exp`, and set it as a cookie: `HttpOnly`, `Secure`, `SameSite=Lax`, host-only, `Path=/`, max-age = token lifetime.
- JwtBearer configured to **read the token from that cookie** (hook the `OnMessageReceived` event) instead of the `Authorization` header.
- Authorization policies: `AdminOnly`, and `RecruiterOrAdmin` for later.
- `POST /api/auth/logout` (expires the cookie) and `POST/PUT/DELETE /api/projects` under `AdminOnly`.
- Input validation returning 400 ValidationProblemDetails (slug format, required fields, URL fields).

Done when:
- Wrong email and wrong password return the **same** 401 (no user enumeration), ideally in similar time.
- Tests: CRUD without cookie → 401; with a recruiter token → 403; with admin → 2xx; invalid payload → 400.

Watch out for:
- **CSRF.** Cookie auth means the browser sends credentials automatically. `SameSite=Lax` blocks cross-site POSTs, and requiring `Content-Type: application/json` on writes forces a CORS preflight that other origins fail. Keep both.
- Sign with a symmetric key of at least 256 bits, kept in configuration; validate issuer, audience, lifetime and signing key.

### M3 — Recruiter access with one-time codes

Build:
- `OtpRequest` entity and migration.
- `POST /api/auth/otp/request`:
  1. Verify the Turnstile token server-side (Cloudflare `siteverify` endpoint). Cloudflare publishes test keys that always pass or always fail — use them in Development and tests.
  2. Enforce per-IP (rate limiter) and per-email (database count in the last hour + cooldown) limits.
  3. Generate a 6-digit code with a cryptographically secure RNG, store only its **hash** with a 10-minute expiry.
  4. Send it through `IEmailSender`; notify `hola@eortega.dev`.
  5. Always return 202 with the same body, whatever happened above (except Turnstile failure → 400).
- `POST /api/auth/otp/verify`: look up the latest unconsumed, unexpired request for that email; compare in constant time; increment attempts on failure and invalidate at 5; on success mark consumed, create the recruiter `User` if needed, update `last_login_at`, set the cookie.
- Email: a console implementation for Development (logs the code — no real email locally) and a Resend implementation for Production, selected by configuration.

Done when:
- Tests: happy path; wrong code; expired code; 6th attempt rejected even with the right code; reuse of a consumed code rejected; rate limit returns 429; Turnstile failure returns 400; the response for a never-seen email is identical to a known one.

Watch out for:
- **Client IP behind the tunnel.** Every request reaches the API from the `cloudflared` container, so the remote address is always the same — rate limiting by it would throttle everyone together. Use the `CF-Connecting-IP` header, and trust it only because the tunnel is the sole way in (Postgres and the API publish no ports). Same for `CF-IPCountry`.
- **Hashing the code.** A slow password hash (bcrypt/PBKDF2) is unnecessary here: the code lives 10 minutes and allows 5 attempts. An HMAC-SHA256 with a server-side secret is enough and keeps the endpoint fast.
- **Email deliverability.** Resend must be verified on `send.eortega.dev` (its own SPF and DKIM records in Cloudflare). With the domain's strict DMARC, a misconfiguration means silently rejected mail — send a real test to Gmail and Outlook before calling it done.

### M4 — Extras, session view and admin lists

Build:
- `GET /api/auth/me`: returns the decoded claims of the current cookie (never the raw token).
- `GET /api/extras`, `GET /api/extras/cv` (PDF streamed by the API, not a public file) and `GET /api/extras/protected-demo`, all under `RecruiterOrAdmin`.
- `GET /api/admin/access-requests` and `GET /api/admin/contact-messages` under `AdminOnly`, paginated.
- `POST /api/contact` with Turnstile + rate limit, stored and notified by email.
- A retention job (`BackgroundService` running daily) that deletes rows past the retention period.

Done when:
- `protected-demo` returns 401 without a cookie and 200 with one.
- `/me` reflects the real expiry of the token.
- Tests for each role boundary.

### M5 — Container, CI and deployment

Build:
- Multi-stage `Dockerfile` (SDK image to publish, ASP.NET runtime image to run, non-root user).
- **The Oracle VM is ARM64 (Ampere A1)**: the image must be built for `linux/arm64` (Docker Buildx), or it won't start there.
- `backend.yml` workflow: build + test on PRs touching `api/`; on `main`, build the arm64 image and push it to GitHub Container Registry.
- Migrations in production: generate an EF **migration bundle** and run it as a deploy step, rather than migrating automatically at app startup (startup migrations race when there's more than one instance and hide failures).
- *(Claude)* VM provisioning, production `compose.yaml` (api + postgres without published ports + cloudflared), the tunnel to `api.eortega.dev`, and the periodic health check that keeps Oracle from reclaiming the VM.

Done when:
- `https://api.eortega.dev/health/ready` returns 200 from the internet.
- A merge to `main` ships a new image without manual steps.
- The README diagrams drop their *planned* markers.

---

## 3. What Claude does in parallel

| Milestone | Frontend / infra work |
|---|---|
| M1 | Fetch projects from the API; `VITE_API_URL` per environment |
| M2 | `/admin` screens (login, project CRUD) |
| M3 | Request-access CTA, email + Turnstile form, code entry screen |
| M4 | `/extra` page (session view, flow diagram, 401 vs 200 demo), admin lists |
| M5 | VM, compose, tunnel, health check, deploy workflow |
