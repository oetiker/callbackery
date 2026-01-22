# CallBackery Next

## What This Is

A backend-agnostic framework for building data-driven web applications where the backend configures the frontend through a standardized protocol. Includes an OpenAPI specification, a Svelte 5 + Flowbite-Svelte frontend, and a Rust/Axum reference backend. This is a clean-room redesign inspired by CallBackery, extracting its core ideas while fixing accumulated inconsistencies and enabling any language to implement compliant backends.

## Core Value

**The backend drives the frontend through a standardized, documented protocol.** Any backend implementing the OpenAPI spec works with the frontend — no frontend changes needed for new applications.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Conceptual documentation explaining the mental model and design principles
- [ ] OpenAPI specification defining the REST API contract
- [ ] WebSocket specification for live notifications
- [ ] Rust/Axum backend implementing the specs
- [ ] Svelte 5 frontend consuming the specs
- [ ] Navigation component (application structure, tabs/menu switching)
- [ ] Table component (data display with backend-defined columns)
- [ ] Form component (data entry with backend-defined fields and validation)
- [ ] Hierarchical relationships (parent-child data patterns)
- [ ] Authentication flow (login, session management)
- [ ] Working prototype demonstrating all components together

### Out of Scope

- Perl backend implementation — existing CallBackery serves as conceptual reference only
- Migration tooling from old CallBackery — this is a new framework
- Advanced features (file upload, charts, drag-drop) — defer to v2
- Mobile-specific UI — web-first, responsive via Flowbite
- JSON-RPC — replaced by REST + WebSocket

## Context

**Origin:** CallBackery is a Perl/Mojolicious framework that pioneered the "backend-configures-frontend" pattern with a Qooxdoo RIA frontend. Over years of organic growth, features were added inconsistently and documentation degraded. The conceptual clarity was lost.

**This project:** Extract what works (the pattern), document it properly, formalize it as a spec, and build a complete modern implementation. The result:
1. A clear mental model developers can learn
2. An OpenAPI spec any backend can implement
3. A Rust/Axum reference backend proving the spec works
4. A Svelte frontend that works with any compliant backend

**Reference material:** The existing CallBackery codebase (`.planning/codebase/`) documents the current patterns — but we're modernizing the protocol.

**Key CallBackery concepts to preserve:**
- Plugin system (forms, tables, actions, HTML displays)
- Config-driven UI generation (backend defines what frontend renders)
- User/session management
- Lazy loading of plugin configurations

**Key changes from CallBackery:**
- REST API instead of JSON-RPC — cleaner, standard tooling
- WebSocket for push notifications — triggers frontend to refresh via REST
- OpenAPI specification — formal contract, not implicit protocol
- Modern frontend stack — Svelte 5 replaces Qooxdoo

## Constraints

- **Frontend**: Svelte 5 + Flowbite-Svelte (Tailwind-based components)
- **Backend**: Rust + Axum (reference implementation)
- **API**: REST (OpenAPI 3.1 specification)
- **Real-time**: WebSocket for notifications (events trigger REST calls)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| REST + WebSocket over JSON-RPC | Cleaner separation, standard tooling, better caching | — Pending |
| Svelte 5 frontend | Modern reactivity, smaller bundle, better DX, Flowbite ecosystem | — Pending |
| Rust/Axum backend | Type-safe, performant, proves spec works outside Perl | — Pending |
| OpenAPI spec | Industry standard, enables code generation, self-documenting | — Pending |
| Documentation-first | Root cause fix — unclear mental model leads to inconsistent implementations | — Pending |

---
*Last updated: 2026-01-22 after initialization*
