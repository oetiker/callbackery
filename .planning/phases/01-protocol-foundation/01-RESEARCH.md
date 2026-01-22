# Phase 1: Protocol Foundation - Research

**Researched:** 2026-01-22
**Domain:** OpenAPI 3.1 specification design, REST API architecture, WebSocket notification protocols
**Confidence:** HIGH

## Summary

This phase focuses on creating a formal protocol specification before any implementation. Research confirms that OpenAPI 3.1 is the industry standard for REST API specification, with JSON Schema 2020-12 alignment enabling rich data validation. The spec-first development approach (design API contract before implementation) is widely recommended and supported by robust tooling for validation, mock servers, and code generation.

The CallBackery Next protocol combines REST for CRUD operations with WebSocket for real-time notifications, a proven hybrid architecture pattern. The "backend configures frontend" model aligns with server-driven UI (SDUI) patterns, where JSON responses define UI structure and the frontend renders dynamically.

For error handling, RFC 9457 Problem Details provides a standardized, machine-readable format. URL path versioning (/api/v1/) is the most popular approach for REST APIs, favored for simplicity and cache-friendliness. The research identifies specific pitfalls to avoid (generating specs after implementation, inadequate examples, mixing OpenAPI versions) and confirms that mock servers enable parallel frontend/backend development.

**Primary recommendation:** Create OpenAPI 3.1 specification first using spec-first methodology, adopt RFC 9457 for error responses, use camelCase for field names (JSON best practice), validate with Spectral linter, and structure conceptual documentation around the mental model with clear examples.

## Standard Stack

The established libraries/tools for OpenAPI 3.1 specification development:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| OpenAPI Spec | 3.1.0+ | API specification format | Industry standard, JSON Schema 2020-12 aligned, widely supported |
| Spectral | 6.x+ | OpenAPI linting/validation | Most popular open-source linter, customizable rules |
| OpenAPI Generator | 7.19.0+ | Code generation | 50+ language generators, active development (Jan 2026 release) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Scalar CLI | Latest | Mock server generation | Spec-first development, parallel dev workflows |
| Prism | 5.x+ | Mock server + validation | Request/response validation, multi-file specs |
| OpenAPI 3.2 | 3.2.0 | Latest spec version | Optional: webhooks, streaming, multi-document support |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| OpenAPI 3.1 | OpenAPI 3.2 | 3.2 adds webhooks, streaming, multi-doc support; 3.1 has better tool maturity |
| Spectral | Redocly CLI / Vacuum | Spectral has largest community, most flexible ruleset engine |
| RFC 9457 Problem Details | Custom error format | RFC 9457 is standardized, machine-readable, framework-agnostic |

**Installation:**
```bash
# Spectral linter
npm install -g @stoplight/spectral-cli

# OpenAPI Generator (for validation)
npm install -g @openapitools/openapi-generator-cli

# Mock server options
npm install -g @scalar/cli
# or
npm install -g @stoplight/prism-cli
```

## Architecture Patterns

### Recommended Specification Structure
```
spec/
├── openapi.yaml              # Root OpenAPI document
├── components/
│   ├── schemas/              # Reusable data models
│   │   ├── User.yaml
│   │   ├── Plugin.yaml
│   │   └── Error.yaml
│   ├── responses/            # Reusable responses
│   │   ├── ValidationError.yaml
│   │   └── NotFound.yaml
│   ├── parameters/           # Reusable parameters
│   │   └── PluginId.yaml
│   └── examples/             # Reusable examples
│       └── UserExample.yaml
├── paths/
│   ├── users.yaml            # /users endpoints
│   ├── plugins.yaml          # /plugins endpoints
│   └── navigation.yaml       # /navigation endpoints
└── docs/
    ├── conceptual.md         # Mental model documentation
    ├── getting-started.md    # Quick start guide
    └── errors.md             # Error code catalog
```

### Pattern 1: Resource-Centric REST Design
**What:** Organize API around resources (nouns) with standard HTTP verbs
**When to use:** All CRUD operations on domain entities
**Example:**
```yaml
# Source: OpenAPI 3.1 best practices
paths:
  /api/v1/plugins:
    get:
      summary: List all plugins
      operationId: listPlugins
      tags: [Plugins]
      responses:
        '200':
          description: Successful response
          content:
            application/json:
              schema:
                type: object
                required: [data, meta]
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/Plugin'
                  meta:
                    $ref: '#/components/schemas/PaginationMeta'
```

