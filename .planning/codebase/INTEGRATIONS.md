# External Integrations

**Analysis Date:** 2026-01-22

## APIs & External Services

**RPC Services:**
- JSON-RPC 2.0 endpoint available at `/QX-JSON-RPC` (tested in `t/basic.t`)
  - Service routing via `lib/CallBackery/Controller/RpcService.pm`
  - Used for frontend-to-backend communication

**Documentation API:**
- Documentation endpoint at `/doc` (integrated in CallBackery.pm)
- Plugin loading via `lib/CallBackery/Plugin/Doc.pm`

## Data Storage

**Database:**
- SQLite 3.x (via Mojo::SQLite driver)
  - Connection configured in `lib/CallBackery/Database.pm`
  - Connection string: `BACKEND.cfg_db` in config file
  - Default: `callbackery.db` (see `t/callbackery.cfg`)
  - Automatic schema initialization via `dbsetup.sql`
  - Foreign keys enabled by default
  - UTF-8 unicode support configured

**Tables:**
- `cbuser` - User account storage (queried in `lib/CallBackery/User.pm`)
  - Fields: `cbuser_id`, `cbuser_login`

**File Storage:**
- Local filesystem only
- Configuration images/logos stored relative to config
- Temporary/cache files managed via Mojo::File

**Caching:**
- None detected - application uses direct database queries

## Authentication & Identity

**Auth Provider:**
- Custom implementation in `lib/CallBackery/User.pm`
- Session-based authentication

**Auth Mechanism:**
- Basic auth via configuration: `sesame_user` and `sesame_pass` (HMAC-SHA1 hashed)
- Cookie-based session persistence: `cookieConf` property stores user ID
- HMAC-SHA1 signature validation using `Mojo::Util::hmac_sha1_sum()`

**User Rights:**
- Role-based access control via `may()` method in `lib/CallBackery/User.pm`
- User objects provide `id`, `werk` (work/role), and permission checking
- Special system users:
  - `__CONSOLE` - Config console mode
  - `__CONFIG` - Backup/restore tasks
  - `__ROOT` - Bootstrap user when no users exist

**Session Management:**
- User ID stored in `u` cookie field via `cookieConf` property
- User info cached in `userInfo` property
- Session validation on each request

## Monitoring & Observability

**Error Tracking:**
- Custom exception handling via `lib/CallBackery/Exception.pm`
- Exception creation: `CallBackery::Exception::mkerror()` function

**Logs:**
- Mojolicious logging framework (accessible via `$app->log`)
- RPC logging controlled by `CALLBACKERY_RPC_LOG` environment variable (debug mode)
- Log output configured via Mojolicious app logger
- User actions tracked via `$db->userName()` set during authentication

**Debug/Testing:**
- Data cleaner for redacting sensitive information: `passMatch()` in controller (tested in `t/basic.t`)
- Default password patterns redacted as `xxx` in logs

## CI/CD & Deployment

**Hosting:**
- Developed for deployment via Mojolicious application server
- Can use built-in `morbo` (development) or `hypnotoad` (production) servers
- Reverse proxy setup recommended for production

**CI Pipeline:**
- Travis CI integration (config in `.travis.yml.offline`)
- Perl versions tested: 5.24, 5.26, 5.28
- Coverage tracking via Devel::Cover and Coveralls
- Build steps:
  1. Install coverage reporter: `cpanm Devel::Cover::Report::Coveralls`
  2. Run tests with coverage: `cover -test -report coveralls`
  3. Build dependencies: `perl Makefile.PL && make thirdparty`
  4. Run test suite: `make test`

**Package Distribution:**
- CPAN packaging via CPAN::Uploader
- Version from `lib/CallBackery.pm` (currently 0.56.6)

## Environment Configuration

**Required Environment Variables:**
- `CALLBACKERY_CONF` - Path to configuration file (defaults to `etc/callbackery.cfg`)
- `CALLBACKERY_RPC_LOG` - Enable RPC method call/return logging (debug mode)
- `CB_CFG_OVERRIDE_*` - Override any config value via environment (pattern: `CB_CFG_OVERRIDE_SECTION_KEY`)
  - Example: `CB_CFG_OVERRIDE_BACKEND_cfg_db='dbi:SQLite:dbname=/tmp/cb.db'`
  - Non-alphanumeric characters converted to underscores
  - Only can override existing config values

**Secrets Location:**
- Secret key stored in `.secret` file next to config file
- File permissions: 0600 on creation, 0400 after generation
- Auto-generated if missing (random 128-bit hex value)
- Used for session/request signing

## Webhooks & Callbacks

**Incoming:**
- RPC service endpoint: `/QX-JSON-RPC`
  - Accepts JSON-RPC 2.0 requests from frontend
  - Routes to service methods based on `service` and `method` fields

**Outgoing:**
- No detected outgoing webhook integrations
- Application is passive receiver of requests

## Configuration Schema

**Supported Sections:**
- `BACKEND` - Backend configuration
  - `cfg_db` - Database connection string
  - `sesame_user` - Auth username
  - `sesame_pass` - Auth password (HMAC-SHA1)

- `FRONTEND` - Frontend configuration
  - `title` - Application title
  - `logo` - Logo image path
  - `logo_small` - Small logo for navigation
  - `company_name` - Organization name
  - `company_url` - Organization website

- `FRONTEND-COLORS` - Optional color scheme customization
  - Themeable UI elements (buttons, text, borders)

- `PLUGIN:*` - Plugin configurations
  - `module` - Plugin module name
  - `type` - Plugin type (add, edit, show, etc.)
  - `tab-name` - UI tab label
  - `mode` - Operating mode (init, normal, etc.)

## Data Format Standards

**JSON Schema Validation:**
- All configuration validated against JSON Schema in `lib/CallBackery/Model/ConfigJsonSchema.pm`
- Schema embedded in `config-schema.yaml` data section

**JSON-RPC Format:**
- Standard JSON-RPC 2.0 protocol
- Request fields: `id`, `service`, `method`, `params`
- Response fields: `id`, `result` or `error`

---

*Integration audit: 2026-01-22*
