# Stack Research: Backend-Driven UI Framework

**Project:** CallBackery Clean-room Redesign
**Researched:** 2026-01-22
**Confidence:** MEDIUM (unable to verify current versions via web search)

## Research Constraints

**NOTE:** This research is based on training data (cutoff: January 2025). Web verification was unavailable, so version numbers and "latest" information may be 6-18 months stale. Each recommendation includes a confidence level:

- **HIGH**: Core technology choice backed by strong ecosystem
- **MEDIUM**: Likely still current but version should be verified
- **LOW**: May have changed since training, verify before use

## Frontend Stack

### Core Framework

| Technology | Version (Training Data) | Purpose | Confidence | Rationale |
|------------|------------------------|---------|------------|-----------|
| **Svelte** | 5.x | Reactive UI framework | HIGH | Svelte 5 introduced runes ($state, $derived, $effect) for fine-grained reactivity. Perfect for dynamic UI schemas since state changes are explicit and trackable. |
| **TypeScript** | 5.3+ | Type safety | HIGH | Essential for consuming OpenAPI-generated types. Provides compile-time validation of backend contracts. |
| **Vite** | 5.x | Build tool | HIGH | Official Svelte tooling uses Vite. Fast HMR, native ESM, optimized production builds. |

**Why Svelte 5 specifically:**
- Runes model maps well to backend-driven state (backend sends data → `$state` → UI updates)
- Smaller bundle size than React/Vue (critical for framework distribution)
- Compile-time optimization means runtime performance is predictable
- Component composition matches form/table rendering patterns

**Confidence: HIGH** - Svelte 5 is the right choice for this architecture pattern.

### UI Components

| Technology | Version | Purpose | Confidence | Rationale |
|------------|---------|---------|------------|-----------|
| **Flowbite-Svelte** | 0.44+ (check current) | Component library | MEDIUM | Tailwind-based components. Comprehensive set (forms, tables, modals, notifications). |
| **Tailwind CSS** | 3.4+ | Styling system | HIGH | Required by Flowbite. Utility-first CSS matches dynamic component generation. |

**Why Flowbite-Svelte:**
- Pre-built components for forms, tables, navigation (your core use cases)
- Tailwind integration means styling is composable
- Active maintenance (as of training cutoff)
- Accessibility built-in (ARIA attributes)

**Alternatives considered:**
- **Svelte Material UI**: More opinionated design, heavier bundle
- **DaisyUI**: Tailwind-based but less Svelte-specific integration
- **Carbon Components Svelte**: IBM Design, potentially over-engineered for framework use

**Confidence: MEDIUM** - Flowbite was current in training data, but verify Svelte 5 compatibility.

### State Management

| Technology | Version | Purpose | Confidence | Rationale |
|------------|---------|---------|------------|-----------|
| **Svelte 5 Runes** | Built-in | Reactive state | HIGH | Native solution, no external library needed |
| **Svelte Stores** | Built-in | Global/shared state | HIGH | For cross-component state (user session, notifications) |

**Why built-in solutions:**
- Svelte 5 runes (`$state`, `$derived`, `$effect`) handle component-local state
- Stores handle global state (user context, notification queue)
- No need for Redux/Zustand/Pinia complexity
- Backend drives state through API, not complex client-side logic

**Pattern recommendation:**
```typescript
// API response → store → components reactively update
export const uiSchema = writable<UISchema | null>(null);
export const notifications = writable<Notification[]>([]);
```

**Confidence: HIGH** - Built-in solutions are sufficient for backend-driven architecture.

### Frontend Build Tooling

| Tool | Version | Purpose | Confidence |
|------|---------|---------|------------|
| **Vite** | 5.x | Dev server + bundler | HIGH |
| **SvelteKit** | 2.x | Framework (optional) | LOW |
| **vitest** | 1.x | Testing | MEDIUM |
| **Playwright** | 1.40+ | E2E testing | MEDIUM |

**Vite configuration:**
```bash
npm create vite@latest frontend -- --template svelte-ts
```