### Pattern 2: Response Envelope Structure
**What:** Wrap all responses in consistent {data, meta} envelope
**When to use:** All successful API responses
**Example:**
```yaml
# Standard response envelope pattern
components:
  schemas:
    SuccessResponse:
      type: object
      required: [data]
      properties:
        data:
          description: Response payload
        meta:
          type: object
          description: Response metadata (pagination, version, etc)
          properties:
            version:
              type: string
              example: "1.0.0"
            timestamp:
              type: string
              format: date-time
```

### Pattern 3: RFC 9457 Problem Details for Errors
**What:** Standardized error response format with machine-readable fields
**When to use:** All 4xx and 5xx error responses
**Example:**
```yaml
# Source: RFC 9457 specification
components:
  schemas:
    ProblemDetails:
      type: object
      required: [type, title, status]
      properties:
        type:
          type: string
          format: uri
          description: URI identifying the problem type
          example: "https://api.callbackery.com/problems/validation-failed"
        title:
          type: string
          description: Human-readable problem summary
          example: "Validation Failed"
        status:
          type: integer
          description: HTTP status code
          example: 422
        detail:
          type: string
          description: Specific explanation of this occurrence
          example: "The email field is required"
        instance:
          type: string
          format: uri
          description: URI identifying this specific problem occurrence
          example: "/api/v1/users/create"
        errors:
          type: array
          description: Field-level validation errors
          items:
            type: object
            required: [field, code, message]
            properties:
              field:
                type: string
                example: "email"
              code:
                type: string
                example: "INVALID_FORMAT"
              message:
                type: string
                example: "Email address is not properly formatted"
```

### Pattern 4: Field-Level Validation Errors
**What:** Return all validation errors in a single response
**When to use:** HTTP 422 Unprocessable Entity responses
**Example:**
```yaml
# Multiple field errors returned together
responses:
  ValidationError:
    description: Validation failed
    content:
      application/problem+json:
        schema:
          allOf:
            - $ref: '#/components/schemas/ProblemDetails'
            - type: object
              properties:
                errors:
                  type: array
                  items:
                    type: object
                    required: [field, code, message]
                    properties:
                      field:
                        type: string
                      code:
                        type: string
                      message:
                        type: string
        example:
          type: "https://api.callbackery.com/problems/validation-failed"
          title: "Validation Failed"
          status: 422
          detail: "The request contains invalid fields"
          instance: "/api/v1/users/create"
          errors:
            - field: "email"
              code: "REQUIRED"
              message: "Email address is required"
            - field: "name"
              code: "INVALID_FORMAT"
              message: "Name contains unsupported characters"
```

### Pattern 5: Server-Driven UI Configuration Response
**What:** Backend returns JSON defining UI structure, frontend renders it
**When to use:** Plugin configuration endpoints that define forms, tables, etc.
**Example:**
```yaml
# Configuration-driven UI pattern
/api/v1/plugins/{id}/config:
  get:
    summary: Get plugin UI configuration
    responses:
      '200':
        content:
          application/json:
            schema:
              type: object
              required: [data]
              properties:
                data:
                  type: object
                  properties:
                    type:
                      type: string
                      enum: [form, table, action]
                    fields:
                      type: array
                      items:
                        type: object
                        required: [name, type, label]
                        properties:
                          name:
                            type: string
                          type:
                            type: string
                            enum: [text, number, select, date]
                          label:
                            type: string
                          required:
                            type: boolean
                          validation:
                            type: object
            example:
              data:
                type: "form"
                fields:
                  - name: "email"
                    type: "text"
                    label: "Email Address"
                    required: true
                    validation:
                      pattern: "^[^@]+@[^@]+\\.[^@]+$"
```

### Pattern 6: WebSocket Notification Message Format
**What:** JSON event-based convention for WebSocket messages
**When to use:** Real-time notifications that trigger REST API calls
**Example:**
```json
// Source: JSON event-based WebSocket convention
// Message format: [eventName, eventData]
["resource_updated", {
  "resource": "plugin",
  "id": "user-form-123",
  "action": "config_changed",
  "timestamp": "2026-01-22T10:30:00Z"
}]

// Client receives notification, then calls REST endpoint:
// GET /api/v1/plugins/user-form-123/config
```

