# Architecture Research

**Domain:** Backend-Driven UI Framework
**Researched:** 2026-01-22
**Overall Confidence:** MEDIUM (training data + CallBackery reference architecture)

## Executive Summary

A backend-driven UI framework requires clear boundaries between configuration (how UI is structured), data (what gets displayed), and operations (what users can do). The architecture must support:

1. **Lazy loading**: Frontend requests plugin configurations on-demand
2. **Dynamic rendering**: Frontend builds UI from backend-provided schemas
3. **Stateless protocol**: Backend doesn't track UI state, only business state
4. **Plugin isolation**: Each plugin is independently configurable and testable

Based on CallBackery's proven patterns and modern best practices, the recommended architecture uses:
- **REST API** for configuration and data (GET for read, POST for operations)
- **WebSocket** for server-initiated notifications (triggers frontend to refresh)
- **OpenAPI 3.1** for protocol specification
- **Plugin registry pattern** for extensibility

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Browser / Frontend                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Svelte 5 Application                       │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │   │
│  │  │Navigation│  │  Table   │  │   Form   │          │   │
│  │  │Component │  │Component │  │Component │          │   │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘          │   │
│  │       │             │              │                 │   │
│  │       └─────────────┴──────────────┘                 │   │
│  │                     │                                 │   │
│  │              ┌──────▼──────┐                         │   │
│  │              │Protocol     │                         │   │
│  │              │Client Layer │                         │   │
│  │              │(REST+WS)    │                         │   │
│  │              └──────┬──────┘                         │   │
│  └─────────────────────┼──────────────────────────────┘   │
└────────────────────────┼──────────────────────────────────┘
                         │ HTTP/WS
                         │
┌────────────────────────▼──────────────────────────────────┐
│                  Rust/Axum Backend                         │
│  ┌─────────────────────────────────────────────────────┐  │
│  │               REST API Layer                         │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐          │  │
│  │  │  /api/   │  │  /api/   │  │  /api/   │          │  │
│  │  │navigation│  │  plugins │  │   auth   │          │  │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘          │  │
│  └───────┼─────────────┼─────────────┼────────────────┘  │
│          │             │             │                    │
│  ┌───────▼─────────────▼─────────────▼────────────────┐  │
│  │         Plugin Registry & Manager                   │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐         │  │
│  │  │TablePlugin│  │FormPlugin│  │ActionPlugin│        │  │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘         │  │
│  └───────┼─────────────┼─────────────┼────────────────┘  │
│          │             │             │                    │
│  ┌───────▼─────────────▼─────────────▼────────────────┐  │
│  │          Data Layer (Database)                      │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │    WebSocket Server (Notifications)                  │  │
│  └─────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

## Frontend Architecture

### Component Structure

**Hierarchy:**
```
App.svelte (root)
├── AuthProvider (manages login state)
├── WebSocketClient (handles notifications)
└── RouterOutlet
    ├── Navigation (sidebar/tabs)
    └── PluginContainer
        ├── TableComponent (for table plugins)
        ├── FormComponent (for form plugins)
        └── HtmlComponent (for HTML display plugins)
```

**Component Responsibilities:**

| Component | Responsibility | State |
|-----------|---------------|-------|
| App.svelte | Bootstrap, routing, auth orchestration | User session, WS connection |
| Navigation | Display tabs/menu from backend config | Current tab selection |
| PluginContainer | Load plugin config, render appropriate component | Active plugin ID |
| TableComponent | Render table from schema, handle pagination/sort | Table state (page, sort) |
| FormComponent | Render form from schema, handle validation | Form data, validation errors |
| HtmlComponent | Render backend-provided HTML | None (pure display) |

**Key Pattern: Configuration-Driven Rendering**

Components don't know about business domains. They receive schemas and render accordingly.

