# Pitfalls Research: Backend-Driven UI Framework

**Domain:** Backend-driven UI frameworks (server-configures-client pattern)
**Researched:** 2026-01-22
**Confidence:** HIGH (based on CallBackery codebase analysis and domain expertise)

## Executive Summary

Backend-driven UI frameworks face unique challenges because they split responsibilities between protocol design, frontend interpretation, and backend configuration. The most critical pitfalls fall into four categories: protocol evolution (changes break clients), state synchronization (frontend/backend drift), type safety gaps (unvalidated contracts), and progressive complexity (features added without coherent design). CallBackery's 10+ year evolution demonstrates all these patterns.

**Critical insight:** The protocol IS the product. Unlike traditional applications where frontend and backend evolve together, backend-driven frameworks must treat the protocol as a formal contract that outlives any single implementation.

---

## Protocol Design Pitfalls

### Pitfall 1: Implicit Protocol Assumptions

**What goes wrong:**
- Protocol behavior relies on undocumented conventions (field ordering, default values, client-side interpretation rules)
- Backend changes break frontend in subtle ways because assumptions weren't explicit
- Different backend implementations diverge because "correct" behavior isn't specified

**CallBackery evidence:**
- JSON-RPC payload structure not formally documented
- Frontend assumes `exc.code === 6` means "auth required", `exc.code === 7` means "session expired"
- No specification of what `screenCfg` structure should contain for each plugin type
- `instantiationMode` defaults to `onTabSelection` but nothing documents when frontend should instantiate

**Warning signs:**
- Comments like "this just works" without explaining why
- Frontend code checking for specific error codes or field presence without specification
- Backend returning data structures that frontend "just knows" how to interpret

**Prevention strategy:**
1. **OpenAPI specification FIRST** - Write spec before implementation
2. **Document semantics, not just syntax** - Explain what `instantiationMode: "onStartup"` means for client behavior
3. **Formalize error codes** - Define error code enum with exact meanings
4. **Version protocol from day one** - Include API version in all requests/responses

**Phase relevance:**
- Phase 1 (OpenAPI spec): Define complete contract including error codes, plugin config schemas
- Phase 2 (Rust backend): Implementation must match spec exactly, no undocumented behavior
- Phase 3 (Svelte frontend): Client depends ONLY on spec, not implementation details

**Validation checklist:**
- [ ] Every response field documented in OpenAPI with description of semantics
- [ ] Error code enum defined with exact meaning (not just numbers)
- [ ] Protocol behavior testable without looking at implementation code
- [ ] Two independent implementations can interoperate using spec alone

---

### Pitfall 2: Protocol Versioning Afterthought

**What goes wrong:**
- No version negotiation mechanism means breaking changes require "flag day" upgrades
- Can't evolve protocol without breaking old clients
- Backward compatibility becomes increasingly painful

**CallBackery evidence:**
- No protocol version field in requests/responses
- Moving from JSON-RPC to REST would require complete rewrite with no migration path
- Frontend tightly coupled to specific backend version

**Warning signs:**
- "We'll just update frontend and backend together"
- No API version in URL or headers
- Feature additions change existing endpoints rather than adding new ones

**Prevention strategy:**
1. **Version in URL path** - `/v1/plugins/{id}/config` not `/plugins/{id}/config`
2. **Version negotiation** - Client sends supported versions, server responds with chosen version
3. **Compatibility policy** - Define how long versions are supported (e.g., N-1 versions)
4. **Deprecation process** - Mark endpoints/fields deprecated before removal

**Phase relevance:**
- Phase 1 (OpenAPI spec): Version strategy defined upfront (`/v1/` paths)
- All phases: Version appears in all URLs, responses include version header
- Future: v2 can coexist with v1 during migration period

**Implementation pattern:**
```yaml
# OpenAPI spec
paths:
  /v1/plugins/{id}/config:
    get:
      summary: Get plugin configuration
      responses:
        200:
          headers:
            X-API-Version:
              schema:
                type: string
                example: "1.0.0"
```

---

### Pitfall 3: State Synchronization via Polling

**What goes wrong:**
- Frontend polls backend for state changes, wasting bandwidth and increasing latency
- Real-time updates delayed by poll interval
- Backend can't proactively notify frontend of changes