**SvelteKit consideration:**
- **Use if:** You need SSR, routing, or want full-stack framework
- **Skip if:** Frontend is purely API-driven renderer (likely your case)
- **Recommendation:** Start with vanilla Svelte + Vite. Add SvelteKit later if routing complexity warrants it.

**Why NOT SvelteKit initially:**
- Backend (Rust/Axum) handles routing, authentication, business logic
- Frontend is a renderer, not a full application
- SvelteKit's file-based routing won't match backend-driven navigation
- Simpler build = easier to distribute as framework

**Confidence: HIGH** - Vite + vanilla Svelte is right for this architecture.

## Backend Stack

### Core Framework

| Technology | Version | Purpose | Confidence | Rationale |
|------------|---------|---------|------------|-----------|
| **Rust** | 1.75+ (stable) | Language | HIGH | Memory safety, performance, strong type system |
| **Axum** | 0.7.x | Web framework | MEDIUM | Tokio-based, ergonomic, modular |
| **Tokio** | 1.35+ | Async runtime | HIGH | Industry standard for async Rust |
| **Tower** | 0.4.x | Middleware | HIGH | Axum's middleware layer |

**Why Axum:**
- Ergonomic handler functions (similar to Express.js in DX)
- Built on Tower (composable middleware)
- Type-safe extractors for request parsing
- First-class WebSocket support
- Good OpenAPI tooling integration (utoipa-axum)

**Alternatives considered:**
- **Actix-web**: Faster benchmarks but less ergonomic, less type-safe extractors
- **Rocket**: Simpler but less flexible, smaller ecosystem
- **Warp**: More functional style, steeper learning curve

**Confidence: HIGH** - Axum is the right choice for this use case (REST + WebSocket + OpenAPI).

### Database

| Technology | Version | Purpose | Confidence | Rationale |
|------------|---------|---------|------------|-----------|
| **PostgreSQL** | 15+ | Primary database | HIGH | Robust, JSON support for flexible schemas |
| **SQLx** | 0.7.x | Database driver | MEDIUM | Compile-time query verification |

**Why PostgreSQL + SQLx:**
- **PostgreSQL**: JSONB columns for flexible UI schema storage, strong ACID guarantees
- **SQLx**: Compile-time SQL verification prevents runtime DB errors
- **Async**: Native async/await support (works with Tokio)
- **Migrations**: Built-in migration management

**Alternatives:**
- **Diesel**: More ORM-like, but less async-friendly (as of training cutoff)
- **SeaORM**: Full ORM, adds abstraction layer (may be overkill)
- **SQLite**: Consider for demos/testing, but PostgreSQL for production

**Configuration storage pattern:**
```sql
CREATE TABLE ui_schemas (
  id UUID PRIMARY KEY,
  schema_type VARCHAR(50),  -- 'form', 'table', 'navigation'
  definition JSONB,         -- OpenAPI-compliant schema
  version INTEGER
);
```

**Confidence: HIGH** - PostgreSQL + SQLx is proven for this pattern.

### Authentication & Session Management

| Technology | Version | Purpose | Confidence | Rationale |
|------------|---------|---------|------------|-----------|
| **jsonwebtoken** | 9.x | JWT handling | MEDIUM | Industry standard for stateless auth |
| **argon2** | 0.5.x | Password hashing | HIGH | OWASP recommended, memory-hard |
| **tower-cookies** | 0.10.x | Cookie management | LOW | Axum-compatible middleware |

**Why JWT:**
- Stateless authentication (scales horizontally)
- Claims can include user permissions for UI schema filtering
- Works with WebSocket authentication

**Session strategy:**
```rust
// JWT contains user_id + permissions
// Backend filters UI schemas based on permissions
// Frontend receives only authorized UI elements
```

**Confidence: MEDIUM** - JWT is standard, but cookie middleware version may have changed.

### Backend Build Tooling