```typescript
// Example: TableComponent receives this from backend
interface TableConfig {
  columns: Array<{
    key: string;
    label: string;
    type: 'string' | 'number' | 'date';
    sortable: boolean;
  }>;
  actions?: Array<{
    label: string;
    endpoint: string;
  }>;
}
```

### State Management

**Svelte 5 Runes + Stores Pattern:**

```typescript
// Global state (authentication, config)
// Using Svelte stores
export const sessionStore = writable<Session | null>(null);
export const navigationStore = writable<NavigationConfig | null>(null);

// Component-local state
// Using Svelte 5 runes ($state, $derived)
let formData = $state({});
let validationErrors = $derived.by(() => validate(formData));
```

**State Ownership:**
- **Backend owns**: Business logic, validation rules, available operations
- **Frontend owns**: UI state (which tab, current page, form input)
- **Shared state**: Session/auth (backend source of truth, frontend caches)

### Protocol Client

**REST Client Pattern:**

```typescript
class ProtocolClient {
  // Configuration loading (lazy)
  async getPluginConfig(pluginId: string): Promise<PluginConfig>

  // Data fetching
  async getTableData(pluginId: string, params: TableParams): Promise<TableData>
  async getFormData(pluginId: string, recordId?: string): Promise<FormData>

  // Operations
  async submitForm(pluginId: string, data: FormData): Promise<Result>
  async executeAction(pluginId: string, actionId: string, params: any): Promise<Result>

  // Authentication
  async login(username: string, password: string): Promise<Session>
  async logout(): Promise<void>
}
```

**WebSocket Client Pattern:**

```typescript
class NotificationClient {
  // Subscribe to updates
  connect(sessionToken: string): WebSocket

  // Handle notifications
  onNotification(handler: (event: NotificationEvent) => void)
}

// Notification types trigger REST calls
interface NotificationEvent {
  type: 'plugin_update' | 'data_changed' | 'session_expired';
  pluginId?: string;
  // No data payload — frontend fetches fresh data via REST
}
```

**Key Insight from CallBackery:**
WebSocket doesn't deliver data, it's a "poke" mechanism. When backend notifies "table X changed", frontend refetches table data via REST. This keeps the protocol simple and avoids data consistency issues.

## Backend Architecture

### API Layer

**REST Endpoint Structure:**

```
/api/
├── auth/
│   ├── POST /login
│   ├── POST /logout
│   └── GET /session
├── navigation/
│   └── GET /config              # Returns tab list, menu structure
├── plugins/
│   ├── GET /:pluginId/config    # Plugin UI schema (lazy loaded)
│   ├── GET /:pluginId/data      # Plugin data (tables, forms)
│   └── POST /:pluginId/action   # Operations (submit form, execute action)
└── notifications/
    └── WebSocket /ws             # Notification channel
```

**Endpoint Design Principles:**

1. **Resource-oriented**: `/plugins/:pluginId/data` not `/getPluginData`
2. **Lazy loading**: Config fetched only when tab opened
3. **Stateless**: Each request contains full context (session token, parameters)
4. **Idempotent GETs**: Safe to retry, cacheable
5. **POST for operations**: Form submissions, actions

### Plugin System

**Plugin Trait Pattern (Rust):**

```rust
trait Plugin {
    // Identity
    fn plugin_id(&self) -> String;
    fn plugin_type(&self) -> PluginType; // Table, Form, Action, Html

    // Configuration (UI schema)
    fn screen_config(&self, user: &User) -> PluginConfig;

    // Data fetching
    async fn get_data(&self, request: DataRequest, user: &User) -> Result<DataResponse>;

    // Operations
    async fn process_data(&self, data: serde_json::Value, user: &User) -> Result<ProcessResult>;

    // Validation
    fn validate_data(&self, data: serde_json::Value, user: &User) -> Result<ValidationResult>;

    // Authorization
    fn may_anonymous(&self) -> bool;
    fn may_user(&self, user: &User) -> bool;
}
```

**Plugin Registry:**

