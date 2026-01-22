# Requirements: CallBackery Next

**Defined:** 2026-01-22
**Core Value:** The backend drives the frontend through a standardized, documented protocol. Any backend implementing the OpenAPI spec works with the frontend.

## v1 Requirements

Requirements for initial working prototype. Each maps to roadmap phases.

### Protocol & Documentation

- [ ] **PROTO-01**: OpenAPI 3.1 specification defining all REST endpoints
- [ ] **PROTO-02**: Protocol versioning scheme documented and implemented
- [ ] **PROTO-03**: Conceptual documentation explaining the mental model and design principles
- [ ] **PROTO-04**: WebSocket specification for live notifications (triggers REST calls)

### Authentication

- [ ] **AUTH-01**: User can log in with credentials
- [ ] **AUTH-02**: User can log out
- [ ] **AUTH-03**: Session management with token-based authentication
- [ ] **AUTH-04**: Session persists across browser refresh

### Navigation

- [ ] **NAV-01**: Application structure with tabs/menu switching
- [ ] **NAV-02**: Lazy loading of plugin configurations
- [ ] **NAV-03**: Backend-defined navigation structure rendered by frontend

### Tables

- [ ] **TBL-01**: Backend-defined columns rendered by frontend
- [ ] **TBL-02**: Continuous scrolling (virtual/infinite scroll, NOT pagination)
- [ ] **TBL-03**: Column sorting (backend-driven)
- [ ] **TBL-04**: Column filtering (backend-driven)
- [ ] **TBL-05**: XLSX export capability

### Forms

- [ ] **FORM-01**: Core field types (text, number, date, select, checkbox, textarea)
- [ ] **FORM-02**: Backend-driven validation with error display
- [ ] **FORM-03**: Field dependencies (show/hide/enable based on other field values)
- [ ] **FORM-04**: Form submission with success/error handling

### Hierarchical Relationships

- [ ] **HIER-01**: Parent-child data patterns (master-detail views)
- [ ] **HIER-02**: Selection in parent triggers child data loading
- [ ] **HIER-03**: Context propagation from parent to child plugins

### Backend Implementation

- [ ] **BACK-01**: Rust/Axum server implementing the OpenAPI spec
- [ ] **BACK-02**: PostgreSQL database with SQLx for type-safe queries
- [ ] **BACK-03**: JWT-based session management
- [ ] **BACK-04**: WebSocket endpoint for live notifications

### Frontend Implementation

- [ ] **FRONT-01**: Svelte 5 application with runes ($state, $derived, $effect)
- [ ] **FRONT-02**: Flowbite-Svelte component library integration
- [ ] **FRONT-03**: REST client consuming OpenAPI endpoints
- [ ] **FRONT-04**: WebSocket client for live notifications

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Tables

- **TBL-06**: Row actions (buttons per row)
- **TBL-07**: Inline editing
- **TBL-08**: Multi-select with bulk actions
- **TBL-09**: Column reordering and visibility toggle

### Advanced Forms

- **FORM-05**: File upload fields
- **FORM-06**: Rich text editor field
- **FORM-07**: Autocomplete/search fields
- **FORM-08**: Array/repeater fields

### Notifications

- **NOTF-01**: Toast notifications for user feedback
- **NOTF-02**: Real-time data refresh on WebSocket events

### Additional Plugins

- **PLUG-01**: HTML display plugin (static content from backend)
- **PLUG-02**: Chart/visualization plugin
- **PLUG-03**: Tree view plugin

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Perl backend | Existing CallBackery serves as conceptual reference only |
| Migration tooling | This is a new framework, not a migration path |
| JSON-RPC | Replaced by REST + WebSocket |
| Mobile-specific UI | Web-first, responsive via Flowbite |
| File upload | High complexity, defer to v2 |
| Charts/visualizations | Defer to v2 |
| Drag-and-drop | Defer to v2 |
| OAuth/SSO | Email/password sufficient for v1 |
| Role-based permissions | Simple auth sufficient for v1 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| PROTO-01 | Phase 1 | Pending |
| PROTO-02 | Phase 1 | Pending |
| PROTO-03 | Phase 1 | Pending |
| PROTO-04 | Phase 1 | Pending |
| AUTH-01 | Phase 2 | Pending |
| AUTH-02 | Phase 2 | Pending |
| AUTH-03 | Phase 2 | Pending |
| AUTH-04 | Phase 2 | Pending |
| BACK-01 | Phase 2 | Pending |
| BACK-02 | Phase 2 | Pending |
| BACK-03 | Phase 2 | Pending |
| BACK-04 | Phase 2 | Pending |
| FRONT-01 | Phase 3 | Pending |
| FRONT-02 | Phase 3 | Pending |
| FRONT-03 | Phase 3 | Pending |
| FRONT-04 | Phase 3 | Pending |
| NAV-01 | Phase 3 | Pending |
| NAV-02 | Phase 3 | Pending |
| NAV-03 | Phase 3 | Pending |
| TBL-01 | Phase 4 | Pending |
| TBL-02 | Phase 4 | Pending |
| TBL-03 | Phase 4 | Pending |
| TBL-04 | Phase 4 | Pending |
| TBL-05 | Phase 4 | Pending |
| FORM-01 | Phase 5 | Pending |
| FORM-02 | Phase 5 | Pending |
| FORM-03 | Phase 5 | Pending |
| FORM-04 | Phase 5 | Pending |
| HIER-01 | Phase 6 | Pending |
| HIER-02 | Phase 6 | Pending |
| HIER-03 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 31 total
- Mapped to phases: 31
- Unmapped: 0 ✓

---
*Requirements defined: 2026-01-22*
*Last updated: 2026-01-22 after initial definition*