| Tool | Version | Purpose | Confidence |
|------|---------|---------|------------|
| **Cargo** | Latest stable | Build system | HIGH |
| **cargo-watch** | 8.x | Auto-rebuild | MEDIUM |
| **cargo-nextest** | 0.9.x | Faster testing | LOW |

**Development workflow:**
```bash
cargo watch -x 'run --bin backend'
```

**Confidence: MEDIUM** - Cargo is stable, extension tools may have updated.

## API Layer

### OpenAPI Tooling

| Technology | Version | Purpose | Confidence | Rationale |
|------------|---------|---------|------------|-----------|
| **utoipa** | 4.x | OpenAPI generation (Rust) | MEDIUM | Derive macros for OpenAPI 3.1 |
| **utoipa-axum** | 0.1.x | Axum integration | LOW | Bridge between utoipa + Axum |
| **openapi-typescript** | 6.x | TypeScript client gen | LOW | Generates types from OpenAPI spec |

**Why utoipa:**
- Derive macros keep OpenAPI in sync with code
- OpenAPI 3.1 support (latest spec)
- Generates `/openapi.json` endpoint automatically
- Works with Rust type system

**Example:**
```rust
use utoipa::{OpenApi, ToSchema};

#[derive(ToSchema, Serialize)]
struct UISchema {
    schema_type: String,
    fields: Vec<Field>,
}

#[utoipa::path(
    get,
    path = "/api/ui-schema/{id}",
    responses(
        (status = 200, body = UISchema)
    )
)]
async fn get_ui_schema(id: Path<Uuid>) -> Json<UISchema> {
    // ...
}
```

**Frontend consumption:**
```bash
# Generate TypeScript types from OpenAPI spec
npx openapi-typescript http://localhost:3000/openapi.json -o src/api/schema.ts
```

**Confidence: MEDIUM** - utoipa was active and well-maintained in training data, but versions should be verified.

### Code Generation

| Technology | Purpose | Confidence | Rationale |
|------------|---------|------------|-----------|
| **openapi-typescript** | Generate TS types | LOW | Keeps frontend types in sync |
| **openapi-generator** | Alternative option | LOW | More features but heavier |

**Recommendation:**
- **Use openapi-typescript** for type generation only
- **Write fetch wrapper manually** for better control

**Why not full client generation:**
- Generated clients are often bloated
- Custom fetch wrapper is ~50 lines, more maintainable
- You control error handling, retries, auth injection

**Pattern:**
```typescript
import type { paths } from './api/schema';

type GetUISchemaResponse = paths['/api/ui-schema/{id}']['get']['responses']['200']['content']['application/json'];

async function getUISchema(id: string): Promise<GetUISchemaResponse> {
  const response = await fetch(`/api/ui-schema/${id}`);
  return response.json();
}
```

**Confidence: LOW** - This ecosystem moves fast, verify current best practices.

### Validation

| Technology | Version | Purpose | Confidence | Rationale |
|------------|---------|---------|------------|-----------|
| **validator** | 0.18.x | Rust validation | LOW | Derive-based validation |
| **zod** | 3.x | TypeScript validation | MEDIUM | Runtime type checking |

**Backend validation (Rust):**
```rust
use validator::Validate;

#[derive(Validate, Deserialize, ToSchema)]
struct CreateFormRequest {
    #[validate(length(min = 1, max = 100))]
    name: String,
    #[validate]
    fields: Vec<Field>,
}
```

**Frontend validation (optional):**
- Zod for runtime validation of API responses
- Mostly unnecessary if TypeScript types are generated from OpenAPI
- Use for extra safety in critical flows

**Confidence: MEDIUM** - Validation is well-established, but library versions may differ.

## WebSocket Layer

| Technology | Version | Purpose | Confidence | Rationale |
|------------|---------|---------|------------|-----------|
| **axum WebSocket** | Built-in | Server-side WS | MEDIUM | Native Axum support |
| **tokio-tungstenite** | 0.21.x | WS implementation | LOW | Used internally by Axum |
| **native WebSocket API** | Browser built-in | Client-side WS | HIGH | No library needed |

