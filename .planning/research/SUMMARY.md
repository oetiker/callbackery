# Project Research Summary

**Project:** CallBackery Clean-room Redesign
**Domain:** Backend-Driven UI Framework (Server-Configures-Client Pattern)
**Researched:** 2026-01-22
**Confidence:** MEDIUM-HIGH

## Executive Summary

Backend-driven UI frameworks represent a specialized architecture where the server sends component specifications (not just data) to a generic frontend renderer. This pattern enables building CRUD applications where business logic and UI structure are entirely backend-controlled, with the frontend acting as a "dumb" renderer. The research analyzed CallBackery's proven 10+ year implementation and combined it with modern web technologies to chart a path for a clean-room redesign.

**The recommended approach:** Build an OpenAPI-first protocol using Rust/Axum for the backend and Svelte 5 for the frontend. The protocol defines formal contracts for plugin types (forms, tables, actions, HTML displays) with type-safe endpoints for each. Svelte 5's runes system maps perfectly to backend-driven state updates, while Axum provides excellent REST + WebSocket + OpenAPI tooling integration. The architecture separates concerns clearly: configuration (what exists), capabilities (what user can do), and data (actual records) through distinct endpoints.

**Key risk:** The protocol IS the product. Unlike traditional applications where frontend and backend evolve together, this framework's protocol must be formally specified and versioned from day one. CallBackery's implicit protocol led to tight coupling and inability to evolve without breaking changes. Mitigation: Write OpenAPI spec before implementation, validate all code against spec, version endpoints from start (/v1/), and maintain N-1 version compatibility. Secondary risk: Feature bloat leading to monolithic base classes. Mitigation: Use composition over inheritance (Rust traits), keep abstractions focused, and schedule periodic refactoring reviews.

## Key Findings

### Recommended Stack

The stack research identified a clear split between high-confidence architectural choices and version-specific dependencies requiring verification. All recommendations derive from the backend-driven UI pattern's specific needs: dynamic configuration rendering, type-safe contracts, and real-time update capabilities.

**Core technologies:**
- **Svelte 5** (frontend framework) — Runes model ($state, $derived) perfectly matches backend-driven state updates; smaller bundle than React/Vue critical for framework distribution
- **Axum 0.7** (backend framework) — Best Rust option for REST + WebSocket + OpenAPI; type-safe extractors prevent runtime errors; ergonomic handler functions
- **PostgreSQL 15+** (database) — JSONB columns for flexible UI schema storage; mature ACID guarantees; works well with compile-time query verification
- **SQLx 0.7** (database driver) — Compile-time SQL verification prevents deployment of broken queries; native async/await support
- **utoipa 4.x** (OpenAPI generation) — Rust derive macros keep spec in sync with code; generates /openapi.json endpoint automatically
- **openapi-typescript 6.x** (TypeScript client) — Generates frontend types from OpenAPI spec ensuring frontend/backend contract alignment

**Confidence notes:** Stack choices are architecturally sound (HIGH confidence) but specific version numbers may have evolved since training cutoff January 2025 (MEDIUM confidence on versions). Key dependencies to verify: Flowbite-Svelte compatibility with Svelte 5, utoipa-axum integration status, current openapi-typescript API.

### Expected Features

Backend-driven UI frameworks have three feature categories: table stakes (missing = unusable), differentiators (competitive advantages), and anti-features (deliberate exclusions).

**Must have (table stakes):**
- **Plugin discovery** — Frontend fetches navigation structure (tabs/menu) from backend; lazy loads plugin configs on-demand
- **Screen configuration schema** — Protocol supports forms, tables, actions, HTML displays as distinct types with type-specific schemas
- **CRUD operations** — Create, Read, Update, Delete for all plugin types; standard REST verbs or RPC methods
- **Field types** — Text, number, select, checkbox, date, textarea, file upload
- **Pagination & sorting** — Tables send firstRow/lastRow params; backend returns sliced data
- **Field-level validation** — Validation rules sent with field config; backend enforces, frontend displays errors
- **Authentication & authorization** — Session management; per-plugin access control; permission-based UI filtering
- **Parent-child relationships** — Selection in parent table populates child component; master-detail pattern