```rust
struct PluginRegistry {
    plugins: HashMap<String, Box<dyn Plugin>>,
}

impl PluginRegistry {
    fn register(&mut self, plugin: Box<dyn Plugin>);
    fn get(&self, plugin_id: &str) -> Option<&dyn Plugin>;
    fn list_for_user(&self, user: &User) -> Vec<PluginMetadata>;
}
```

**Key CallBackery Pattern Preserved:**
Plugins are registered at startup (from config), instantiated per-request, and provide three distinct interfaces: configuration (UI schema), data (read), and operations (write).

### Data Layer

**Database Access Pattern:**

```rust
// Repository pattern per plugin
trait Repository {
    async fn find_by_id(&self, id: i64) -> Result<Option<Row>>;
    async fn list(&self, filter: Filter, page: Page) -> Result<Vec<Row>>;
    async fn count(&self, filter: Filter) -> Result<i64>;
    async fn insert(&self, data: &Row) -> Result<i64>;
    async fn update(&self, id: i64, data: &Row) -> Result<()>;
    async fn delete(&self, id: i64) -> Result<()>;
}

// Plugin gets repository injected
struct MyTablePlugin {
    repo: Arc<dyn Repository>,
}
```

**Transaction Boundary:**
Operations (form submissions, actions) run in transactions. Queries can be outside transactions for read scalability.

## Protocol Design

### REST Endpoints

**Configuration Loading:**

```
GET /api/navigation/config
Response: {
  tabs: [
    { id: "users", label: "User Management", pluginId: "user_table" },
    { id: "reports", label: "Reports", pluginId: "report_form" }
  ]
}

GET /api/plugins/:pluginId/config
Response: {
  type: "table",
  config: {
    columns: [...],
    actions: [...],
    filters: [...]
  }
}
```

**Data Operations:**

```
GET /api/plugins/:pluginId/data?type=tableData&offset=0&limit=50&sort=name&order=asc
Response: {
  rows: [...],
  totalCount: 235
}

POST /api/plugins/:pluginId/action
Request: {
  action: "submit_form",
  data: { name: "John", email: "john@example.com" }
}
Response: {
  success: true,
  message: "User created",
  recordId: 123
}
```

**Error Format:**

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Invalid email format",
    "fields": {
      "email": "Must be valid email address"
    }
  }
}
```

### WebSocket Events

**Connection:**

```
Client -> Server: WebSocket /api/notifications/ws
Headers: Authorization: Bearer <session_token>

Server -> Client: { type: "connected", sessionId: "..." }
```

**Notification Events:**

```json
// Plugin data changed
{ "type": "plugin_update", "pluginId": "user_table" }

// Session expired
{ "type": "session_expired" }

// Global update (e.g., config changed)
{ "type": "navigation_update" }
```

**Frontend Response:**
Frontend doesn't extract data from WebSocket messages. It uses them as triggers to refetch via REST:

```typescript
ws.onmessage = (event) => {
  const notification = JSON.parse(event.data);

  if (notification.type === 'plugin_update') {
    // Refetch plugin data via REST
    await client.getTableData(notification.pluginId, currentParams);
  }

  if (notification.type === 'session_expired') {
    // Redirect to login
    router.navigate('/login');
  }
};
```

### Schema Definitions

**OpenAPI 3.1 Specification:**

Key schema types:

```yaml
PluginConfig:
  oneOf:
    - $ref: '#/components/schemas/TableConfig'
    - $ref: '#/components/schemas/FormConfig'
    - $ref: '#/components/schemas/HtmlConfig'

TableConfig:
  type: object
  properties:
    type:
      type: string
      enum: [table]
    columns:
      type: array
      items:
        $ref: '#/components/schemas/ColumnDefinition'
    actions:
      type: array
      items:
        $ref: '#/components/schemas/ActionDefinition'

FormConfig:
  type: object
  properties:
    type:
      type: string
      enum: [form]
    fields:
      type: array
      items:
        $ref: '#/components/schemas/FieldDefinition'
    submitAction:
      $ref: '#/components/schemas/ActionDefinition'