**WebSocket strategy:**
```rust
// Backend pushes notifications
async fn ws_handler(
    ws: WebSocketUpgrade,
    State(app_state): State<AppState>,
) -> impl IntoResponse {
    ws.on_upgrade(|socket| handle_socket(socket, app_state))
}

async fn handle_socket(socket: WebSocket, state: AppState) {
    // Subscribe to notification channel
    let mut rx = state.notification_tx.subscribe();
    while let Ok(notification) = rx.recv().await {
        socket.send(Message::Text(serde_json::to_string(&notification)?)).await?;
    }
}
```

**Frontend consumption:**
```typescript
const ws = new WebSocket('ws://localhost:3000/ws');
ws.onmessage = (event) => {
  const notification = JSON.parse(event.data);
  notifications.update(n => [...n, notification]);
};
```

**Confidence: MEDIUM** - Pattern is standard, Axum WS support was solid in training data.

## Testing Stack

### Backend Testing

| Technology | Version | Purpose | Confidence |
|------|---------|---------|------------|
| **cargo test** | Built-in | Unit tests | HIGH |
| **reqwest** | 0.11.x | Integration tests | MEDIUM |
| **testcontainers** | 0.15.x | DB testing | LOW |

**Testing strategy:**
```rust
#[tokio::test]
async fn test_get_ui_schema() {
    let app = create_test_app().await;
    let response = app
        .oneshot(Request::builder().uri("/api/ui-schema/123").body(Body::empty()).unwrap())
        .await
        .unwrap();
    assert_eq!(response.status(), StatusCode::OK);
}
```

**Confidence: MEDIUM** - Testing patterns are stable.

### Frontend Testing

| Technology | Version | Purpose | Confidence |
|------|---------|---------|------------|
| **vitest** | 1.x | Unit tests | MEDIUM |
| **@testing-library/svelte** | 4.x | Component tests | LOW |
| **Playwright** | 1.40+ | E2E tests | MEDIUM |

**Testing priorities:**
1. **Backend API tests**: Critical (OpenAPI contract enforcement)
2. **Component tests**: Medium (form/table rendering)
3. **E2E tests**: Low priority initially (integration smoke tests)

**Confidence: MEDIUM** - Testing libraries are mature but versions should be verified.

## Development Environment

### Tooling

| Tool | Purpose | Confidence |
|------|---------|------------|
| **rustfmt** | Rust formatting | HIGH |
| **clippy** | Rust linting | HIGH |
| **prettier** | TS/Svelte formatting | HIGH |
| **eslint** | TS/Svelte linting | HIGH |

### Recommended Setup

```bash
# Backend
cd backend
cargo build
cargo watch -x 'run'

# Frontend
cd frontend
npm install
npm run dev

# OpenAPI sync
npm run generate-types  # calls openapi-typescript
```

## Deployment Considerations

| Technology | Purpose | Confidence | Rationale |
|------------|---------|------------|-----------|
| **Docker** | Containerization | HIGH | Standard deployment |
| **docker-compose** | Local dev | HIGH | Postgres + backend + frontend |
| **nginx** | Reverse proxy | HIGH | Frontend serving + API proxy |

**Container strategy:**
- **Backend**: Multi-stage Dockerfile (builder + runtime)
- **Frontend**: Build → static files → nginx
- **Database**: Official PostgreSQL image

**Confidence: HIGH** - Deployment patterns are well-established.

## Recommendations Summary

### High Confidence Choices (Use Immediately)

| Component | Choice | Version Range | Why |
|-----------|--------|---------------|-----|
| Frontend Framework | Svelte 5 | 5.x | Runes model perfect for backend-driven UI |
| Frontend Build | Vite | 5.x | Official tooling, fast, reliable |
| Backend Framework | Axum | 0.7.x | Best REST + WebSocket + OpenAPI story |
| Database | PostgreSQL | 15+ | JSONB for flexible schemas, mature |
| DB Driver | SQLx | 0.7.x | Compile-time query verification |
| Async Runtime | Tokio | 1.35+ | Industry standard |
| Password Hashing | argon2 | 0.5.x | OWASP recommended |

