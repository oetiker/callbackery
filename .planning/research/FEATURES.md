# Features Research: Backend-Driven UI Framework

**Domain:** Backend-driven web application framework (server-configures-frontend pattern)
**Researched:** 2026-01-22
**Confidence:** HIGH (based on CallBackery codebase analysis)

## Executive Summary

Backend-driven UI frameworks are a niche category where the server sends UI configuration (not just data) to a generic frontend. Unlike traditional REST APIs that return data for pre-built components, these frameworks return **component specifications** — the backend tells the frontend "render a table with these columns" or "render a form with these fields."

This research analyzes what features such frameworks require at the protocol level and categorizes them into table stakes (essential), differentiators (competitive advantages), and anti-features (things to avoid).

---

## Table Stakes

Features users expect. Missing these makes the framework incomplete or unusable.

### Protocol Features

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Plugin/component discovery** | Frontend must know what screens exist | Low | GET /api/navigation or similar returns app structure |
| **Lazy plugin configuration** | Large apps can't send all configs upfront | Medium | GET /api/plugins/{id}/config returns screen definition on-demand |
| **Screen configuration schema** | Frontend needs to know how to render components | High | Must support forms, tables, actions, HTML displays as distinct types |
| **Session management** | Multi-user apps need auth context | Medium | Standard session cookies or JWT tokens |
| **Error reporting protocol** | Backend validation/errors must reach frontend | Low | Standardized error shape in responses |
| **Field-level validation** | Users expect inline validation | Medium | Validation rules sent with field config, not hardcoded in frontend |

### UI Component Types

| Component | Why Expected | Complexity | Notes |
|-----------|--------------|------------|-------|
| **Forms** | Data entry is core to CRUD apps | High | Must support text, numbers, dates, selects, checkboxes, textareas |
| **Tables** | Data display/browsing is essential | High | Server-side pagination, sorting, column definitions |
| **Actions/buttons** | Users need to trigger operations | Medium | Submit, download, popup/modal triggers, context menus |
| **Navigation structure** | Multi-screen apps need menu/tabs | Medium | Hierarchical or flat, with labels and access control |
| **Read-only displays** | Not everything is editable | Low | HTML rendering or static text panels |

### Data Handling Features

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **CRUD operations** | Create, Read, Update, Delete are fundamental | Medium | Standard REST verbs or RPC methods |
| **Pagination** | Large datasets can't be sent in full | Medium | firstRow/lastRow or offset/limit parameters |
| **Sorting** | Users expect to sort tables | Low | sortColumn + sortDesc parameters |
| **Filtering** | Essential for usable tables | Medium | formData passed to table queries for filtering |
| **Parent-child relationships** | Master-detail patterns are common | High | Selection in parent populates child component |
| **Form data initialization** | Edit forms need current values | Low | GET endpoint returns current field values |
| **Field dependencies** | One field's value affects another | High | Dynamic form reconfiguration based on field changes |

### Field Types

| Type | Why Expected | Complexity | Notes |
|------|--------------|------------|-------|
| **Text input** | Universal data entry | Low | Single-line and multi-line (textarea) |
| **Number input** | Numeric data with validation | Low | Min/max, step constraints |
| **Select/dropdown** | Constrained choices | Medium | Static options or dynamic from endpoint |
| **Checkbox** | Boolean values | Low | True/false toggles |
| **Date/DateTime** | Temporal data | Medium | ISO8601 format, timezone handling |
| **Radio buttons** | Exclusive choice from small set | Low | Alternative to select for visibility |
| **File upload** | Users need to attach files | High | Multipart form data, progress tracking |

### Security Features

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Authentication** | Multi-user systems need login | Medium | Username/password, session creation |
| **Authorization checks** | Users have different permissions | Medium | Per-plugin/screen access control |
| **Session expiry handling** | Security requirement | Low | Frontend detects and redirects to login |
| **CSRF protection** | Standard web security | Medium | Token-based or same-site cookies |

---

## Differentiators

Features that set the framework apart. Not expected, but provide competitive advantage.

### Developer Experience

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **OpenAPI specification** | Self-documenting, enables codegen | Medium | Industry-standard contract definition |
| **Type-safe backend API** | Catch errors at compile time | Medium | Rust/TypeScript backends benefit greatly |
| **Hot-reload during dev** | Faster iteration cycle | Low | Backend config changes don't require frontend rebuild |
| **Plugin generator/scaffolding** | Lower barrier to entry | Medium | CLI to create new plugin boilerplate |
| **Built-in validation library** | Don't reinvent common validations | Low | Email, URL, regex patterns pre-built |
| **Comprehensive examples** | Reduces learning curve | Low | Sample apps for common patterns |
| **Clear mental model docs** | Root cause fix for confusion | Medium | Explain the pattern, not just API reference |