```

**Field Type System:**

Matching CallBackery's proven field types:
- `text`: Single-line text input
- `textarea`: Multi-line text
- `select`: Dropdown (static or dynamic options)
- `number`: Numeric input with validation
- `date`: Date picker
- `checkbox`: Boolean toggle
- `file`: File upload (POST to separate endpoint)

Each field type includes:
- Validation rules (required, pattern, min/max)
- Display properties (label, placeholder, help text)
- Conditional visibility (based on other field values)

## Data Flow

### Configuration Loading

**Sequence:**

```
1. User opens application
   Frontend -> GET /api/navigation/config
   Backend -> Returns tab list

2. Frontend renders navigation with tabs

3. User clicks "Users" tab
   Frontend -> GET /api/plugins/user_table/config
   Backend -> Plugin.screen_config() -> Returns table schema

4. Frontend renders TableComponent with schema
```

**Caching Strategy:**
- Navigation config: Cached for session, invalidated by WebSocket notification
- Plugin configs: Cached per plugin, invalidated by notification
- Plugin data: Not cached (always fresh from server)

### Data Operations

**Read Flow (Table):**

```
1. User opens table tab
   Frontend -> GET /api/plugins/user_table/config
   Backend -> Returns table schema (columns, actions)

2. Frontend renders empty table, requests data
   Frontend -> GET /api/plugins/user_table/data?type=tableData&offset=0&limit=50
   Backend -> Plugin.get_data() -> Query database -> Returns rows

3. User sorts/filters/paginates
   Frontend -> GET /api/plugins/user_table/data?type=tableData&offset=50&limit=50&sort=name
   Backend -> Plugin.get_data() with params -> Returns rows
```

**Write Flow (Form):**

```
1. User opens form (new record)
   Frontend -> GET /api/plugins/user_form/config
   Backend -> Returns form schema (fields, validation)

2. User fills form and submits
   Frontend -> POST /api/plugins/user_form/action
   Request: { action: "submit", data: {...} }

3. Backend validates and processes
   Backend -> Plugin.validate_data() -> Check rules
   Backend -> Plugin.process_data() -> Insert/update database
   Backend -> Returns success/error

4. Frontend handles response
   Success: Show message, navigate away
   Error: Display field errors inline
```

**Edit Flow (Form with existing data):**

```
1. User clicks "Edit" on table row
   Frontend -> GET /api/plugins/user_form/config?recordId=123
   Backend -> Returns form schema + current data

2. Form renders with pre-filled data

3. Submit flow same as new record
```

### Real-time Updates

**Push Notification Flow:**

```
1. Backend detects data change (e.g., another user modifies table)
   Backend -> Broadcasts WebSocket message
   { type: "plugin_update", pluginId: "user_table" }

2. Frontend receives notification
   Frontend -> Checks if user is viewing that plugin
   If yes: Refetch data via REST
   Frontend -> GET /api/plugins/user_table/data?...
   Backend -> Returns updated data