### Anti-Patterns to Avoid

- **Generating specs after implementation:** Leads to incomplete, inaccurate specs. Design spec first, implement from spec.
- **Empty request/response bodies:** Every schema must document properties. Use examples liberally.
- **Mixing OpenAPI versions:** Choose one version (3.1.0) and stick to it. Don't mix 3.0 and 3.1 syntax.
- **Implicit type assumptions:** Always use `type` keyword explicitly in JSON Schema. Don't rely on implicit types.
- **Single error responses:** Return all validation errors together. Forcing users to fix one field at a time is poor UX.
- **Inconsistent naming conventions:** Pick one (camelCase) and apply it everywhere: schemas, properties, operationIds.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Error response format | Custom JSON structure | RFC 9457 Problem Details | Standardized, machine-readable, extensible, framework-agnostic |
| API validation | Custom validation logic | Spectral linter | 100+ built-in rules, custom rulesets, CI/CD integration |
| Mock server | Custom stub server | Scalar CLI or Prism | Auto-generates from spec, realistic data, request validation |
| Code generation | Custom parsers | OpenAPI Generator | 50+ languages, battle-tested, community maintained |
| Field naming conventions | Ad-hoc decisions | camelCase (JSON standard) | Code generator compatibility, JavaScript ecosystem convention |
| OpenAPI multi-file management | Manual file combining | $ref resolution | Native OpenAPI feature, tool support, DRY principle |

**Key insight:** The OpenAPI ecosystem is mature with production-grade tooling. Custom solutions create maintenance burden and incompatibility with standard tools.

## Common Pitfalls

### Pitfall 1: Code-First Spec Generation
**What goes wrong:** Generating OpenAPI specs from server code produces incomplete, inaccurate specifications that drift from actual API behavior. Generic types, nullable properties, and language idioms don't map cleanly to OpenAPI.
**Why it happens:** Teams want to avoid writing specs manually and hope code generation solves it.
**How to avoid:** Design OpenAPI specification first. Treat it as source code, commit to version control, validate in CI/CD. Use spec to generate server stubs and client SDKs.
**Warning signs:** Missing examples, empty request bodies, generic error responses, no field descriptions.

### Pitfall 2: Under-Utilizing Components
**What goes wrong:** Specifications become massive, repetitive, and hard to maintain. Changes require editing multiple locations. Inconsistencies creep in.
**Why it happens:** Developers write OpenAPI linearly without extracting reusable elements.
**How to avoid:** Move repeated schemas, responses, parameters to `components` section. Reference with `$ref`. Split large specs into multiple files organized by resource.
**Warning signs:** Copy-pasted schema definitions, file size exceeding 1000 lines, difficulty finding specific schemas.

### Pitfall 3: Inadequate Examples
**What goes wrong:** Documentation is hard to understand. Mock servers generate unrealistic data. Developers struggle to use the API correctly.
**Why it happens:** Examples treated as optional nice-to-have instead of critical documentation.
**How to avoid:** Every schema must have an `example` or `examples` field. Show realistic data including edge cases. Examples should demonstrate actual usage patterns.
**Warning signs:** Generic examples like `"string"` or `123`, missing examples on complex nested objects, mock servers returning meaningless data.

### Pitfall 4: Inconsistent Naming Conventions
**What goes wrong:** Schemas use PascalCase, properties use snake_case, operationIds use random styles. Code generators produce inconsistent client SDKs. API feels unprofessional.
**Why it happens:** Multiple contributors without style guide, mixing conventions from different languages.
**How to avoid:** Choose conventions early and document them. For JSON APIs: camelCase for properties, PascalCase for schema names, camelCase for operationIds. Enforce with Spectral linter rules.
**Warning signs:** Mix of camelCase and snake_case in same spec, code generators requiring manual fixes, inconsistent URLs.