### Runtime Features

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Real-time updates** | Data changes push to all clients | High | WebSocket for notifications, triggers refresh |
| **Multi-step wizards** | Complex workflows feel guided | High | State machine on backend, step-by-step UI |
| **Context-sensitive actions** | Operations appear based on selection | Medium | Action visibility rules based on row data |
| **Computed/derived fields** | Backend calculates, frontend displays | Medium | Field value from formula, updates on dependency change |
| **Optimistic UI updates** | Feels faster | Medium | Frontend updates immediately, reverts on error |
| **Undo/redo support** | Power user feature | High | Command pattern on backend |
| **Bulk operations** | Act on multiple rows at once | Medium | Multi-select + action button |
| **Export to CSV/XLSX** | Standard business requirement | Medium | Backend generates file from table data |
| **Audit trail** | Who changed what when | Medium | Automatic logging of all mutations |
| **Multi-language support** | Internationalization | Medium | Translation keys in config, frontend resolves |
| **Theming/branding** | White-label deployments | Medium | CSS variables or theme config endpoint |
| **Keyboard shortcuts** | Power user efficiency | Low | Frontend binds keys to backend-defined actions |
| **Card/grid view** | Alternative to table for visual data | Medium | Layout config in plugin type |
| **Collapsible sections** | Organize complex forms | Low | Section headers with expand/collapse |
| **Inline editing** | Edit-in-place in tables | High | Update triggered without opening form |
| **Row grouping** | Aggregate data visually | Medium | Group-by parameter in table config |
| **Column visibility toggle** | User customization | Low | Frontend stores preferences, backend unaware |
| **Responsive layout hints** | Mobile-friendly | Medium | Backend suggests column priority for small screens |

---

## Anti-Features

Things to deliberately NOT build. Common mistakes in this domain.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| **Custom scripting language in config** | Adds complexity, security risks, maintenance burden | Use native backend language for logic, send results as config |
| **Frontend business logic** | Defeats the purpose (backend should drive) | Keep frontend as dumb renderer, all logic in backend |
| **GraphQL** | Overkill for this pattern, couples frontend to schema | REST endpoints return full screen config, not queryable graph |
| **Client-side routing with frontend-defined routes** | Backend should define navigation structure | Backend returns navigation config, frontend renders it |
| **Schema-less "send arbitrary JSON"** | No contract = integration hell | OpenAPI spec or JSON Schema for all payloads |
| **Inline HTML in backend config for layout** | Security risk (XSS), couples backend to frontend tech | Backend sends structured config, frontend applies layout |
| **File upload as base64 in JSON** | Inefficient, memory-intensive | Separate multipart endpoint, return file ID |
| **Polling for real-time updates** | Wasteful, slow | WebSocket for push notifications |
| **Hardcoded field types** | Not extensible | Plugin system for custom field renderers |
| **No versioning of protocol** | Breaking changes break all clients | Include API version in URL or header |
| **Single monolithic plugin type** | Forces one-size-fits-all | Distinct types: Form, Table, Action, Html, CardList |
| **Synchronous-only operations** | Blocking UX for slow operations | Async/promise support for long-running actions |
| **Admin-only features baked into core** | Bloats the framework | Admin features as optional plugins |
| **Trying to support every frontend framework** | Maintenance nightmare | Pick one frontend stack, do it well |
| **Database coupling in protocol** | Leaks implementation details | Protocol agnostic to storage (could be DB, API, filesystem) |

---

## Feature Dependencies

Visual representation of which features depend on others:

```
Authentication
  └─> Authorization checks
      └─> Per-plugin access control
          └─> Navigation structure (filtered by permissions)

Forms
  ├─> Field types (text, number, date, select, etc.)
  ├─> Field-level validation
  ├─> Field dependencies (dynamic reconfiguration)
  └─> Actions (submit, cancel buttons)

Tables
  ├─> Pagination
  ├─> Sorting
  ├─> Filtering (via form data)
  ├─> Parent-child relationships (selection drives child table)
  └─> Actions (context menu, bulk operations)
      └─> Export (special action type)

Actions
  ├─> Popup/modal forms (action opens another plugin)
  ├─> Download (action returns file)
  └─> Submit (action processes form data)

Real-time updates (if included)
  └─> WebSocket connection
      └─> Triggers table refresh or form reload

File upload (if included)
  └─> Multipart endpoint
  └─> Progress tracking
  └─> File reference in form submissions
```