3. Frontend re-renders table with fresh data
```

**Key Design Decision:**
WebSocket is one-way (server -> client) for notifications only. No client requests over WebSocket. This keeps protocol simple and allows WebSocket layer to be independently scalable (separate service if needed).

## Build Order

Based on dependencies between components, recommended build order:

### Phase 1: Protocol Foundation
1. **OpenAPI Spec** — Define contract first
2. **Backend: Auth** — Login, session management, middleware
3. **Backend: Plugin Registry** — Core plugin trait, registry
4. **Frontend: Protocol Client** — REST client, types from OpenAPI

**Why first:** Everything depends on auth and plugin system.

### Phase 2: Simplest Plugin Type
5. **Backend: HTML Plugin** — Simplest type (no data operations)
6. **Frontend: HTML Component** — Render HTML from backend
7. **Backend: Navigation API** — Tab list endpoint
8. **Frontend: Navigation** — Tab switching

**Why second:** HTML plugin has no data complexity, validates plugin system works.

### Phase 3: Table Plugin
9. **Backend: Table Plugin Base** — Abstract table plugin
10. **Backend: Example Table Plugin** — Concrete implementation
11. **Frontend: Table Component** — Render table from schema
12. **Pagination/Sorting** — Table data parameters

**Why third:** Tables are read-only (simpler than forms), core use case.

### Phase 4: Form Plugin
13. **Backend: Form Plugin Base** — Abstract form plugin
14. **Backend: Example Form Plugin** — CRUD form
15. **Frontend: Form Component** — Dynamic form builder
16. **Frontend: Validation Display** — Error handling

**Why fourth:** Forms require validation logic, builds on table patterns.

### Phase 5: Real-time Updates
17. **Backend: WebSocket Server** — Notification broadcaster
18. **Frontend: WebSocket Client** — Notification handler
19. **Plugin-level notifications** — Broadcast on data changes

**Why fifth:** Optional enhancement, requires working plugins first.

### Phase 6: Advanced Features
20. **Action Plugins** — Buttons that trigger operations
21. **Hierarchical Plugins** — Parent-child relationships
22. **File Upload** — Special handling

**Why last:** These build on core patterns, not essential for MVP.

## Component Boundaries

### Clear Separations

**Frontend ↔ Backend:**
- **Protocol**: REST + WebSocket (OpenAPI spec is contract)
- **Frontend never**: Knows about database, business rules, plugin internals
- **Backend never**: Knows about UI framework, rendering, user interactions

**Plugin ↔ Framework:**
- **Framework provides**: Registration, routing, auth checks, error handling
- **Plugin provides**: Schema, data queries, validation rules, operations
- **Clear interface**: Plugin trait with fixed methods

**Data ↔ Presentation:**
- **Data layer**: Repository pattern, database queries
- **Plugin layer**: Business logic, validation
- **API layer**: HTTP serialization, auth middleware

### Anti-Patterns to Avoid

**1. Smart Frontend:**
Don't put business logic in frontend. Frontend is a renderer.

❌ Bad:
```typescript
// Frontend computing permissions
if (user.role === 'admin' || user.department === 'sales') {
  showButton();
}
```

✅ Good:
```typescript
// Backend provides actions based on permissions
config.actions.forEach(action => renderButton(action));
```

**2. Chatty Protocol:**
Don't make 10 requests to render one screen.

❌ Bad:
```typescript
const config = await getConfig(pluginId);
const data = await getData(pluginId);
const permissions = await getPermissions(pluginId);
const metadata = await getMetadata(pluginId);
```

✅ Good:
```typescript
// Single request includes everything needed
const config = await getConfig(pluginId); // Includes permissions
const data = await getData(pluginId);     // Metadata in response
```

**3. Tight Coupling:**
Don't make plugins aware of each other.

❌ Bad:
```rust
impl UserTablePlugin {
    fn get_data() -> Result<Data> {
        // Plugin calling another plugin directly
        let roles = role_plugin.get_roles()?;
    }
}
```

✅ Good:
```rust
impl UserTablePlugin {
    fn get_data() -> Result<Data> {
        // Plugin queries database directly
        let roles = self.repo.get_roles()?;
    }
}
```

**4. Stateful Backend:**
Don't track UI state on backend.

❌ Bad:
```rust
// Backend storing "which page user is on"
user_session.current_page = 3;
```

✅ Good:
```rust
// Frontend sends page in every request
fn get_data(params: TableParams) -> Result<Data> {
    let offset = params.page * params.limit;
}
```

## Technology-Specific Patterns

### Svelte 5 Patterns

**Component Composition:**
```svelte
<script>
  import { PluginRenderer } from './PluginRenderer.svelte';

  let pluginConfig = $state(null);

  async function loadPlugin(id) {
    pluginConfig = await client.getPluginConfig(id);
  }