### Pitfall 5: Versioning Confusion
**What goes wrong:** Breaking changes deployed without version bump. Multiple versions maintained without clear deprecation policy. Clients break unexpectedly.
**Why it happens:** No documented versioning strategy, treating version as afterthought.
**How to avoid:** Document versioning scheme upfront. Use URL path versioning (/api/v1/). Define what constitutes breaking change. For CallBackery Next: backend and frontend deploy together, so deprecation window not needed, but version for future flexibility.
**Warning signs:** No version in URL, undocumented breaking changes, client compatibility issues.

### Pitfall 6: Ignoring RFC 9457 for Errors
**What goes wrong:** Every error response has different structure. Clients can't handle errors generically. AI agents and tools can't parse errors reliably.
**Why it happens:** Each developer invents their own error format. Legacy formats carried forward.
**How to avoid:** Adopt RFC 9457 Problem Details from the start. Use `application/problem+json` media type. Extend with custom fields (like `errors` array for validation) but keep standard fields.
**Warning signs:** Inconsistent error responses, clients with complex error-handling logic, inability to use generic error handlers.

### Pitfall 7: WebSocket Message Structure Ambiguity
**What goes wrong:** WebSocket messages lack clear format. Clients don't know how to parse. Adding new event types breaks existing clients.
**Why it happens:** No formal specification, treating WebSocket as secondary concern.
**How to avoid:** Document WebSocket message format in specification. Use JSON event-based convention: `[eventName, eventData]`. Specify all event types and their data structures. WebSocket triggers REST calls, don't duplicate data.
**Warning signs:** WebSocket format documented only in code comments, clients parsing messages with brittle logic, difficulty adding new notification types.

## Code Examples

Verified patterns from official sources:

### OpenAPI 3.1 Root Document Structure
```yaml
# Source: OpenAPI 3.1.0 specification
openapi: 3.1.0
info:
  title: CallBackery Next API
  version: 1.0.0
  description: Backend-driven UI framework protocol
  contact:
    name: API Support
    url: https://github.com/callbackery/callbackery-next
  license:
    name: Artistic License 2.0
    identifier: Artistic-2.0

servers:
  - url: https://api.callbackery.com/api/v1
    description: Production server
  - url: http://localhost:3000/api/v1
    description: Local development

tags:
  - name: Plugins
    description: Backend plugin configuration
  - name: Navigation
    description: Application structure and navigation
  - name: Users
    description: User management and authentication

paths:
  /plugins:
    $ref: './paths/plugins.yaml'
  /navigation:
    $ref: './paths/navigation.yaml'

components:
  schemas:
    $ref: './components/schemas/_index.yaml'
  responses:
    $ref: './components/responses/_index.yaml'
  parameters:
    $ref: './components/parameters/_index.yaml'

# OpenAPI 3.1 specific: JSON Schema 2020-12 support
jsonSchemaDialect: https://spec.openapis.org/oas/3.1/dialect/base
```

### URL Path Versioning Implementation
```yaml
# Source: REST API versioning best practices
servers:
  - url: https://api.callbackery.com/api/v1
    description: Version 1 API
    variables: {}

# Alternative: Serve OpenAPI spec at versioned endpoint
paths:
  /openapi.json:
    get:
      summary: Get OpenAPI specification
      description: Self-hosted, always current specification
      responses:
        '200':
          description: OpenAPI 3.1 specification
          content:
            application/json:
              schema:
                type: object
```

### Reusable Component with $ref Pattern
```yaml
# Source: OpenAPI 3.1 best practices - DRY principle

# In components/schemas/User.yaml
User:
  type: object
  required: [id, email, name]
  properties:
    id:
      type: string
      format: uuid
      example: "550e8400-e29b-41d4-a716-446655440000"
    email:
      type: string
      format: email
      example: "user@example.com"
    name:
      type: string
      minLength: 1
      maxLength: 100
      example: "John Doe"
    createdAt:
      type: string
      format: date-time
      example: "2026-01-22T10:30:00Z"

# In paths/users.yaml - Reference the schema
paths:
  /users/{id}:
    get:
      summary: Get user by ID
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          content:
            application/json:
              schema:
                type: object
                required: [data]
                properties:
                  data:
                    $ref: '#/components/schemas/User'  # Reuse schema
```