**CallBackery evidence:**
- No push mechanism for table refreshes or form updates
- Frontend must poll to detect backend state changes
- No way for backend to notify "data changed, please refresh"

**Warning signs:**
- `setInterval()` calls to check for updates
- "Check every N seconds" in feature descriptions
- Users complain about stale data despite recent changes

**Prevention strategy:**
1. **WebSocket for notifications** - Backend pushes "resource changed" events
2. **Event-driven architecture** - Backend emits events, frontend subscribes
3. **Optimistic updates** - Frontend updates immediately, backend confirms
4. **ETags/version stamps** - Detect conflicts without polling

**Phase relevance:**
- Phase 1 (WebSocket spec): Define notification schema (resource type, ID, change type)
- Phase 2 (Rust backend): Emit notifications when data mutates
- Phase 3 (Svelte frontend): Subscribe to notifications, trigger REST refetch

**WebSocket notification schema:**
```json
{
  "type": "resource.updated",
  "resource": "table",
  "id": "users_table",
  "timestamp": "2026-01-22T10:30:00Z"
}
```

**Frontend pattern:**
```javascript
// Frontend receives notification, refetches via REST
ws.on('resource.updated', (event) => {
  if (event.id === currentTableId) {
    fetch(`/v1/plugins/${event.id}/data`).then(refresh);
  }
});
```

---

### Pitfall 4: No Formal Schema Validation

**What goes wrong:**
- Backend sends malformed data, frontend crashes
- Type mismatches caught at runtime, not design time
- No single source of truth for what valid data looks like

**CallBackery evidence:**
- Config::Grammar validates backend config but no JSON schema for RPC payloads
- Frontend assumes field types without validation
- `screenCfg` structure varies by plugin type but no schema enforces consistency

**Warning signs:**
- Runtime errors like "cannot read property X of undefined"
- Defensive code with `if (data && data.field && data.field.subfield)`
- Different plugins returning different shapes for same concept

**Prevention strategy:**
1. **JSON Schema for all payloads** - Define schemas in OpenAPI spec
2. **Backend validates outgoing data** - Catch malformed responses before sending
3. **Frontend validates incoming data** - Fail fast with clear error
4. **Code generation** - Generate TypeScript types from schemas

**Phase relevance:**
- Phase 1 (OpenAPI spec): JSON schemas for all request/response bodies
- Phase 2 (Rust backend): Use serde with strict deserialization, validate before sending
- Phase 3 (Svelte frontend): Generate TS types from OpenAPI, validate with Zod/AJV

**Schema example:**
```yaml
# OpenAPI schema for plugin config
components:
  schemas:
    PluginConfig:
      type: object
      required: [type, title, instantiationMode]
      properties:
        type:
          type: string
          enum: [form, table, action, html]
        title:
          type: string
        instantiationMode:
          type: string
          enum: [onStartup, onTabSelection]
      additionalProperties: false
```

---

### Pitfall 5: Generic Plugin Protocol Instead of Typed Variants

**What goes wrong:**
- Single `getPluginConfig` endpoint returns different structures for forms vs tables
- Frontend must introspect response to determine type
- Shared fields have different semantics in different contexts

**CallBackery evidence:**
- `AbstractForm`, `AbstractTable`, `AbstractCardlist` all return `screenCfg` but with different schemas
- Frontend checks plugin type then casts data to appropriate shape
- Validation rules differ by type but enforcement is ad-hoc

**Warning signs:**
- Discriminated unions in responses (`{type: "form", ...formFields}` vs `{type: "table", ...tableFields}`)
- Frontend switch statements on plugin type
- Shared field names mean different things (e.g., `columns` in table vs form)

**Prevention strategy:**
1. **Separate endpoints per type** - `/plugins/forms/{id}/config` vs `/plugins/tables/{id}/config`
2. **Type-specific schemas** - Each endpoint has its own schema
3. **No discriminated unions at protocol level** - Type determined by URL path
4. **Stronger guarantees** - URL guarantees shape of response

