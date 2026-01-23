# Phase 1: Protocol Foundation - Research v2

**Researched:** 2026-01-23
**Domain:** Fundamental atoms of Server-Driven UI (SDUI) systems and protocol boundary design
**Confidence:** HIGH

## Summary

This research explores the irreducible atomic concepts of server-driven UI systems, drawing from industry implementations at Airbnb, Shopify, Netflix, Lyft, REI, and others. The goal is to identify the true building blocks that underpin ANY backend-driven frontend system, not specific implementations like "form" or "table."

The key insight from this research is that successful SDUI systems share a common set of atoms that are more fundamental than specific plugin types. These atoms are: **Component Tree** (what to render), **Actions** (what can happen), **State/Data** (what changes), **Navigation** (where to go), **Events/Notifications** (when things change), **Styling/Theming** (how things look), and **Translation** (what language). The protocol boundary should separate "what" (server decides) from "how" (client decides).

**Primary recommendation:** Design the protocol around these fundamental atoms with generic capability patterns. Let specific plugin types (forms, tables, etc.) be compositions of these atoms, not first-class protocol concepts.

## The Puppeteer/Puppet Mental Model

The user's metaphor of "backend as puppeteer, frontend as clever puppet" aligns with industry patterns:

| Aspect | Puppeteer (Backend) | Clever Puppet (Frontend) |
|--------|---------------------|--------------------------|
| **Decides** | What to show, what data, what options | How to render, animations, interactions |
| **Provides** | Configuration, data, validation rules | Platform-specific rendering, UX polish |
| **Controls** | Business logic, authorization, state truth | Local state, optimistic updates, caching |
| **Changes** | Through protocol messages | Autonomously within boundaries |

**Key insight from Airbnb:** "What if clients didn't need to know they were even displaying a listing? What if we could pass the UI directly to the client and skip the idea of listing data entirely?"

**Key insight from REI:** "Adding new filters simply becomes a matter of adding a new case to the switch statement" on the backend - the frontend is forward-compatible without updates.

## The Six Fundamental Atoms

Based on research across multiple SDUI implementations, these are the irreducible atomic concepts:

### Atom 1: Component Tree (Presentation)

**What it is:** A hierarchical description of what the UI should display.

**Structure:**
```
Screen/Page
  -> Section/Region
    -> Component (renders something)
      -> Children (nested components)
```