**Should have (competitive advantages):**
- **OpenAPI specification** — Self-documenting protocol; enables code generation; industry-standard contract
- **Real-time updates** — WebSocket for server-push notifications; data changes propagate to all clients
- **Export to XLSX** — Common business requirement; backend generates file from table data
- **Multi-language support** — Translation keys in config; frontend resolves; enables international deployments
- **Field dependencies** — One field's value triggers form reconfiguration; enables complex conditional forms
- **Context-sensitive actions** — Operations appear based on row data/selection; cleaner UIs

**Defer (v2+):**
- Multi-step wizards (high complexity, uncommon use case)
- Audit trail (compliance feature, not core functionality)
- Inline editing (UX enhancement, not essential pattern)
- Undo/redo (niche power-user feature)
- Card/grid view (alternative layout, standard table sufficient initially)
- Theming beyond CSS variables (customization can wait)

### Architecture Approach

The architecture enforces clear separation between backend (business logic, validation, data access) and frontend (rendering, UI state). Backend exposes REST endpoints for configuration/data and WebSocket for notifications. Frontend is stateless — all application state reconstructible from URL + API responses.

**Major components:**
1. **Protocol Layer** — OpenAPI 3.1 spec defines contracts; REST for request/response; WebSocket for server-push notifications (one-way, backend to client only)
2. **Plugin System** — Trait-based on backend (Rust); registry pattern for discovery; separate types (FormPlugin, TablePlugin, ActionPlugin, HtmlPlugin) with type-specific endpoints
3. **Frontend Renderer** — Svelte 5 components (TableComponent, FormComponent) receive schemas and render dynamically; protocol client wraps REST API; WebSocket client triggers refetch on notifications
4. **Data Layer** — Repository pattern per plugin; domain models separate from database schema; transactions for mutations, read queries can be outside transactions

**Key patterns:**
- **Lazy loading**: Frontend requests plugin configs only when tabs opened
- **Configuration vs capabilities**: Static config (what exists) separate from dynamic capabilities (what user can do)
- **WebSocket as "poke" mechanism**: Notifications don't deliver data, they trigger REST refetch (avoids consistency issues)
- **Type-specific endpoints**: `/v1/forms/{id}/config` vs `/v1/tables/{id}/config` (no discriminated unions)

### Critical Pitfalls

Based on CallBackery's 10-year evolution, the research identified 15 pitfalls across protocol, frontend, backend, and cross-cutting concerns. The top 5 highest-severity issues:

1. **Implicit Protocol Assumptions** — CallBackery's protocol relies on undocumented conventions (error codes, field ordering, default values). Frontend assumes `exc.code === 6` means auth required but nothing documents this. **Prevention:** OpenAPI specification FIRST before implementation; document semantics not just syntax; formalize error codes; version protocol from day one.

2. **Protocol Versioning Afterthought** — No version negotiation means breaking changes require "flag day" upgrades. CallBackery has no protocol version field, making evolution impossible without breaking all clients. **Prevention:** Version in URL path (/v1/); version negotiation (client sends supported versions); compatibility policy (N-1 versions supported); deprecation process before removal.

3. **Generic Plugin Protocol Instead of Typed Variants** — Single endpoint returns different structures for forms vs tables; frontend must introspect response type; shared fields have different semantics. **Prevention:** Separate endpoints per type (/v1/forms/{id} vs /v1/tables/{id}); type-specific schemas; no discriminated unions at protocol level.

4. **Client-Side Logic Drift** — Frontend accumulates business logic (validation, permissions checks) duplicating backend. CallBackery has validation on both sides with no clear boundary. **Prevention:** Dumb frontend principle (frontend renders, backend decides); backend validation is authoritative; frontend validation is UX hint only.