### Medium Confidence Choices (Verify Versions)

| Component | Choice | Verification Needed |
|-----------|--------|-------------------|
| UI Components | Flowbite-Svelte | Check Svelte 5 compatibility |
| OpenAPI Gen | utoipa + utoipa-axum | Verify current versions |
| TypeScript Gen | openapi-typescript | Check latest API |
| Testing | vitest + Playwright | Verify Svelte 5 compatibility |

### Low Confidence Choices (Research Further)

| Component | Training Data Choice | Action |
|-----------|---------------------|--------|
| Cookie Middleware | tower-cookies | Verify Axum 0.7 compatibility |
| TS Client Gen | openapi-typescript vs openapi-generator | Benchmark both |
| Testing | cargo-nextest vs cargo test | Evaluate speed gains |

## Version Verification Checklist

Before starting implementation, verify these versions:

- [ ] Svelte 5 stable release number
- [ ] Flowbite-Svelte Svelte 5 support status
- [ ] Axum latest stable (check for 0.8 or 1.0 release)
- [ ] utoipa compatibility with Axum current version
- [ ] utoipa-axum current status (check if merged into utoipa)
- [ ] openapi-typescript current API
- [ ] vitest Svelte 5 support

## What NOT to Use

| Technology | Why Avoid | Alternative |
|------------|-----------|-------------|
| SvelteKit (initially) | Over-engineered for renderer | Vanilla Svelte + Vite |
| Diesel | Less async-friendly | SQLx |
| Full OpenAPI client gen | Bloated, less control | Custom fetch + generated types |
| Redux/Zustand | Unnecessary complexity | Svelte stores |
| Actix-web | Less ergonomic | Axum |
| React/Vue | Larger bundles, not needed | Svelte 5 |

## Installation Commands

### Backend

```bash
# Create new Rust project
cargo new backend
cd backend

# Add dependencies (verify versions first)
cargo add axum tokio serde serde_json
cargo add sqlx --features postgres,runtime-tokio-native-tls,migrate
cargo add utoipa utoipa-axum
cargo add jsonwebtoken argon2
cargo add tower tower-http
cargo add uuid --features serde,v4

# Dev dependencies
cargo add --dev reqwest
```

### Frontend

```bash
# Create new Svelte project
npm create vite@latest frontend -- --template svelte-ts
cd frontend

# Add dependencies (verify versions first)
npm install flowbite-svelte tailwindcss
npm install --save-dev @sveltejs/vite-plugin-svelte
npm install --save-dev prettier prettier-plugin-svelte
npm install --save-dev vitest @testing-library/svelte
npm install --save-dev openapi-typescript
```

## Next Steps

1. **Verify versions**: Run web searches for each MEDIUM/LOW confidence item
2. **Prototype**: Build minimal REST endpoint (Rust) + form renderer (Svelte)
3. **OpenAPI validation**: Ensure utoipa → openapi-typescript pipeline works
4. **WebSocket test**: Verify notification push flow
5. **Document patterns**: Create architectural decision records (ADRs)

## Sources

**Limitation:** Web verification was unavailable. All recommendations based on training data (cutoff: January 2025).

**Verification required for:**
- Current version numbers (all dependencies)
- Svelte 5 ecosystem maturity (was in RC/early release during training)
- utoipa-axum integration status (was early-stage during training)
- Flowbite-Svelte Svelte 5 compatibility

**Recommended verification sources:**
- crates.io for Rust dependencies
- npmjs.com for Node dependencies
- Official docs: svelte.dev, docs.rs/axum, flowbite-svelte.com
- GitHub releases for breaking changes

---

**Research confidence: MEDIUM**

Strong confidence in architectural choices (Svelte 5 + Axum is the right stack).
Low confidence in specific version numbers (need web verification).
