# Architecture

CINE-X uses a layered backend and a Provider-based Flutter client.

## Backend

Request flow:

```text
Controller -> Service -> Repository -> PostgreSQL
```

Rules:

- Controllers never access repositories directly.
- Entities are mapped to DTOs before returning API responses.
- Project-level endpoints call `ProjectAccessService`.
- `OWNER` and `SCREENWRITER` can edit story structure.
- `PRODUCER` and `ASSISTANT_DIRECTOR` can view, plan, analyze, export and update scene status.
- Global exception handling returns JSON error responses.

Security:

- `/api/v1/auth/**`, Swagger and static uploads are public.
- Other endpoints require `Authorization: Bearer <token>`.
- JWT includes user id, email, system role, issued-at and expiration.

## Flutter

Client flow:

```text
Screen -> ChangeNotifier -> Repository -> ApiClient -> Spring Boot
```

The app uses:

- `AuthProvider` for bootstrap/login/register/logout.
- `ProjectProvider` for the project launcher.
- `WorkspaceProvider` for acts, characters, locations, scenes, planner, analytics and export.
- `ApiClient` for auth headers, UTF-8 JSON, errors, timeouts, multipart and PDF bytes.

Responsive behavior:

- Mobile uses `NavigationBar`.
- Tablet/desktop uses `NavigationRail`.
- Cards and grids use responsive constraints and no fixed-width form layouts.