### Spectral Linting Configuration
```yaml
# .spectral.yaml - Source: Spectral documentation
extends: [[spectral:oas, all]]

rules:
  # Enforce operation IDs in camelCase
  operation-operationId-valid-in-url:
    severity: error

  # Require examples on all schemas
  oas3-schema-examples:
    severity: warn

  # Enforce consistent tag usage
  openapi-tags:
    severity: error

  # Custom rule: Enforce response envelope
  response-envelope-required:
    description: All 2xx responses must use {data, meta} envelope
    given: $.paths..responses[?(@property.match(/^2/))]..schema
    severity: error
    then:
      - field: properties.data
        function: truthy
      - field: required
        function: schema
        functionOptions:
          schema:
            type: array
            contains:
              const: data
```

### Mock Server Usage
```bash
# Source: Scalar CLI documentation
# Generate mock server from OpenAPI spec
npx @scalar/cli mock openapi.yaml --port 3000

# Now frontend can develop against mock server:
# GET http://localhost:3000/api/v1/plugins
# Returns realistic data based on schema examples
```

### Validation in CI/CD Pipeline
```yaml
# .github/workflows/validate-spec.yml
# Source: Spectral CI/CD integration
name: Validate OpenAPI Spec

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Spectral
        run: npm install -g @stoplight/spectral-cli

      - name: Lint OpenAPI Spec
        run: spectral lint spec/openapi.yaml --ruleset .spectral.yaml

      - name: Validate JSON Schema
        run: |
          npx @hyperjump/json-schema validate \
            --schema https://spec.openapis.org/oas/3.1/schema \
            spec/openapi.yaml
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| OpenAPI 3.0 | OpenAPI 3.1 | Feb 2021 | JSON Schema 2020-12 alignment, better validation, `$schema` keyword support |
| Custom error formats | RFC 9457 Problem Details | 2023-2025 adoption | Standardized machine-readable errors, framework interoperability |
| Code-first API design | Spec-first API design | 2020-2025 shift | Better documentation, parallel development, contract-driven testing |
| JSON-RPC for config APIs | REST + WebSocket | 2022+ | Standard tooling, better caching, cleaner separation of concerns |
| Monolithic OpenAPI files | Multi-file with $ref | Always supported, more adoption 2023+ | Maintainability, reusability, team collaboration |
| OpenAPI 3.1 | OpenAPI 3.2 | Sept 2025 | Webhooks, streaming, multi-document support (optional upgrade) |

**Deprecated/outdated:**
- OpenAPI 2.0 (Swagger): Replaced by OpenAPI 3.x. Lacks JSON Schema alignment, weaker validation.
- RFC 7807 Problem Details: Superseded by RFC 9457 (same content, updated RFC).
- Header-based versioning: Fell out of favor vs URL path versioning for public APIs.
- Inline-only schemas: Modern practice uses components and $ref for maintainability.

**Current best practices (2026):**
- OpenAPI 3.1+ with spec-first development
- RFC 9457 for errors
- Spectral for validation
- Mock servers for parallel development
- URL path versioning for simplicity
- JSON Schema 2020-12 for rich validation
- camelCase for JSON properties

## Open Questions

Things that couldn't be fully resolved:

1. **OpenAPI 3.1 vs 3.2 for CallBackery Next**
   - What we know: 3.2 adds webhooks, streaming, multi-document support (released Sept 2025)
   - What's unclear: Tool maturity for 3.2 (only 4 months old), whether CallBackery needs webhooks/streaming features
   - Recommendation: Start with 3.1 (better tool support, proven). 3.1 meets all requirements. Consider 3.2 only if webhooks feature becomes critical later.

2. **Extent of WebSocket specification formalization**
   - What we know: JSON event-based convention `[eventName, eventData]` is common pattern
   - What's unclear: Whether WebSocket message format should be in OpenAPI spec itself, or separate document
   - Recommendation: Create separate WebSocket specification document (OpenAPI doesn't formally support WebSocket message schemas). Reference it from OpenAPI spec description. Document all event types and their data structures.

3. **Response envelope universality**
   - What we know: Envelope pattern `{data, meta}` decided for CallBackery. Industry debate on envelopes vs bare responses.
   - What's unclear: Whether error responses (Problem Details) should also use envelope or be bare
   - Recommendation: Use envelope for 2xx responses, bare RFC 9457 Problem Details for errors. Problem Details already has standard structure, wrapping would be redundant and non-standard.

4. **Plugin configuration endpoint versioning granularity**
   - What we know: URL versioning decided (/api/v1/). Plugins return UI configuration dynamically.
   - What's unclear: If plugin configuration format changes, does it require API version bump, or can plugins version internally?
   - Recommendation: Document in versioning scheme: API version covers protocol structure (endpoints, envelope format). Plugin-specific config schemas can evolve independently if properly validated. Breaking protocol changes require version bump.

## Sources

### Primary (HIGH confidence)
- [OpenAPI 3.1.0 Specification](https://spec.openapis.org/oas/v3.1.0) - Official specification
- [OpenAPI 3.2.0 Specification](https://spec.openapis.org/oas/v3.2.0) - Latest version (Sept 2025)
- [RFC 9457 Problem Details](https://www.rfc-editor.org/rfc/rfc9457.html) - Error response standard
- [OpenAPI Best Practices](https://learn.openapis.org/best-practices.html) - Official guidance
- [Spectral OpenAPI Linter](https://stoplight.io/open-source/spectral) - Official tool documentation
- [OpenAPI Generator](https://openapi-generator.tech/) - Official code generation tool

### Secondary (MEDIUM confidence)
- [I'd Rather Be Writing - API Documentation Course](https://idratherbewriting.com/learnapidoc/) - Comprehensive API docs guide (Jan 2026)
- [REST API Versioning Best Practices](https://daily.dev/blog/api-versioning-strategies-best-practices-guide) - Industry survey (2026)
- [WebSocket Communication Patterns](https://blog.bitsrc.io/websocket-communication-patterns-for-real-time-web-apps-526a3d4e8894) - Pattern catalog
- [Server-Driven UI Design Patterns](https://devcookies.medium.com/server-driven-ui-design-patterns-a-professional-guide-with-examples-a536c8f9965f) - SDUI implementation guide
- [JSON Schema 2020-12 and OpenAPI 3.1](https://apisyouwonthate.com/blog/openapi-v3-1-and-json-schema/) - Integration analysis
- [Field-Level Validation Best Practices](https://www.speakeasy.com/api-design/errors) - Error handling patterns
- [Scalar Mock Server Documentation](https://blog.scalar.com/p/how-to-set-up-an-openapi-mock-server) - Mock server setup

### Tertiary (LOW confidence - requires validation)
- WebSearch results on naming conventions - No single authoritative source, community consensus on camelCase for JSON
- WebSearch results on envelope patterns - Ongoing debate, CallBackery decision already made
- Medium articles on API design - Useful patterns but not standards bodies

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - OpenAPI 3.1, Spectral, OpenAPI Generator are industry standards with official documentation
- Architecture patterns: HIGH - REST resource design, RFC 9457, response envelopes verified against official sources
- Pitfalls: HIGH - Common mistakes documented in multiple authoritative sources (OpenAPI Initiative, liblab, API experts)
- WebSocket specification: MEDIUM - Patterns are well-established but OpenAPI doesn't formally define WebSocket messages
- Naming conventions: MEDIUM - Community consensus on camelCase but not RFC-level standard

**Research date:** 2026-01-22
**Valid until:** 60 days (OpenAPI ecosystem is stable, tools mature, standards frozen)

**Research scope adhered to CONTEXT.md decisions:**
- Researched resource-centric REST organization (locked decision)
- Researched standard response envelope pattern (locked decision)
- Researched semantic error codes with field-level validation (locked decision)
- Researched URL path versioning /api/v1/ (locked decision)
- Researched conceptual documentation for backend developers (locked decision)
- Exercised discretion on: field naming (camelCase), OpenAPI component organization ($ref patterns), WebSocket message structure (JSON array convention), documentation file organization (conceptual sections)

**Key findings for planner:**
- Spec-first development is proven methodology with mature tooling
- Mock servers enable parallel frontend/backend development
- Spectral validation should run in CI/CD pipeline
- RFC 9457 Problem Details is the standard for errors (not custom format)
- JSON event-based WebSocket convention `[eventName, eventData]` is established pattern
- OpenAPI 3.1 meets all requirements (3.2 is optional future upgrade)
- Conceptual documentation should focus on mental model, not implementation