**Key properties:**
- `type`: What kind of component (the frontend's registry determines how to render)
- `props/attributes`: Configuration for this component instance
- `children`: Nested components
- `key/id`: Unique identifier for reconciliation

**Industry patterns:**
- **Airbnb Ghost Platform:** 100-200 "core sections," each with a `Section` interface and `SectionComponent` renderer
- **Shopify Shop App:** `ProductsSection`, `CollectionsSection` with configurable layouts (`GridLayout`, `ShelfLayout`)
- **Apollo GraphQL:** Union types representing different response shapes, fragments for client capability negotiation

**The clever puppet's role:** The frontend maintains a component registry mapping `type` strings to platform-native renderers. The backend never specifies HOW to render - only WHAT to render.

### Atom 2: Actions (Interactions)

**What it is:** Descriptions of what can happen when users interact.

**Structure:**
```
Action
  -> type: What kind of action
  -> target: Where to send it / what it affects
  -> payload: Data to send
  -> confirmation: Optional "are you sure?" prompt
```

**Common action types (from Lyft Canvas, Netflix CLCS, wutsi SDUI):**
- `navigate`: Go somewhere (deeplink, route, URL)
- `submit`: Send data to backend
- `dismiss`: Close/hide something
- `share`: Platform share sheet
- `track`: Analytics event
- `mutate`: Change local state
- `refresh`: Reload data

**The clever puppet's role:** Frontend knows how to execute each action type natively. Backend specifies WHAT action, frontend decides HOW (animations, confirmation dialogs, optimistic updates).

### Atom 3: State/Data (What Changes)

**What it is:** The data that components display and that actions modify.

**Two distinct concerns:**
1. **Server State:** Truth lives on backend, fetched and refreshed
2. **Client State:** Local interactions, form values before submit, UI state

**Binding pattern (from A2UI Protocol):**
```json
{
  "component": "TextField",
  "props": {
    "value": {"$ref": "/data/form/email"},
    "label": "Email Address"
  }
}
```

JSON Pointer paths (RFC 6901) bind UI components to data locations, enabling bidirectional data flow without coupling.

**The clever puppet's role:** Frontend manages optimistic updates, local validation, form state. Backend is authoritative for persisted state.

### Atom 4: Navigation (Where to Go)

**What it is:** The structure of the application and how users move through it.

**Structure:**
```
NavigationItem
  -> id: Unique identifier
  -> label: Display text (or translation key)
  -> target: What to show (component tree reference, deeplink, lazy load config)
  -> children: Nested navigation items
  -> badge/indicator: Optional notification count, etc.
```

**Key patterns:**
- **Hierarchical:** Tree structure for menus, tabs, drawers
- **Lazy loading:** Navigation items reference configurations loaded on demand
- **Context propagation:** Parent selection affects child content (master-detail)

**The clever puppet's role:** Frontend decides how to render navigation (tabs, sidebar, drawer, bottom nav) based on platform and screen size. Backend provides the structure.

### Atom 5: Events/Notifications (When Things Change)

**What it is:** Signals from server to client that something changed.

**Structure:**
```
Event
  -> type: What kind of event
  -> target: What it affects (resource, component, data path)
  -> payload: Event-specific data
```

**Common patterns (from Netflix UMA, industry WebSocket patterns):**
- `invalidate`: This data is stale, refetch it
- `update`: Here's new data, merge it
- `navigate`: Go somewhere (server-initiated navigation)
- `notify`: Show a message to user
- `reconfigure`: The UI definition changed, reload config

**The clever puppet's role:** Frontend subscribes to event streams, decides how to handle each event type (background refresh, toast notification, full reload).

### Atom 6: Design Tokens (How Things Look)

**What it is:** Visual parameters that configure the puppet's appearance.

**W3C Design Tokens Specification (October 2025):**
```json
{
  "color": {
    "primary": {"$value": "#0066cc", "$type": "color"},
    "background": {"$value": "#ffffff", "$type": "color"}
  },
  "spacing": {
    "small": {"$value": "8px", "$type": "dimension"},
    "medium": {"$value": "16px", "$type": "dimension"}
  }
}
```

**Theming layers:**
1. **Global tokens:** Base design system values
2. **Alias tokens:** Semantic mappings (primary-color, error-color)
3. **Component tokens:** Component-specific overrides

**The clever puppet's role:** Frontend applies tokens through its design system. Backend can override tokens for branding, A/B tests, or user preferences.

### Atom 7: Translation/i18n (What Language)

**What it is:** Localized strings and formatting rules.

**Two approaches:**
1. **Server-side rendering:** Backend sends pre-translated strings (Apollo recommendation: "return only strings")
2. **Key-based:** Backend sends translation keys, frontend looks up from loaded bundles

**Hybrid pattern:**
- Static UI labels: Key-based, frontend manages bundles
- Dynamic content: Server-rendered with locale from request
- Formatting: Server provides rules (date format, number format), frontend applies

**The clever puppet's role:** Frontend handles text rendering, RTL layout, pluralization rules. Backend provides content and format preferences.

## The Protocol Boundary

The protocol should define CAPABILITIES, not PLUGINS:

### What the Protocol Defines (Generic Capabilities)

| Capability | Purpose | Protocol Shape |
|------------|---------|----------------|
| `getConfig` | Retrieve UI configuration | Request: context -> Response: Component tree |
| `getData` | Retrieve data for components | Request: query params -> Response: Data + pagination |
| `submitAction` | Execute an action | Request: action + payload -> Response: result |
| `validate` | Check data validity | Request: data -> Response: validation result |
| `subscribe` | Listen for events | WebSocket: event stream |
| `getTokens` | Retrieve design tokens | Request: theme context -> Response: token values |
| `getTranslations` | Retrieve translation bundle | Request: locale -> Response: key-value map |

### What the Frontend Defines (Component Registry)

The frontend publishes JSON Schemas for each component type it supports:

```json
{
  "TextField": {
    "props": {
      "label": {"type": "string"},
      "value": {"type": "string"},
      "required": {"type": "boolean"},
      "validation": {"$ref": "#/definitions/ValidationRule"}
    }
  },
  "DataGrid": {
    "props": {
      "columns": {"type": "array", "items": {"$ref": "#/definitions/Column"}},
      "dataSource": {"$ref": "#/definitions/DataBinding"}
    }
  }
}
```

### Bidirectional Schema Sharing

**The key insight:** Both sides validate against shared schemas.

1. **Frontend publishes** component schemas (what props each component accepts)
2. **Backend validates** its configurations against these schemas before sending
3. **Frontend validates** incoming configurations for safety/compatibility
4. **Backend publishes** data schemas (what shape the data has)
5. **Frontend validates** received data against these schemas

This creates a **contract** that prevents:
- Backend sending unknown component types
- Backend sending invalid props
- Deserialization errors on frontend
- Type mismatches in data binding

## Reconfiguration Patterns

The user asked specifically about "on-the-fly reconfiguration." Here are the patterns:

### Pattern 1: Event-Driven Invalidation

```
Server: emit event {type: "invalidate", target: "/plugins/user-list/config"}
Client: receives event -> refetches config -> re-renders
```

Use when: Configuration changed, full refresh needed.

### Pattern 2: Patch-Based Updates

```
Server: emit event {type: "patch", target: "/data/users", operations: [...]}
Client: applies JSON Patch (RFC 6902) to local data -> re-renders
```

Use when: Data changed, incremental update possible.

### Pattern 3: Component Replacement

```
Server: emit event {type: "replace", target: "#notification-area", component: {...}}
Client: replaces component subtree at target location
```

Use when: Part of UI needs to change without full reload.

### Pattern 4: State Synchronization

```
Server: emit event {type: "setState", path: "/form/email", value: "new@example.com"}
Client: updates local state at path -> triggers re-render
```

Use when: Server needs to modify client state (e.g., form reset after save).

## How Forms/Tables Become Compositions

The original plans defined forms and tables as first-class concepts. With the atoms approach:

### A "Form" is:

```json
{
  "type": "FormContainer",
  "props": {
    "dataBinding": "/data/editUser",
    "submitAction": {"type": "submit", "target": "/plugins/user-edit/data"}
  },
  "children": [
    {
      "type": "TextField",
      "props": {"label": "Name", "value": {"$ref": "/data/editUser/name"}}
    },
    {
      "type": "EmailField",
      "props": {"label": "Email", "value": {"$ref": "/data/editUser/email"}}
    },
    {
      "type": "Button",
      "props": {"label": "Save", "action": {"type": "submit"}}
    }
  ]
}
```

The protocol doesn't know about "forms" - it knows about component trees, data bindings, and actions.

### A "Table" is:

```json
{
  "type": "DataGrid",
  "props": {
    "dataSource": {"$ref": "/data/users"},
    "columns": [
      {"key": "name", "label": "Name", "sortable": true},
      {"key": "email", "label": "Email"}
    ],
    "actions": [
      {"type": "navigate", "target": "/users/{id}/edit", "label": "Edit"}
    ]
  }
}
```

The protocol doesn't know about "tables" - it knows about components with data bindings and actions.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Design tokens | Custom theming JSON | W3C Design Tokens format | Standard format, tool ecosystem |
| Component schemas | Custom validation | JSON Schema 2020-12 | Standard, bidirectional validation |
| Data binding paths | Custom syntax | JSON Pointer (RFC 6901) | Standard, proven, parseable |
| Patch operations | Custom diff format | JSON Patch (RFC 6902) | Standard, reversible, efficient |
| Event format | Custom structure | SSE/WebSocket + JSON envelope | Proven patterns, wide support |
| Translation format | Custom i18n JSON | ICU MessageFormat / i18next | Pluralization, formatting rules |

## Common Pitfalls

### Pitfall 1: Over-Specifying the Protocol

**What goes wrong:** Protocol defines "FormField" with every possible property (min, max, pattern, etc.), becoming a leaky abstraction.

**How to avoid:** Protocol defines generic component tree. Form field properties are component-specific props defined by frontend's JSON Schema. Backend just provides values for props the component schema declares.

### Pitfall 2: Under-Empowering the Puppet

**What goes wrong:** Backend specifies pixel positions, exact colors, animations. Frontend becomes a dumb renderer with no ability to adapt.

**How to avoid:** Backend specifies WHAT (semantic intent: "primary button", "error state"). Frontend decides HOW (color mapping, animation style, responsive layout).

### Pitfall 3: No Schema Contract

**What goes wrong:** Backend sends arbitrary JSON, frontend crashes on unexpected shapes. Or backend breaks frontend with schema changes.

**How to avoid:** Both sides publish and validate against schemas. Version the schemas. Frontend declares what components it supports with their prop schemas.

### Pitfall 4: Conflating Navigation and Layout

**What goes wrong:** Navigation structure tied to specific layout (sidebar vs tabs), limiting platform adaptation.

**How to avoid:** Navigation is abstract structure. Layout is frontend's interpretation based on device, screen size, user preference.

### Pitfall 5: Ignoring Client-Side State

**What goes wrong:** Every keystroke round-trips to server. Form loses data on navigation. No optimistic updates.

**How to avoid:** Protocol acknowledges client state. Actions can be local-only or server-bound. Client manages transient state, server manages persistent state.

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Plugin-type-specific endpoints | Generic capability endpoints | Extensibility without protocol changes |
| Backend specifies layout | Backend specifies components, frontend decides layout | Platform adaptation |
| Custom JSON formats | Standards (JSON Schema, JSON Pointer, Design Tokens) | Interoperability, tooling |
| Polling for updates | WebSocket/SSE event streams | Real-time, efficient |
| Monolithic config response | Component tree with lazy loading | Performance, incremental loading |
| Client-rendered translations | Server-rendered strings OR shared keys | Flexibility per content type |

## Open Questions

1. **Schema Discovery Protocol**
   - How does backend discover what components frontend supports?
   - Options: Well-known endpoint, capability negotiation header, version-based compatibility
   - Recommendation: Frontend exposes `/schema/components` endpoint, backend fetches on startup

2. **Versioning Component Schemas**
   - What happens when frontend adds new props to existing component?
   - Options: Semver for component registry, backward-compatible prop additions only
   - Recommendation: Additive changes only, new required props = new component type

3. **Offline Support**
   - How does the puppet operate without the puppeteer?
   - Options: Cached configurations, local-only actions, sync on reconnect
   - Recommendation: Defer to v2, complex interaction with validation and state

4. **Action Queuing**
   - What happens to actions when offline or when server is slow?
   - Options: Queue with retry, optimistic UI, conflict resolution
   - Recommendation: Define action properties (idempotent, queued, immediate)

## Sources

### Primary (HIGH confidence)
- [Airbnb SDUI - InfoQ](https://www.infoq.com/news/2021/07/airbnb-server-driven-ui/) - Ghost Platform architecture
- [Shopify SDUI](https://shopify.engineering/server-driven-ui-in-shop-app) - Section-based architecture
- [Apollo GraphQL SDUI Guide](https://www.apollographql.com/docs/graphos/schema-design/guides/sdui/basics) - Schema design patterns
- [Mobile Native Foundation Discussion](https://github.com/MobileNativeFoundation/discussions/discussions/47) - Multi-company SDUI strategies
- [W3C Design Tokens Spec](https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/) - Design tokens standard (Oct 2025)
- [REI SDUI](https://engineering.rei.com/mobile/server-driven-ui.html) - JSON Schema approach

### Secondary (MEDIUM confidence)
- [Netflix Server-Driven Notifications - InfoQ](https://www.infoq.com/news/2024/07/netflix-server-driven-ui/) - CLCS system
- [Lyft Canvas System](https://medium.com/@aubreyhaskett/server-driven-ui-what-airbnb-netflix-and-lyft-learned-building-dynamic-mobile-experiences-20e346265305) - Protobuf-based SDUI
- [Engineering Dumb: Modern Mobile Thin Clients - InfoQ](https://www.infoq.com/presentations/modern-mobile/) - Thin client patterns
- [Comviva SDUI Concepts](https://www.comviva.com/blog/server-driven-ui-concepts-and-building-blocks/) - Building blocks overview

### Tertiary (LOW confidence - requires validation)
- Various Medium articles on SDUI patterns
- GitHub examples (csmets/Server-Driven-UI, wutsi/sdui)

## Metadata

**Confidence breakdown:**
- Fundamental atoms: HIGH - Consistent across multiple industry implementations
- Protocol boundary: HIGH - Clear patterns from Airbnb, Shopify, Apollo
- Schema sharing: MEDIUM - Pattern is sound, specific implementation varies
- Reconfiguration: MEDIUM - Event patterns well-established, specifics context-dependent

**Research date:** 2026-01-23
**Valid until:** 90 days (fundamental concepts are stable, implementation details evolve)

---

## Appendix: Mapping to User's Initial Atoms

The user identified these atoms. Here's how they map to the research:

| User's Atom | Research Finding | Notes |
|-------------|------------------|-------|
| Navigation | Atom 4: Navigation | Confirmed as fundamental, structure is hierarchical |
| Notification | Atom 5: Events | Broader than notifications - includes all server->client signals |
| Design parameters | Atom 6: Design Tokens | Use W3C standard, three-tier hierarchy |
| Translation system | Atom 7: Translation | Hybrid approach (server-rendered + key-based) |
| Presentation + Input | Atoms 1-3: Component Tree + Actions + State | These three are tightly coupled |
| Reconfiguration | Pattern layer on Atom 5: Events | Events trigger config reloads, patches, replacements |

The research confirms the user's intuition but refines it: Presentation and Input are actually three distinct atoms (Component Tree for rendering, Actions for interactions, State for data), while Reconfiguration is a pattern built on Events rather than a separate atom.