</script>

<PluginRenderer config={pluginConfig} />
```

**Reactive Data Fetching:**
```svelte
<script>
  let tableParams = $state({ page: 0, sort: 'name' });

  let tableData = $derived.by(async () => {
    return await client.getTableData(pluginId, tableParams);
  });
</script>
```

### Axum Patterns

**Router with State:**
```rust
let app = Router::new()
    .route("/api/plugins/:id/config", get(get_plugin_config))
    .route("/api/plugins/:id/data", get(get_plugin_data))
    .route("/api/plugins/:id/action", post(plugin_action))
    .layer(middleware::from_fn(auth_middleware))
    .with_state(app_state);
```

**Extractors:**
```rust
async fn get_plugin_config(
    Path(plugin_id): Path<String>,
    State(registry): State<Arc<PluginRegistry>>,
    Extension(user): Extension<User>,
) -> Result<Json<PluginConfig>, Error> {
    let plugin = registry.get(&plugin_id)?;
    Ok(Json(plugin.screen_config(&user)))
}
```

**Error Handling:**
```rust
// Custom error type implementing IntoResponse
enum ApiError {
    NotFound,
    Unauthorized,
    ValidationError(HashMap<String, String>),
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        // Convert to JSON error response
    }
}
```

## Scalability Considerations

| Concern | At 100 users | At 10K users | At 1M users |
|---------|--------------|--------------|-------------|
| API servers | Single instance | Load balanced (stateless) | Multi-region deployment |
| Database | SQLite | PostgreSQL single instance | PostgreSQL with read replicas |
| WebSocket | Same process as API | Separate WS service | Distributed WS with Redis pub/sub |
| Sessions | In-memory | Redis | Redis cluster |
| Plugin configs | Computed per-request | Cached in Redis | CDN-cached with versioning |

**Key Scalability Property:**
Stateless API design means horizontal scaling is straightforward. WebSocket is the only stateful component and can be separated.

## Migration from CallBackery

**What Carries Over:**
- Plugin pattern (table/form/action/html)
- Lazy configuration loading
- Backend-driven UI generation
- Permission system (mayAnonymous, per-user checks)

**What Changes:**
- JSON-RPC → REST API (more standard, better tooling)
- Qooxdoo → Svelte (modern frontend, smaller bundle)
- Perl → Rust (type safety, performance)
- Implicit protocol → OpenAPI spec (formal contract)

**Migration Strategy:**
Not a direct migration. This is a new framework. Applications using CallBackery would need to:
1. Implement plugins against new trait interface
2. Map config grammar to new config format
3. Adjust any custom frontend code

**Advantage of Fresh Start:**
Clean break allows fixing accumulated inconsistencies without backward compatibility constraints.

## Sources

**Primary:**
- CallBackery architecture analysis (`.planning/codebase/ARCHITECTURE.md`)
- CallBackery plugin system (`lib/CallBackery/GuiPlugin/Abstract*.pm`)
- CallBackery RPC service (`lib/CallBackery/Controller/RpcService.pm`)

**Confidence Levels:**
- Plugin pattern: HIGH (directly from CallBackery reference)
- REST API design: MEDIUM (industry standard patterns from training)
- Svelte 5 patterns: MEDIUM (training data, specific runes syntax)
- Axum patterns: MEDIUM (training data, standard Rust patterns)
- WebSocket pattern: HIGH (proven CallBackery pattern adapted to WebSocket)

**Knowledge Gaps:**
- Svelte 5 specific runes API may have evolved since training cutoff
- Axum recent versions may have new patterns
- OpenAPI 3.1 specific features for schema composition

**Recommendations for Validation:**
- Review OpenAPI spec patterns with current documentation
- Verify Svelte 5 runes API against official docs
- Check Axum extractors and middleware patterns against latest docs

---

*Architecture research complete. Ready for roadmap phase structure.*