5. **Authorization Mixed with Configuration** — Backend returns different configs based on user permissions; same endpoint varies by user; caching breaks. **Prevention:** Separate capabilities from config; config describes what exists (same for all users); capabilities describe what user can do (user-specific); action-level permissions.

**Phase-specific warnings:** Phase 1 (OpenAPI Spec) risks implicit assumptions and missing versioning; Phase 2 (Rust Backend) risks database-as-protocol and synchronous operations; Phase 3 (Svelte Frontend) risks client logic drift and framework coupling.

## Implications for Roadmap

Based on architectural dependencies, feature priorities, and pitfall avoidance, the research suggests 6 core phases followed by enhancement phases. The order reflects: protocol-first approach, simplest-to-complex plugin types, and separation of core features from differentiators.

### Phase 1: Protocol Foundation (OpenAPI Spec + Auth)
**Rationale:** Everything depends on formal protocol contract and authentication. Building anything before defining the protocol leads to implicit assumptions (Pitfall #1). Versioning must be in place from day one (Pitfall #2).

**Delivers:**
- Complete OpenAPI 3.1 specification for all endpoints
- Protocol versioned (/v1/ paths)
- Authentication endpoints (login, logout, session management)
- Error code enum with formal semantics
- Type-specific endpoint structure defined

**Addresses:** Protocol versioning (PITFALLS.md), authentication (FEATURES.md table stakes), formal schema validation (PITFALLS.md)

**Stack decisions:** OpenAPI spec format; JWT vs session cookies; error handling conventions

**Research flag:** LOW — OpenAPI patterns are well-documented; standard auth patterns

### Phase 2: Backend Core (Plugin Registry + Auth Implementation)
**Rationale:** Backend trait system and plugin registry are foundational. All plugin types depend on this abstraction. Auth middleware blocks unauthorized access. Async/await from start avoids synchronous blocking (Pitfall #13).

**Delivers:**
- Rust Plugin trait (screen_config, get_data, process_data, validate_data)
- Plugin registry pattern (register, get, list_for_user)
- Auth middleware (JWT handling, session validation)
- SQLx database connection pooling
- Domain model layer (separate from database schema, avoids Pitfall #12)

**Uses:** Axum (REST framework), SQLx (database), argon2 (password hashing), jsonwebtoken (JWT)

**Implements:** Plugin System component (ARCHITECTURE.md), Data Layer with repository pattern

**Avoids:** Database schema as protocol (Pitfall #12), synchronous operations (Pitfall #13)

**Research flag:** LOW — Axum patterns well-documented; trait system is standard Rust

### Phase 3: Frontend Foundation (Protocol Client + Routing)
**Rationale:** Frontend needs protocol client and routing before rendering components. Client-side validation must be UX-only (Pitfall #6). Framework-agnostic protocol prevents tight coupling (Pitfall #9).

**Delivers:**
- TypeScript types generated from OpenAPI (openapi-typescript)
- REST client wrapper (fetch with auth injection, error handling)
- SvelteKit routing (/tables/{id}, /forms/{id})
- Auth provider (session store, login/logout handlers)
- Navigation component (tabs from backend config)

**Uses:** Svelte 5 (reactive framework), Vite (build tool), SvelteKit (routing), openapi-typescript (type generation)

**Implements:** Frontend Renderer (ARCHITECTURE.md), Protocol Client layer

**Avoids:** Client-side logic drift (Pitfall #6), tight coupling to UI framework (Pitfall #9)

**Research flag:** MEDIUM — Svelte 5 runes API may have evolved; verify current syntax against docs

### Phase 4: Simplest Plugin (HTML Display)
**Rationale:** HTML plugin has no data operations, validating plugin system works without complexity. Proves lazy loading and navigation integration.

**Delivers:**
- Backend HtmlPlugin implementation
- Frontend HtmlComponent renderer
- Plugin config caching strategy
- Navigation API endpoint (GET /v1/navigation/config)
- End-to-end flow: login → navigation → HTML plugin display

**Addresses:** Plugin discovery (FEATURES.md), navigation structure (FEATURES.md), lazy plugin configuration (FEATURES.md)

**Avoids:** Progressive feature bloat (Pitfall #15) — keep implementation minimal

**Research flag:** LOW — Simplest component, no novel patterns

### Phase 5: Table Plugin (Read-Only Data)
**Rationale:** Tables are read-only (simpler than forms) but represent core CRUD use case. Pagination and sorting are essential table stakes. Parent-child relationships enable complex applications.

**Delivers:**
- Backend TablePlugin base trait
- Example table implementation (users, products, etc.)
- Frontend TableComponent (Flowbite-Svelte table)
- Pagination (offset/limit parameters)
- Sorting (sortColumn/sortDesc parameters)
- Filtering (formData passed to query)
- Parent-child relationships (selection passes ID to child plugin)

**Addresses:** Tables (FEATURES.md table stakes), pagination (FEATURES.md), sorting (FEATURES.md), parent-child relationships (FEATURES.md)

**Uses:** Flowbite-Svelte (table components), Tailwind CSS (styling)

**Avoids:** Generic plugin protocol (Pitfall #5) — use type-specific /v1/tables/{id}/config endpoint

**Research flag:** MEDIUM — Verify Flowbite-Svelte Svelte 5 compatibility

### Phase 6: Form Plugin (Data Entry + Validation)
**Rationale:** Forms require validation logic and field dependencies. Builds on table patterns but adds mutation operations. Field types and validation rules are table stakes.

**Delivers:**
- Backend FormPlugin base trait
- Example form implementation (user creation/editing)
- Frontend FormComponent (dynamic form builder)
- Field types: text, number, date, select, checkbox, textarea
- Field-level validation (backend authoritative, frontend UX hints)
- Field dependencies (triggerField parameter reconfigures form)
- Submit action with error handling
- Optimistic updates with rollback (Pitfall #7 mitigation)

**Addresses:** Forms (FEATURES.md), field types (FEATURES.md), field-level validation (FEATURES.md), field dependencies (FEATURES.md)

**Avoids:** Optimistic updates without rollback (Pitfall #7), no formal schema validation (Pitfall #4)

**Research flag:** LOW — Form validation patterns are standard

### Phase Ordering Rationale

- **Protocol first** (Phase 1) prevents implicit assumptions and enables parallel frontend/backend development
- **Backend before frontend** (Phase 2 before 3) ensures contract implementable before consumption
- **HTML before tables before forms** follows complexity gradient: no data → read-only → read-write
- **Navigation integrated in Phase 4** requires backend plugin registry (Phase 2) and frontend routing (Phase 3)
- **Tables before forms** because read operations simpler than write; forms can reuse table patterns for select fields
- **Defer advanced features** (WebSocket, export, multi-language) until core CRUD cycle proven

### Deferred Phases (Post-MVP)

**Phase 7: Real-time Updates (WebSocket)**
- Backend WebSocket server (notification broadcaster)
- Frontend WebSocket client (triggers REST refetch on notification)
- Plugin-level data change events
- **Avoids:** State synchronization via polling (Pitfall #3)
- **Research flag:** LOW — Standard WebSocket patterns

**Phase 8: Advanced Features**
- Export to XLSX (common business requirement)
- Multi-language support (translation keys in config)
- File upload (multipart endpoint, progress tracking)
- Bulk operations (multi-select + action)
- **Research flag:** MEDIUM — Export library selection; i18n strategy

**Phase 9: Admin Features**
- User management plugin
- Permission configuration UI
- Audit trail (who changed what when)
- **Research flag:** LOW — Standard admin patterns

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 3:** Svelte 5 specific runes API — verify $state, $derived, $effect syntax against svelte.dev
- **Phase 5:** Flowbite-Svelte Svelte 5 compatibility — check GitHub issues, test basic table rendering
- **Phase 8:** XLSX export library — evaluate options (rust_xlsxwriter vs others), benchmark performance

**Phases with standard patterns (skip research-phase):**
- **Phase 1:** OpenAPI spec — industry standard, well-documented
- **Phase 2:** Rust backend patterns — Axum docs comprehensive, trait system standard
- **Phase 4:** HTML rendering — trivial implementation
- **Phase 6:** Form validation — standard web patterns

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Architectural choices sound (Svelte 5 + Axum right for pattern); version numbers from training data may be stale; verify Flowbite-Svelte Svelte 5 compatibility |
| Features | HIGH | Based on CallBackery's 10+ year production use; table stakes/differentiators validated by real deployments; feature dependencies clear from codebase analysis |
| Architecture | HIGH | Plugin pattern proven in CallBackery; REST + WebSocket separation of concerns well-understood; type-specific endpoints fix CallBackery's generic protocol issue |
| Pitfalls | HIGH | All 15 pitfalls derived from CallBackery codebase review; CONCERNS.md documents known issues; pattern mistakes clearly identifiable |

**Overall confidence:** MEDIUM-HIGH

Core architectural recommendations are solid (backend-driven pattern proven, Svelte 5 + Axum excellent fit). Uncertainty limited to:
1. Specific library versions (Svelte 5 ecosystem maturity, utoipa-axum integration status)
2. OpenAPI 3.1 advanced features (schema composition, discriminated unions)
3. Flowbite-Svelte Svelte 5 compatibility (was in flux during training cutoff)

### Gaps to Address

**During Phase 1 (OpenAPI Spec):**
- **Gap:** OpenAPI 3.1 discriminated union syntax for error responses
- **Mitigation:** Review OpenAPI 3.1 spec section on oneOf/anyOf; validate with openapi-generator

**During Phase 2 (Rust Backend):**
- **Gap:** utoipa-axum current integration status (was early-stage in training)
- **Mitigation:** Check crates.io for latest version; verify axum 0.7 compatibility; test OpenAPI generation in prototype

**During Phase 3 (Svelte Frontend):**
- **Gap:** Svelte 5 runes API may have changed syntax
- **Mitigation:** Review svelte.dev documentation; test $state, $derived in minimal example before full implementation

**During Phase 5 (Table Plugin):**
- **Gap:** Flowbite-Svelte Svelte 5 compatibility unknown
- **Mitigation:** Check GitHub issues; test table component; fallback to headless UI + Tailwind if incompatible

**During implementation (all phases):**
- **Gap:** Real-world usage patterns from CallBackery deployments not analyzed
- **Mitigation:** Interview CallBackery users about pain points if possible; start with conservative feature set; iterate based on feedback

## Sources

### Primary (HIGH confidence)
- CallBackery codebase analysis (`.planning/codebase/ARCHITECTURE.md`, `CONCERNS.md`)
- CallBackery plugin system (`lib/CallBackery/GuiPlugin/Abstract*.pm`) — 10+ years production use
- CallBackery RPC protocol (`lib/CallBackery/Controller/RpcService.pm`) — proven patterns
- CallBackery Qooxdoo frontend (`lib/CallBackery/qooxdoo/callbackery/source/class/`) — client implementation

### Secondary (MEDIUM confidence)
- Training data on Svelte 5, Axum, PostgreSQL (cutoff: January 2025)
- Industry-standard patterns for REST APIs, OpenAPI, WebSocket
- OWASP recommendations (argon2 password hashing, CSRF protection)

### Tertiary (LOW confidence — verify before use)
- Specific version numbers for dependencies (from training data, may be stale)
- Svelte 5 runes syntax specifics (was in RC during training)
- utoipa-axum integration status (was early-stage during training)
- Flowbite-Svelte Svelte 5 compatibility (needs verification)

**Verification sources recommended:**
- crates.io for Rust dependency versions (Axum, utoipa, SQLx, tokio)
- npmjs.com for Node dependency versions (Svelte, Vite, openapi-typescript)
- Official docs: svelte.dev, docs.rs/axum, flowbite-svelte.com
- GitHub releases for breaking changes in ecosystem libraries

---
*Research completed: 2026-01-22*
*Ready for roadmap: yes*