**Phase relevance:**
- Phase 1 (OpenAPI spec): Define `/v1/forms/{id}`, `/v1/tables/{id}` as separate resources
- Phase 2 (Rust backend): Separate handlers return type-specific structs
- Phase 3 (Svelte frontend): Import type-specific components (`FormView`, `TableView`)

**Better protocol design:**
```yaml
# Type-specific endpoints
paths:
  /v1/forms/{id}/config:
    get:
      responses:
        200:
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/FormConfig'

  /v1/tables/{id}/config:
    get:
      responses:
        200:
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TableConfig'
```

---

## Frontend Pitfalls

### Pitfall 6: Client-Side Logic Drift

**What goes wrong:**
- Frontend accumulates business logic that should be on backend
- Same validation/calculation logic duplicated in frontend and backend
- Frontend becomes "smart" making backend changes break assumptions

**CallBackery evidence:**
- Form validation exists on both frontend (immediate feedback) and backend (authoritative)
- Table sorting/filtering can happen client-side or server-side
- No clear boundary of what frontend may assume

**Warning signs:**
- "We also need to update the frontend validation"
- Conditional logic based on data values (not just UI state)
- Frontend constructing complex queries or filters

**Prevention strategy:**
1. **Dumb frontend principle** - Frontend renders, backend decides
2. **Backend validation is authoritative** - Frontend validation is UX hint only
3. **Explicit frontend capabilities** - Backend declares what frontend may do (sort, filter, paginate)
4. **Stateless frontend** - All state reconstructible from backend responses

**Phase relevance:**
- Phase 1 (OpenAPI spec): Define what backend provides (e.g., `sortable: true` means backend sorts)
- Phase 3 (Svelte frontend): Implement presentation logic only, no business rules
- Phase 4 (Forms): Frontend validates for UX, always defers to backend response

**Anti-pattern:**
```javascript
// BAD: Frontend decides if user can edit
if (user.role === 'admin' || record.createdBy === user.id) {
  showEditButton();
}

// GOOD: Backend declares capabilities
if (record.actions.includes('edit')) {
  showEditButton();
}
```

---

### Pitfall 7: Optimistic Updates Without Rollback

**What goes wrong:**
- Frontend updates UI immediately assuming backend will succeed
- Backend rejects request but frontend already updated
- Inconsistent state when offline or network errors

**CallBackery evidence:**
- Not present in CallBackery (synchronous RPC) but would be needed for modern UX
- Moving to REST makes this a concern

**Warning signs:**
- UI updates before API call completes
- No error handling for failed updates
- Stale data displayed after network partition

**Prevention strategy:**
1. **Explicit optimistic update policy** - Document which operations are optimistic
2. **Version stamps** - Backend returns version, frontend includes in updates
3. **Rollback mechanism** - On error, revert to last known good state
4. **Conflict resolution** - Define how to handle "update based on stale data"

**Phase relevance:**
- Phase 1 (OpenAPI spec): Define version/ETag semantics
- Phase 3 (Svelte frontend): Implement optimistic update with rollback
- Phase 4 (Forms): Form submission optimistically shows success, reverts on error

**Pattern:**
```javascript
// Svelte store pattern
async function updateRecord(id, changes) {
  const snapshot = { ...currentRecord };

  // Optimistic update
  currentRecord = { ...currentRecord, ...changes };

  try {
    const response = await api.update(id, changes, { version: snapshot.version });
    currentRecord = response.data; // Backend wins
  } catch (error) {
    currentRecord = snapshot; // Rollback
    if (error.code === 'conflict') {
      showConflictDialog(snapshot, error.current);
    }
  }
}
```

---

### Pitfall 8: Navigation State Not in Protocol

**What goes wrong:**
- Frontend manages tab state, deep linking breaks
- Refreshing page loses context (which tab, which form)
- No way to bookmark or share specific views

**CallBackery evidence:**
- Qooxdoo manages tab state client-side
- No URL routing for different plugin views
- Refresh resets to initial state

**Warning signs:**
- "You can't refresh the page or you'll lose your work"
- No URL changes when navigating between views
- Can't share direct links to specific forms/tables

**Prevention strategy:**
1. **URL-driven navigation** - Every view has a URL
2. **Backend-provided navigation** - Backend declares available tabs/views
3. **Deep link support** - `/app/tables/users` directly loads users table
4. **Hierarchical URLs** - `/forms/user-edit/123` identifies form and record

