# Roadmap: CallBackery Next

## Overview

A backend-agnostic framework where the backend configures the frontend through a standardized OpenAPI protocol. The journey begins with formalizing the protocol specification and documentation, then builds the Rust/Axum reference backend with authentication and database integration. Next comes the Svelte 5 frontend with navigation and protocol clients, followed by the core plugin types (tables and forms) and finally hierarchical relationships that enable master-detail patterns. Each phase delivers a complete, verifiable capability that builds toward a working prototype demonstrating backend-driven UI configuration.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Protocol Foundation** - Capability-based OpenAPI spec, versioning, conceptual docs, WebSocket spec
- [ ] **Phase 2: Backend Core** - Rust/Axum backend with auth, database, WebSocket implementation
- [ ] **Phase 3: Frontend Foundation** - Svelte 5 app with navigation, REST/WebSocket clients
- [ ] **Phase 4: Table Plugin** - Backend-defined columns, continuous scrolling, sort/filter, export
- [ ] **Phase 5: Form Plugin** - Field types, validation, dependencies, submission
- [ ] **Phase 6: Hierarchical Relationships** - Master-detail patterns, context propagation

## Phase Details

### Phase 1: Protocol Foundation
**Goal**: Protocol contract is formally defined using capability-based architecture before any implementation
**Depends on**: Nothing (first phase)
**Requirements**: PROTO-01, PROTO-02, PROTO-03, PROTO-04
**Success Criteria** (what must be TRUE):
  1. OpenAPI 3.1 specification defines capability-based endpoints (surfaces, components, data, actions)
  2. Message envelope schemas defined (not plugin-specific schemas)
  3. Component model uses ID-based adjacency list (flat, not nested)
  4. Data binding uses JSON Pointer paths (RFC 6901)
  5. Schema discovery/exchange mechanism documented
  6. WebSocket specification defines event message format
  7. Generic validation error format (path-based, not field-code-specific)
  8. Conceptual documentation explains the puppet-master mental model
  9. Protocol versioning scheme documented
**Plans**: 4 plans in 3 waves

Plans:
- [ ] 01-01-PLAN.md - Core protocol schemas (component model, data binding, error format)
- [ ] 01-02-PLAN.md - Protocol operations and REST endpoints (surfaces, actions, schema discovery)
- [ ] 01-03-PLAN.md - WebSocket specification (events, subscription, lifecycle)
- [ ] 01-04-PLAN.md - Conceptual documentation (mental model, quick-start, versioning)

### Phase 2: Backend Core
**Goal**: Rust/Axum backend implements the protocol with authentication and database integration
**Depends on**: Phase 1
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, BACK-01, BACK-02, BACK-03, BACK-04
**Success Criteria** (what must be TRUE):
  1. User can log in with credentials and receive a JWT token
  2. User can log out and token is invalidated
  3. Session persists across requests using token-based authentication
  4. Session survives server restart (tokens remain valid)
  5. Backend serves OpenAPI spec at /openapi.json matching Phase 1 specification
  6. PostgreSQL database is connected with SQLx for type-safe queries
  7. WebSocket endpoint accepts connections and can broadcast notifications
  8. Plugin trait system exists (screen_config, get_data, process_data methods)
**Plans**: TBD

Plans:
- [ ] TBD

### Phase 3: Frontend Foundation
**Goal**: Svelte 5 frontend consumes the protocol with navigation and real-time updates
**Depends on**: Phase 2
**Requirements**: FRONT-01, FRONT-02, FRONT-03, FRONT-04, NAV-01, NAV-02, NAV-03
**Success Criteria** (what must be TRUE):
  1. Frontend renders using Svelte 5 runes ($state, $derived, $effect)
  2. Flowbite-Svelte components are integrated and styled with Tailwind
  3. REST client calls backend endpoints with automatic auth token injection
  4. WebSocket client connects to backend and receives live notifications
  5. User sees application navigation structure (tabs/menu) fetched from backend
  6. Plugin configurations are lazy loaded (fetched when user opens tab/menu item)
  7. Frontend renders different navigation based on backend-provided structure
**Plans**: TBD

Plans:
- [ ] TBD

### Phase 4: Table Plugin
**Goal**: Users can view backend-defined tabular data with sorting, filtering, and export
**Depends on**: Phase 3
**Requirements**: TBL-01, TBL-02, TBL-03, TBL-04, TBL-05
**Success Criteria** (what must be TRUE):
  1. Table displays columns defined by backend (name, type, width, alignment)
  2. Table uses continuous scrolling (virtual/infinite scroll, NOT pagination)
  3. User can click column headers to sort (triggers backend re-query)
  4. User can filter columns (filter UI triggers backend re-query with filter params)
  5. User can export table data to XLSX file
  6. Backend-defined table works without frontend code changes
**Plans**: TBD

Plans:
- [ ] TBD

### Phase 5: Form Plugin
**Goal**: Users can enter data through backend-defined forms with validation and dependencies
**Depends on**: Phase 4
**Requirements**: FORM-01, FORM-02, FORM-03, FORM-04
**Success Criteria** (what must be TRUE):
  1. Form displays fields defined by backend (text, number, date, select, checkbox, textarea)
  2. Backend validation rules are enforced with error messages shown at field level
  3. Field visibility/enablement changes based on other field values (dependencies)
  4. User can submit form and see success confirmation or error messages
  5. Backend-defined form works without frontend code changes
**Plans**: TBD

Plans:
- [ ] TBD

### Phase 6: Hierarchical Relationships
**Goal**: Users can navigate master-detail relationships where parent selection drives child content
**Depends on**: Phase 5
**Requirements**: HIER-01, HIER-02, HIER-03
**Success Criteria** (what must be TRUE):
  1. Parent table row selection triggers child plugin data loading
  2. Child plugin displays data filtered by parent selection context
  3. Parent selection ID propagates to child plugin configuration requests
  4. Multiple levels of hierarchy work (grandparent -> parent -> child)
  5. Working prototype demonstrates all components together (nav -> table -> form -> hierarchy)
**Plans**: TBD

Plans:
- [ ] TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Protocol Foundation | 0/4 | Planned (capability-based) | - |
| 2. Backend Core | 0/TBD | Not started | - |
| 3. Frontend Foundation | 0/TBD | Not started | - |
| 4. Table Plugin | 0/TBD | Not started | - |
| 5. Form Plugin | 0/TBD | Not started | - |
| 6. Hierarchical Relationships | 0/TBD | Not started | - |

---
*Roadmap created: 2026-01-22*
*Last updated: 2026-01-23 (capability-based re-planning)*
