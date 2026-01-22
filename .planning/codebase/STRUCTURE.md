# Codebase Structure

**Analysis Date:** 2026-01-22

## Directory Layout

```
callbackery/
├── lib/
│   └── CallBackery/              # Main Perl package namespace
│       ├── CallBackery.pm        # Mojolicious app class (entry point)
│       ├── Config.pm             # Configuration parser and management
│       ├── Database.pm           # Database access abstraction layer
│       ├── User.pm               # User authentication and context
│       ├── Exception.pm          # Custom exception class
│       ├── Translate.pm          # Internationalization via gettext PO files
│       ├── Command/              # CLI commands
│       │   └── showconfig.pm     # Config inspection command
│       ├── Controller/           # Mojolicious controllers
│       │   └── RpcService.pm     # JSON-RPC service handler
│       ├── GuiPlugin/            # Plugin base classes for UI components
│       │   ├── Abstract.pm       # Base class for all plugins
│       │   ├── AbstractAction.pm # Base for action plugins
│       │   ├── AbstractForm.pm   # Base for form plugins
│       │   ├── AbstractTable.pm  # Base for table/data-grid plugins
│       │   ├── AbstractCardlist.pm # Base for card-based list plugins
│       │   ├── AbstractHtml.pm   # Base for HTML display plugins
│       │   ├── Users.pm          # Built-in user management plugin
│       │   └── UserForm.pm       # Built-in user form plugin
│       ├── Model/                # Data model utilities
│       │   └── ConfigJsonSchema.pm # JSON schema generation from config
│       ├── Plugin/               # Non-GUI plugins
│       │   └── Doc.pm            # Documentation system
│       ├── qooxdoo/              # Frontend assets and code
│       │   ├── callbackery/      # Main Qooxdoo application
│       │   │   ├── Manifest.json # Qooxdoo build manifest
│       │   │   ├── cache/        # Build cache (generated)
│       │   │   └── source/       # Frontend source code
│       │   │       ├── class/
│       │   │       │   └── callbackery/
│       │   │       │       ├── Application.js      # Main app class
│       │   │       │       ├── ui/                 # UI components
│       │   │       │       │   ├── Desktop.js      # Main desktop layout
│       │   │       │       │   ├── TabView.js      # Tab container
│       │   │       │       │   ├── Header.js       # App header
│       │   │       │       │   ├── Footer.js       # App footer
│       │   │       │       │   ├── Plugins.js      # Plugin container
│       │   │       │       │   ├── Card.js         # Card component
│       │   │       │       │   ├── TabView.js      # Tab view
│       │   │       │       │   ├── MsgBox.js       # Message dialog
│       │   │       │       │   ├── HtmlBox.js      # HTML display
│       │   │       │       │   ├── form/           # Form components
│       │   │       │       │   │   ├── Auto.js     # Auto-form generator
│       │   │       │       │   │   ├── VirtualSelectBox.js
│       │   │       │       │   │   └── renderer/   # Form renderers
│       │   │       │       │   └── plugin/         # Plugin UI wrappers
│       │   │       │       ├── data/               # Data layer
│       │   │       │       │   ├── Server.js       # RPC client wrapper
│       │   │       │       │   ├── Config.js       # Client config model
│       │   │       │       │   └── MHistoryRelaxedEncoding.js
│       │   │       │       ├── util/               # Utilities
│       │   │       │       │   ├── format/         # Value formatters
│       │   │       │       │   └── ...
│       │   │       │       ├── theme/              # Qooxdoo theme customizations
│       │   │       │       ├── locale/             # Frontend translations
│       │   │       │       └── test/               # Frontend tests
│       │   │       ├── resource/                   # Static assets (images, CSS)
│       │   │       │   └── callbackery/
│       │   │       │       └── spinner.gif
│       │   │       └── translation/                # Translation source files
│       │   └── uploadwidget/     # File upload widget library
│       │       └── Manifest.json
│       └── templates/            # Mojolicious templates
│           └── doc.html.ep       # Documentation page template
├── t/                            # Test directory
│   ├── basic.t                   # Basic integration tests
│   ├── invalidPlugin.t           # Plugin error handling tests
│   └── callbackery.cfg           # Test configuration
├── bin/                          # Executable scripts
├── etc/                          # Configuration files
│   └── callbackery.cfg           # Main application config
├── thirdparty/                   # Vendored dependencies
│   └── lib/perl5/                # Bundled CPAN modules
└── .planning/                    # GSD planning documents
    └── codebase/                 # Architecture/structure docs
```

## Directory Purposes

**lib/CallBackery:**
- Purpose: Core application logic and plugin system
- Contains: Perl modules implementing backend services, plugins, and configuration
- Key files: CallBackery.pm (Mojolicious app), RpcService.pm (API handler), Abstract.pm (plugin base)

**lib/CallBackery/GuiPlugin:**
- Purpose: Extensible plugin framework for UI components
- Contains: Base classes for forms, tables, card lists, HTML displays, and actions
- Key files: Abstract.pm (parent class), AbstractForm.pm, AbstractTable.pm
- Pattern: All plugins inherit from Abstract, override screenCfg() to define UI layout

**lib/CallBackery/qooxdoo/callbackery/source:**
- Purpose: Frontend Rich Internet Application built with Qooxdoo framework
- Contains: JavaScript classes for UI, data models, and client-side logic
- Key structure: class/callbackery/{ui, data, util, theme, locale, test}
- Build output: Compiled files go to lib/CallBackery/qooxdoo/callbackery/build/