**Phase relevance:**
- Phase 1 (OpenAPI spec): Define navigation structure (tabs, hierarchy)
- Phase 3 (Svelte frontend): SvelteKit routing maps URLs to plugin views
- Phase 5 (Navigation): Each plugin type gets URL pattern

**Pattern:**
```javascript
// SvelteKit route structure
// src/routes/tables/[id]/+page.svelte
export async function load({ params, fetch }) {
  const config = await fetch(`/v1/tables/${params.id}/config`);
  const data = await fetch(`/v1/tables/${params.id}/data`);
  return { config, data };
}
```

---

### Pitfall 9: Tight Coupling to UI Framework

**What goes wrong:**
- Backend assumes specific UI framework capabilities
- Migrating frontend requires backend changes
- Mobile/alternative clients can't work with protocol

**CallBackery evidence:**
- Backend returns Qooxdoo-specific widget configurations
- `screenCfg` structure mirrors Qooxdoo component hierarchy
- Replacing Qooxdoo requires protocol changes

**Warning signs:**
- Protocol mentions framework names ("qooxdoo", "react")
- Response includes framework-specific config (e.g., Qooxdoo theme settings)
- No abstraction layer between protocol and framework

**Prevention strategy:**
1. **Framework-agnostic protocol** - Describe UI semantically, not structurally
2. **Capability negotiation** - Client declares what it can render
3. **Backend describes intent** - "Display as table" not "Use QxTable component"
4. **Multiple client support** - Web, mobile, CLI should all work

**Phase relevance:**
- Phase 1 (OpenAPI spec): Protocol describes data + semantics, not widgets
- Phase 3 (Svelte frontend): Map semantic descriptions to Flowbite components
- Future: React/Vue clients could use same protocol

**Anti-pattern:**
```json
// BAD: Framework-specific
{
  "widget": "qx.ui.form.TextField",
  "properties": { "qxTheme": "modern" }
}

// GOOD: Semantic
{
  "type": "text_field",
  "validation": { "pattern": "^[a-z]+$" },
  "hint": "Lowercase letters only"
}
```

---

## Backend Pitfalls

### Pitfall 10: Plugin Configuration Changes Break Protocol

**What goes wrong:**
- Adding fields to plugin config requires frontend update
- Removing fields breaks old clients
- No way to know what config versions are compatible

**CallBackery evidence:**
- Plugin `grammar()` defines config structure but no versioning
- Adding new plugin type requires frontend changes
- Config changes are breaking changes

**Warning signs:**
- "Frontend needs to support new field before we can deploy backend"
- Different plugins have incompatible config formats
- No config schema version in responses

**Prevention strategy:**
1. **Config schema versioning** - Each plugin declares schema version
2. **Forward compatibility** - Old clients ignore unknown fields
3. **Backward compatibility** - New backends support old config versions
4. **Deprecation warnings** - Backend warns about deprecated config usage

**Phase relevance:**
- Phase 1 (OpenAPI spec): Config schemas include version field
- Phase 2 (Rust backend): Validate config against version-specific schema
- Phase 3 (Svelte frontend): Ignore unknown fields, log warnings

**Pattern:**
```json
// Config with version
{
  "schemaVersion": "1.0",
  "type": "form",
  "fields": [...]
}
```

---

### Pitfall 11: Authorization Mixed with Configuration

**What goes wrong:**
- Backend returns different configs based on user permissions
- Frontend can't know what's possible without trying
- Caching breaks because configs vary by user

**CallBackery evidence:**
- `may()` method filters data based on user permissions
- Plugin config changes based on authentication state
- Frontend must fetch config for each user

**Warning signs:**
- Same endpoint returns different data for different users
- Config not cacheable because it's user-specific
- Authorization logic in config generation code

**Prevention strategy:**
1. **Separate capabilities from config** - Config describes what exists, capabilities describe what user can do
2. **Consistent config** - All users see same config structure
3. **Action-level permissions** - Config includes all actions, backend filters allowed ones
4. **Frontend capability queries** - Separate endpoint for "can I do X?"

