# Architecture

**Analysis Date:** 2026-01-22

## Pattern Overview

**Overall:** Client-Server with Plugin Architecture

**Key Characteristics:**
- Mojolicious-based backend serving Qooxdoo Rich Internet Application (RIA) frontend
- Plugin-based GUI system allowing extensible screen/form configurations
- JSON-RPC communication layer between frontend and backend
- User authentication and authorization integrated at the RPC service level
- Config-driven plugin instantiation with lazy loading capabilities

## Layers

**Frontend (Qooxdoo JavaScript RIA):**
- Purpose: Rich interactive user interface with drag-and-drop forms, tables, cards, and HTML displays
- Location: `lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/`
- Contains: Qooxdoo application classes (Application.js, UI components, data models, utilities)
- Depends on: Backend JSON-RPC API via callbackery.data.Server
- Used by: End users via web browsers

**RPC Service Layer (JSON-RPC Controller):**
- Purpose: Exposes backend methods to frontend via standardized JSON-RPC 2.0 interface
- Location: `lib/CallBackery/Controller/RpcService.pm`
- Contains: RPC method handlers (login, getPluginData, processPluginData, validatePluginData, upload/download)
- Depends on: User authentication, Plugin instantiation, Config system
- Used by: Frontend via Qooxdoo RPC calls to `/QX-JSON-RPC` endpoint

**Plugin System (GuiPlugin Base Classes):**
- Purpose: Provides reusable components for building plugin-based user interfaces
- Location: `lib/CallBackery/GuiPlugin/`
- Contains: Abstract base classes (Abstract.pm, AbstractForm.pm, AbstractTable.pm, AbstractCardlist.pm, AbstractHtml.pm, AbstractAction.pm)
- Depends on: Config system, Database, User system, Exception handling
- Used by: Application-specific plugin implementations extending the base classes

**Configuration Management:**
- Purpose: Parse and manage the entire application configuration from file
- Location: `lib/CallBackery/Config.pm`
- Contains: Config file parser using Config::Grammar::Dynamic, plugin registry, and configuration validation
- Depends on: Grammar-based parsing, plugin loader
- Used by: Application startup, RPC service layer, all plugins

**User & Authentication:**
- Purpose: Manage user authentication, sessions, and authorization checks
- Location: `lib/CallBackery/User.pm`
- Contains: Session management, password validation, permission checking (may/mayAnonymous)
- Depends on: Database, session storage
- Used by: RPC service controller for access control, plugins for data filtering

**Database Access:**
- Purpose: Provide abstraction layer for database operations and migrations
- Location: `lib/CallBackery/Database.pm`
- Contains: SQLite database handling, SQL mapping utilities (map2sql, map2where), row/value fetching, data insertion/updates
- Depends on: Mojo::SQLite with migrations
- Used by: User system, plugins for data persistence

**Exception & Logging:**
- Purpose: Standardized error handling and internationalization
- Location: `lib/CallBackery/Exception.pm`, `lib/CallBackery/Translate.pm`
- Contains: Custom exception class with code/message, translation manager for gettext PO files
- Depends on: Exporter, Mojo::Base
- Used by: All modules for error reporting and multilingual support

## Data Flow

**Frontend to Backend Request:**

1. User interacts with Qooxdoo UI component (form submission, button click, etc.)
2. callbackery.data.Server (Qooxdoo RPC client) sends JSON-RPC request to `/QX-JSON-RPC` endpoint
3. Mojolicious router dispatches to `CallBackery::Controller::RpcService`
4. RpcService checks authentication via `User->isUserAuthenticated()`
5. RpcService instantiates appropriate GuiPlugin via `Config->instantiatePlugin()`
6. Plugin method executes (getData, processData, validateData) with form data
7. Plugin may query database via Database utility methods or direct SQL operations
8. Response (data/error) serialized to JSON and returned to frontend

**Backend to Frontend Response:**

1. Plugin returns result object or CallBackery::Exception
2. RpcService serializes response via JSON, handles exceptions specially
3. Response sent as JSON with `result` or `exception` field
4. Frontend callbackery.data.Server callback receives result
5. If exception with code 6 (auth), trigger login dialog; code 7 (session expired), reload page
6. Otherwise, update UI components with returned data

**State Management:**

- Frontend: Qooxdoo application singleton instances (callbackery.data.Config, callbackery.data.Server, callbackery.ui.Desktop)
- Backend: Per-request controller instantiation; user object attached to controller; session data in Mojolicious session store
- Database: SQLite with foreign key constraints enabled via pragma

## Key Abstractions

**GuiPlugin:**
- Purpose: Base class for all UI-generating plugins
- Examples: `lib/CallBackery/GuiPlugin/Abstract.pm`, `lib/CallBackery/GuiPlugin/AbstractForm.pm`, `lib/CallBackery/GuiPlugin/AbstractTable.pm`
- Pattern: Mojo::Base subclassing with attribute-based configuration; screenCfg returns JSON schema for UI generation; abstract methods overridden by subclasses

**Config Grammar:**
- Purpose: Define and validate configuration structure for plugins and system settings
- Examples: Each plugin defines `grammar()` method returning Config::Grammar::Dynamic structure
- Pattern: Declarative grammar with _doc, _vars, _mandatory fields; recursive grammar composition

**User Object:**
- Purpose: Encapsulates user context (authentication, permissions, database handle)
- Examples: Created per-request in `RpcService->user` lazy attribute
- Pattern: Weak reference to controller; database handle accessed via `user->db`; permission checks via `may()` method

## Entry Points

**HTTP Routes:**
- Location: `lib/CallBackery.pm` startup() method
- `/QX-JSON-RPC` → JSON-RPC handler (POST only)
- `/upload` → File upload handler (async)
- `/download` → File download handler (async)
- `/login` → Dummy login form (for browser password manager)
- `/doc` → Documentation pages

**Async/Promises:**
- Mojolicious async/await via Syntax::Keyword::Try in RpcService methods
- Config->promisify() wraps callbacks as Mojo::Promise
- instantiatePlugin_p async version for plugin loading

## Error Handling

**Strategy:** Exception-based with JSON serialization for client delivery

**Patterns:**

- Modules throw CallBackery::Exception via mkerror(code, message)
- RpcService catches exceptions in try/catch blocks
- Caught exceptions serialized as `{exception: {code: N, message: "..."}}` in JSON response
- Frontend detects exception field and either auto-handles (auth/session errors) or displays to user via MsgBox
- Validation errors returned as nested exception objects in response
- Database/SQL errors caught and converted to CallBackery::Exception with appropriate error code

## Cross-Cutting Concerns

**Logging:**
- Mojo::Log instance available via app->log or controller->log
- RpcService logs method calls/returns via logRpcCall/logRpcReturn when CALLBACKERY_RPC_LOG env var set
- Password fields masked with 'xxx' in logs to prevent credential leakage

**Validation:**
- GuiPlugin::validateData() method for per-field validation via JSON schema
- Config::Grammar validates configuration structure at parse time
- Database schema enforced via SQLite foreign keys

**Authentication:**
- User login via RpcService->login() checks credentials against database
- Session cookie generated via User->makeSessionCookie() and validated on each request
- Anonymous plugins allowed via instantiatePlugin() checks plugin->mayAnonymous attribute
- RPC access control via allow_rpc_access() method checking authentication and method whitelist

---

*Architecture analysis: 2026-01-22*