**Critical path for MVP:**
1. Authentication (blocks everything in multi-user app)
2. Navigation structure (defines app)
3. Forms with basic field types (data entry)
4. Tables with pagination (data display)
5. Actions for submit/save (completes CRUD)
6. Parent-child relationships (enables complex apps)

**Can defer to v2:**
- Real-time updates (nice-to-have, not essential)
- Export to CSV/XLSX (common request but not blocking)
- Multi-step wizards (complex, uncommon)
- Audit trail (compliance feature, not core)
- Theming (customization, not functionality)
- Inline editing (UX enhancement)
- Card view (alternative layout, not essential)

---

## Recommendations for v1

### Must Include (Table Stakes)

**Protocol:**
- Navigation discovery (GET /api/navigation)
- Plugin configuration (GET /api/plugins/{id}/config)
- Standardized error responses
- Session management

**Components:**
- Form (with field types: text, number, date, select, checkbox, textarea)
- Table (with pagination, sorting)
- Actions (submit, popup, download)
- Navigation tabs/menu

**Data handling:**
- CRUD operations (processData endpoint)
- Parent-child relationships (selection passes ID to child)
- Field validation (rules in config, validated on backend)
- Field dependencies (triggerField parameter reconfigures form)

**Security:**
- Authentication (login endpoint)
- Authorization (checkAccess per plugin)
- Session expiry handling

### Should Include (Differentiators Worth the Effort)

- **OpenAPI specification** — This is core to the value proposition (any backend can implement)
- **WebSocket for notifications** — Modernizes the pattern, not hard to add
- **Export to XLSX** — Common business requirement, relatively easy
- **Multi-language support** — If targeting reuse, plan for this now
- **Field dependency system** — Powerful feature, enables complex forms

### Defer to v2

- Wizards (high complexity, low initial demand)
- Audit trail (add when compliance is needed)
- Inline editing (UX polish, not essential)
- Undo/redo (niche power user feature)
- Advanced table features (grouping, pivoting, etc.)
- Theming beyond basic CSS variables
- Custom field types (do this when users ask)

### Explicitly Avoid

- Client-side scripting in config
- GraphQL
- Frontend-driven routing
- Schema-less JSON
- Base64 file uploads in JSON
- Polling (use WebSocket instead)
- Monolithic plugin architecture

---

## Protocol Surface Area

Based on CallBackery's implementation, here's what the REST API must support:

### Core Endpoints

```
POST /api/auth/login
  Body: { username, password }
  Returns: { sessionToken, userId, userInfo }

GET /api/navigation
  Returns: { tabs: [{ id, label, pluginId, ... }] }

GET /api/plugins/{id}/config
  Query: ?args={...}
  Returns: { type: 'form'|'table'|'action'|'html'|'cardlist', ...config }

POST /api/plugins/{id}/data
  Query: ?type=tableData|tableRowCount|field|allFields
  Body: { formData, firstRow, lastRow, sortColumn, sortDesc }
  Returns: [data rows] or field value

POST /api/plugins/{id}/validate
  Body: { fieldName, formData }
  Returns: null or { error: "message" }

POST /api/plugins/{id}/action/{actionKey}
  Body: { formData }
  Returns: result or { action: 'download', filename, ... }

POST /api/upload
  Content-Type: multipart/form-data
  Returns: { fileId }

GET /api/download/{fileId}
  Returns: file stream
```

### WebSocket Events

```
Event: data_changed
  Payload: { pluginId, affectedRecordIds }
  Action: Frontend refreshes affected components

Event: session_expired
  Action: Frontend redirects to login

Event: notification
  Payload: { message, severity }
  Action: Frontend shows toast/alert
```

---

## Research Sources

**Primary source:** CallBackery codebase analysis
- `/lib/CallBackery/GuiPlugin/Abstract*.pm` — Base classes for all plugin types
- `/lib/CallBackery/Controller/RpcService.pm` — Protocol endpoints
- `.planning/codebase/ARCHITECTURE.md` — System structure

**Confidence:** HIGH — All features verified in working implementation

**Gaps:**
- Could not access contemporary competing frameworks (WebSearch unavailable)
- Relying on CallBackery as reference may miss innovations from 2024-2026
- Real-world usage patterns from actual deployments not analyzed

**Recommendations for validation:**
- Survey other backend-driven frameworks (React Admin, Retool, Budibase) when WebSearch available
- Interview CallBackery users about pain points and missing features
- Prototype minimal protocol and get feedback before building full spec

---

*Research complete: 2026-01-22*