**Phase relevance:**
- Phase 1 (OpenAPI spec): Config is static, capabilities are dynamic
- Phase 2 (Rust backend): Config route cacheable, capabilities route checks auth
- Phase 6 (Authentication): Permission model separates "exists" from "allowed"

**Pattern:**
```json
// Config (same for all users)
{
  "actions": ["create", "edit", "delete"]
}

// Capabilities (user-specific)
{
  "allowed": ["create", "edit"]
}
```

---

### Pitfall 12: Database Schema as Protocol

**What goes wrong:**
- Backend exposes database fields directly in API
- Database changes require API version bump
- Internal refactoring becomes breaking change

**CallBackery evidence:**
- Table plugins expose database columns directly
- Field names match database column names
- Changing schema requires config updates

**Warning signs:**
- API fields named `cbuser_id`, `cb_` prefix
- One-to-one mapping between DB columns and API fields
- "We can't rename this database column because clients depend on it"

**Prevention strategy:**
1. **API models != database models** - Explicit mapping layer
2. **Semantic field names** - API uses business names, DB uses technical names
3. **Versioned transformations** - Same DB can support multiple API versions
4. **Backend abstraction** - Plugins work with domain objects, not DB rows

**Phase relevance:**
- Phase 2 (Rust backend): Domain model layer between DB and API
- Phase 4 (Tables/Forms): API returns business objects, not raw DB rows

**Pattern:**
```rust
// DB model
struct DbUser {
    cbuser_id: i64,
    cbuser_login: String,
}

// API model
struct ApiUser {
    id: String,
    username: String,
}

// Mapping
impl From<DbUser> for ApiUser {
    fn from(db: DbUser) -> Self {
        ApiUser {
            id: db.cbuser_id.to_string(),
            username: db.cbuser_login,
        }
    }
}
```

---

### Pitfall 13: Synchronous Plugin Instantiation

**What goes wrong:**
- Loading plugin config blocks request handling
- Slow plugin initialization delays all requests
- No concurrent plugin loading

**CallBackery evidence:**
- `instantiatePlugin` is synchronous (pre-async version)
- Later added `instantiatePlugin_p` async version
- Plugin loading can block RPC calls

**Warning signs:**
- Slow first-load performance
- Request timeouts during initialization
- Backend thread blocked on plugin loading

**Prevention strategy:**
1. **Async everywhere** - All I/O operations async from day one
2. **Lazy loading** - Only load plugins when accessed
3. **Concurrent initialization** - Load multiple plugins in parallel
4. **Caching** - Cache loaded plugin configs

**Phase relevance:**
- Phase 2 (Rust backend): Use async/await from start, tokio runtime
- All endpoints: Non-blocking I/O for all database and plugin operations

**Pattern:**
```rust
// Rust async plugin loading
async fn get_plugin_config(id: &str) -> Result<PluginConfig> {
    // Concurrent DB query + file load
    let (db_config, file_config) = tokio::join!(
        db.get_config(id),
        load_config_file(id)
    );

    merge_configs(db_config?, file_config?)
}
```

---

## Cross-Cutting Pitfalls

### Pitfall 14: No Formal Testing Strategy

**What goes wrong:**
- Protocol changes break clients in production
- No contract tests between frontend and backend
- Integration issues discovered after deployment

**CallBackery evidence:**
- Only 2 test files: `basic.t`, `invalidPlugin.t`
- No frontend/backend integration tests
- No OpenAPI spec validation

**Warning signs:**
- "Works on my machine"
- Manual testing before each release
- Bugs discovered by users, not tests

**Prevention strategy:**
1. **Contract testing** - Frontend tests against OpenAPI spec
2. **Backend spec compliance** - Backend validates responses against spec
3. **Integration tests** - Real frontend + backend tests
4. **Property-based testing** - Generate test cases from schemas

**Phase relevance:**
- Phase 1 (OpenAPI spec): Spec serves as test oracle
- Phase 2 (Rust backend): Use openapi-validator to ensure compliance
- Phase 3 (Svelte frontend): Use openapi-typescript for type safety
- All phases: Integration tests with real HTTP calls