**t/**
- Purpose: Automated testing
- Contains: Test scripts for integration testing (basic.t, invalidPlugin.t)
- Configuration: Test config in t/callbackery.cfg points to test database

**etc/**
- Purpose: Deployment configuration
- Contains: callbackery.cfg main config file defining plugins, database, backend settings
- Format: Custom INI-like format parsed by Config::Grammar::Dynamic

**thirdparty/lib/perl5:**
- Purpose: Bundled Perl module dependencies
- Generated: Via carton/cpanm during deployment
- Not committed: Build artifacts in work/ directory excluded

## Key File Locations

**Entry Points:**
- `lib/CallBackery.pm`: Mojolicious app class - defines startup() route configuration
- `lib/CallBackery/Controller/RpcService.pm`: JSON-RPC service handler - all frontend API calls flow through allow_rpc_access()
- `lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/Application.js`: Qooxdoo main app - initializes UI and loads base config

**Configuration:**
- `lib/CallBackery/Config.pm`: Configuration parsing and validation
- `etc/callbackery.cfg`: Main application config file (plugin definitions, database path, etc.)
- Grammar definitions: Each plugin defines its own config grammar in GuiPlugin subclasses

**Core Logic:**
- `lib/CallBackery/User.pm`: User authentication, session management, permission checks
- `lib/CallBackery/Database.pm`: Database utility methods (map2sql, fetchRow, updateOrInsertData)
- `lib/CallBackery/Controller/RpcService.pm`: RPC method handlers (login, getPluginConfig, processPluginData)
- `lib/CallBackery/GuiPlugin/Abstract.pm`: Base plugin class with core plugin framework

**Testing:**
- `t/basic.t`: Integration tests for ping, doc routes, and data cleaning
- `t/callbackery.cfg`: Test configuration (same structure as etc/callbackery.cfg)
- Test data: Fixtures in callbackery.cfg.secret and inline test plugins

## Naming Conventions

**Files:**
- Perl modules: PascalCase with .pm extension (e.g., RpcService.pm, AbstractForm.pm)
- JavaScript classes: PascalCase with .js extension (e.g., Application.js, Server.js)
- Tests: lowercase_with_underscores.t (e.g., basic.t, invalidPlugin.t)
- Config files: lowercase_with_underscores.cfg (e.g., callbackery.cfg)

**Directories:**
- Perl package dirs: PascalCase matching module hierarchy (CallBackery/GuiPlugin/)
- Frontend structure: lowercase with hyphens for Qooxdoo namespaces (callbackery/ui/form/)
- Feature-specific: Plural for collections (templates, resources, commands, controllers)

**Perl Packages:**
- Root: CallBackery
- Controllers: CallBackery::Controller::*
- Plugins: CallBackery::GuiPlugin::*
- Commands: CallBackery::Command::*
- Models: CallBackery::Model::*
- Utilities: CallBackery::* (Config, User, Database, Exception, Translate)

**Qooxdoo Classes:**
- Namespace: callbackery.*
- UI: callbackery.ui.* (Desktop, TabView, Header, etc.)
- Data: callbackery.data.* (Server, Config, models)
- Utilities: callbackery.util.* (formatters, helpers)
- Format utilities: callbackery.util.format.*

## Where to Add New Code

**New Plugin (Most Common):**
1. Create new file in `lib/CallBackery/GuiPlugin/MyPlugin.pm`
2. Extend appropriate base class: AbstractForm, AbstractTable, AbstractCardlist, AbstractHtml, or AbstractAction
3. Define config grammar via grammar() method
4. Implement screenCfg() for UI layout
5. Implement getData()/processData()/validateData() for business logic
6. Register in etc/callbackery.cfg under PLUGIN section with instance name and tab-name
7. Add tests to `t/` directory as MyPlugin.t

**New Frontend Component:**
1. Create new Qooxdoo class in `lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/ui/`
2. Extend appropriate Qooxdoo base class (qx.ui.container.Composite, qx.ui.form.*, etc.)
3. Follow qx.Class.define() pattern with extend, construct, members, properties
4. Access backend via callbackery.data.Server.getInstance()
5. Use callbackery.ui.Desktop.getInstance() to access main application container

**New Utility/Service:**
- Backend: Create in `lib/CallBackery/` as new .pm module, use Mojo::Base -base
- Frontend: Create in `lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/util/`
- Pattern: Expose via static getInstance() singleton pattern when appropriate

**Database Operations:**
- Use Database.pm helper methods: fetchRow(), fetchValue(), updateOrInsertData(), insertIfNew()
- Or use mojoSqlDb() to access raw Mojo::SQLite database handle
- Always use quote_identifier() for table/column names in SQL

**New API Endpoint:**
- Add new route in `lib/CallBackery.pm` startup() method
- Or add new RPC method to `lib/CallBackery/Controller/RpcService.pm`
- Recommended: Use RPC for consistency (single /QX-JSON-RPC endpoint)
- Include in allow_rpc_access() whitelist with appropriate access level (1=public, 2=authenticated, 3=plugin-dependent)

## Special Directories

**lib/CallBackery/qooxdoo/callbackery/cache/:**
- Purpose: Build cache for Qooxdoo compiler
- Generated: By qooxdoo compiler during build
- Committed: No (regenerated on build)

**lib/CallBackery/qooxdoo/callbackery/build/:**
- Purpose: Compiled frontend application
- Generated: By qooxdoo compiler during build
- Committed: No (regenerated on build)

**thirdparty/work/:**
- Purpose: Temporary CPAN build artifacts
- Generated: During dependency installation
- Committed: No (build temporary)

---

*Structure analysis: 2026-01-22*
