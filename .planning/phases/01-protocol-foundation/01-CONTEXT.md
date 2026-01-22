# Phase 1: Protocol Foundation - Context

**Gathered:** 2026-01-22
**Status:** Ready for planning

<domain>
## Phase Boundary

Formalize the protocol contract before any implementation. Deliver: OpenAPI 3.1 specification defining all REST endpoints, WebSocket specification for notifications, conceptual documentation explaining the mental model, versioning scheme, and formal error code enumeration.

</domain>

<decisions>
## Implementation Decisions

### Spec Structure
- Resource-centric API organization (/users, /plugins, /sessions — REST nouns, CRUD operations)
- Plugin endpoints nested under plugins: /plugins/{id}/config, /plugins/{id}/data
- Hierarchical navigation endpoints: /navigation for root, /navigation/{id}/children for nested
- Standard response envelope: all responses wrap data in {data: ..., meta: ...} structure

### Error Contract
- Semantic error codes (AUTH_INVALID, VALIDATION_FAILED, PLUGIN_NOT_FOUND) — machine-readable
- Field-level validation errors as array: errors: [{field: 'email', code: 'INVALID_FORMAT', message: '...'}]
- Errors include user-facing message as fallback, frontend can override with translations
- Internal errors return request_id that maps to server logs for debugging/support

### Versioning Approach
- Version in URL path: /api/v1/...
- Start at v1 even though no old versions — room to grow
- No deprecation window needed: backend serves the frontend, deployed together
- OpenAPI spec served at endpoint: /api/v1/openapi.json — self-hosted, always current

### Conceptual Documentation
- Primary audience: backend developers implementing backends in any language
- Core mental model: "config-driven UI" — backend returns config, frontend renders it
- Schema examples only — show JSON structures, explain fields, no implementation code
- Clean slate — no references to existing CallBackery, new users shouldn't need legacy context

### Claude's Discretion
- Exact field names and casing conventions
- OpenAPI component organization and $ref patterns
- WebSocket message structure details
- Documentation file organization

</decisions>

<specifics>
## Specific Ideas

- The protocol should feel like a well-designed REST API that happens to configure a UI
- Error responses should be consistent enough that a generic error handler works
- Conceptual docs should make someone go "oh, I get it" within 5 minutes of reading

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-protocol-foundation*
*Context gathered: 2026-01-22*