**Tools:**
- Backend: `utoipa` crate generates OpenAPI from Rust code
- Frontend: `openapi-typescript-codegen` generates client
- Validation: `openapi-validator` ensures responses match spec
- Testing: Playwright E2E tests

---

### Pitfall 15: Progressive Feature Bloat

**What goes wrong:**
- Each new feature adds complexity without refactoring
- Plugin base classes become monolithic
- No coherent mental model

**CallBackery evidence:**
- `Abstract.pm` is 722 lines (from CONCERNS.md)
- `AbstractForm.pm` adds 337 more lines
- Features added incrementally without redesign

**Warning signs:**
- Base classes keep growing
- "Just add one more method" mentality
- Different features using different patterns

**Prevention strategy:**
1. **Composition over inheritance** - Small focused traits/mixins
2. **Feature flags** - Explicitly enable capabilities
3. **Periodic refactoring** - Scheduled cleanup sprints
4. **Coherent phases** - Each phase has clear scope

**Phase relevance:**
- All phases: Keep abstractions small and focused
- Review cycle: After each phase, evaluate if refactoring needed

**Pattern:**
```rust
// Instead of giant base class, use traits
trait Renderable {
    fn render(&self) -> Html;
}

trait Validatable {
    fn validate(&self, data: &FormData) -> Result<()>;
}

trait Authorizable {
    fn check_permission(&self, user: &User) -> bool;
}

// Plugins compose behaviors
struct FormPlugin {
    renderer: Box<dyn Renderable>,
    validator: Box<dyn Validatable>,
    authz: Box<dyn Authorizable>,
}
```

---

## Lessons from CallBackery

### What CallBackery Got Right

1. **Backend-configures-frontend pattern** - Core concept is sound
2. **Plugin architecture** - Extensibility without framework changes
3. **User/session management** - Authentication integrated from start
4. **Config-driven UI** - Backend declares what frontend renders

### What to Do Differently

1. **Formal specification first** - OpenAPI before implementation
   - CallBackery: Implicit protocol evolved organically
   - Do instead: Write spec, validate all implementations against it

2. **Protocol versioning from day one** - `/v1/` URLs, version negotiation
   - CallBackery: No versioning, can't evolve without breaking
   - Do instead: Version in URL, support N-1 versions

3. **Type-specific endpoints** - Separate routes for forms/tables/actions
   - CallBackery: Generic `getPluginConfig` with discriminated unions
   - Do instead: `/v1/forms/{id}`, `/v1/tables/{id}` with type-specific schemas

4. **WebSocket for push** - Backend notifies frontend of changes
   - CallBackery: Polling or page refresh only
   - Do instead: WebSocket events trigger REST refetch

5. **Separation of concerns** - Config != capabilities != data
   - CallBackery: Mixed authorization into config generation
   - Do instead: Static config, dynamic capabilities, separate data endpoints

6. **Framework-agnostic protocol** - Semantic descriptions, not widget specs
   - CallBackery: Qooxdoo-specific config structures
   - Do instead: "text field with pattern validation" not "QxTextField"

7. **Domain models != database models** - Abstraction layer
   - CallBackery: Direct DB field exposure in API
   - Do instead: Map DB schema to semantic API models

8. **Async from start** - Non-blocking I/O throughout
   - CallBackery: Later added async as retrofit
   - Do instead: tokio/async-await from first line of code

9. **Comprehensive testing** - Contract tests, integration tests
   - CallBackery: Minimal test coverage
   - Do instead: OpenAPI-driven contract tests, E2E with Playwright

10. **Documentation as code** - Spec is documentation
    - CallBackery: Documentation degraded over time
    - Do instead: OpenAPI spec + generated docs + conceptual guides

---

## Critical Success Factors

### 1. Protocol is the Product

**What this means:**
The OpenAPI specification is more important than any implementation. Treat it as the source of truth that both frontend and backend must satisfy.

**How to achieve:**
- Write spec before code
- Validate all implementations against spec
- Version spec, not just implementations
- Breaking changes require new version

**Validation:**
- Both Rust backend and any future backend can be validated against spec
- Frontend types generated from spec
- Integration tests use spec as oracle

---

### 2. Clear Separation of Concerns

**Concerns that must be separate:**

| Concern | Responsibility | Endpoint Pattern |
|---------|---------------|------------------|
| Configuration | What UI elements exist | `GET /v1/forms/{id}/config` |
| Capabilities | What user can do | `GET /v1/forms/{id}/capabilities` |
| Data | Actual records | `GET /v1/forms/{id}/data` |
| Validation | Business rules | `POST /v1/forms/{id}/validate` |
| Mutation | State changes | `POST /v1/forms/{id}/submit` |

**Anti-pattern:**
Single endpoint that mixes all concerns based on user/state.

---

### 3. Stateless Frontend Architecture

**Frontend should:**
- Render based on backend responses
- Manage only UI state (dropdown open, modal visible)
- Validate for UX only, never trust client validation
- Reconstruct all state from URL + API

**Frontend should NOT:**
- Make authorization decisions
- Store business logic
- Calculate derived values
- Cache data without invalidation strategy

---

### 4. Backward and Forward Compatibility

**Backward compatibility (old clients with new backend):**
- Don't remove fields, deprecate them
- Don't change field semantics
- Don't require new required fields
- Version major changes

**Forward compatibility (new clients with old backend):**
- Ignore unknown fields
- Graceful degradation of new features
- Detect backend version and adapt

**Testing:**
- Run old frontend against new backend in CI
- Run new frontend against old backend in CI

---

### 5. Observable and Debuggable

**Logging:**
- All RPC calls logged with user context
- Errors include correlation IDs
- Backend logs decision rationale (why auth failed, why validation rejected)

**Debugging:**
- Response includes debug info in development
- OpenAPI schema errors are specific ("field X violates constraint Y")
- WebSocket events include causality (what triggered this notification)

**Monitoring:**
- Protocol version usage metrics
- Error rates by endpoint and error code
- Performance metrics per plugin type

---

## Phase-Specific Warnings

| Phase | Primary Pitfall Risk | Mitigation |
|-------|---------------------|------------|
| Phase 1: OpenAPI Spec | Implicit assumptions (#1), No versioning (#2) | External review, Validate examples, Version from start |
| Phase 2: Rust Backend | Database as protocol (#12), Sync operations (#13) | Domain model layer, async/await everywhere |
| Phase 3: Svelte Frontend | Client logic drift (#6), Framework coupling (#9) | Dumb frontend principle, semantic protocol |
| Phase 4: Tables | Generic protocol (#5), Auth mixing (#11) | Type-specific endpoints, separate capabilities |
| Phase 5: Forms | Optimistic updates (#7), No validation (#4) | Rollback on error, JSON schema validation |
| Phase 6: Navigation | State not in protocol (#8) | URL-driven, deep links |
| Phase 7: Hierarchies | Complex state sync | WebSocket notifications (#3) |
| Phase 8: Auth | Permission complexity | Capabilities separate from config (#11) |

---

## Research Confidence

| Area | Confidence | Source |
|------|-----------|--------|
| Protocol pitfalls | HIGH | CallBackery codebase analysis |
| Frontend patterns | HIGH | CallBackery Qooxdoo implementation |
| Backend design | HIGH | CallBackery Perl/Mojolicious analysis |
| Testing gaps | HIGH | Direct observation of test directory |
| CallBackery mistakes | HIGH | CONCERNS.md + direct code review |

---

## Sources

**Primary sources (HIGH confidence):**
- `/home/oetiker/checkouts/callbackery/.planning/codebase/CONCERNS.md` - Security and architecture issues
- `/home/oetiker/checkouts/callbackery/.planning/codebase/ARCHITECTURE.md` - System design patterns
- `/home/oetiker/checkouts/callbackery/lib/CallBackery/GuiPlugin/Abstract.pm` - Plugin protocol implementation
- `/home/oetiker/checkouts/callbackery/lib/CallBackery/Controller/RpcService.pm` - RPC protocol handling
- `/home/oetiker/checkouts/callbackery/lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/data/Server.js` - Frontend protocol consumption

**Analysis method:**
Direct code review of 10+ year old production system revealing evolution of backend-driven UI pattern and accumulated technical debt from undocumented protocol.

---

*Pitfalls research completed: 2026-01-22*
