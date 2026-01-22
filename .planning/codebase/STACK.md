# Technology Stack

**Analysis Date:** 2026-01-22

## Languages

**Primary:**
- Perl 5.22+ - Core application language, used throughout `lib/CallBackery/` modules

**Secondary:**
- JavaScript/Qooxdoo - Frontend UI framework via Mojolicious::Plugin::Qooxdoo
- YAML - Configuration files
- SQL - SQLite database queries

## Runtime

**Environment:**
- Perl 5.22.0 or higher (specified in `Makefile.PL`)

**Package Manager:**
- CPAN (Comprehensive Perl Archive Network)
- Lockfile: `MYMETA.json` and `MYMETA.yml` present for dependency tracking

## Frameworks

**Core:**
- Mojolicious 9.33+ - Web framework for request handling and routing
- Mojolicious::Plugin::Qooxdoo 1.0.14+ - Desktop-like UI framework integration

**Configuration:**
- Config::Grammar::Dynamic 1.13+ - Dynamic configuration file parsing via `lib/CallBackery/Config.pm`

**Testing:**
- Test::More - Test framework (used in `t/basic.t`, `t/invalidPlugin.t`)
- Test::Mojo - Mojolicious testing utilities
- Test::Fatal - Exception testing utilities

**Build/Dev:**
- ExtUtils::MakeMaker - Perl module installation and building
- CPAN::Uploader - Package distribution (build requirement)

## Key Dependencies

**Critical:**
- Mojolicious 9.33 - Web framework powering entire application
- Future::AsyncAwait 0.65 - Async/await syntax support in `lib/CallBackery/Config.pm`, enables modern async patterns
- Syntax::Keyword::Try 0.29 - Try/catch exception handling syntax
- XS::Parse::Keyword 0.38 - Keyword extension support for Future::AsyncAwait and Syntax::Keyword::Try
- JSON::Validator 5.14 - JSON Schema validation in `lib/CallBackery/Model/ConfigJsonSchema.pm`
- YAML::XS 0.88 - YAML configuration file parsing in `lib/CallBackery/Model/ConfigJsonSchema.pm`

**Data Storage:**
- Mojo::SQLite - SQLite database driver used in `lib/CallBackery/Database.pm`

**Data Processing:**
- Text::CSV - CSV file parsing/generation
- Excel::Writer::XLSX - Excel file generation for reports
- Locale::PO 0.27 - Internationalization support via `lib/CallBackery/Translate.pm`

**Utilities:**
- Mojo::JSON - JSON encoding/decoding (core Mojolicious)
- Mojo::Util - Utility functions (HMAC-SHA1, base64, secure comparison)
- Mojo::File - File system operations
- Mojo::URL - URL parsing and manipulation
- Mojo::Promise - Promise/async operations
- Mojo::Loader - Dynamic module loading
- Pod::Simple::Text, Pod::Simple::HTML - Documentation generation
- Carp - Error handling/debugging
- Scalar::Util - Reference utilities
- Time::HiRes - High-resolution timing

## Configuration

**Environment:**
- Configuration files in YAML format (loaded via `lib/CallBackery/Model/ConfigJsonSchema.pm`)
- Environment variable overrides: `CB_CFG_OVERRIDE_*` pattern (documented in `ConfigJsonSchema.pm`)
- Main config file location controlled by `CALLBACKERY_CONF` environment variable or defaults to `etc/callbackery.cfg`

**Key Configs Required:**
- `BACKEND.cfg_db` - SQLite database path (default via schema)
- `BACKEND.sesame_user` - Basic auth username
- `BACKEND.sesame_pass` - HMAC-SHA1 hashed password
- `FRONTEND.title` - Application title
- `FRONTEND.logo` - Logo image path
- `FRONTEND.company_name` - Company name
- `PLUGIN.*` - Plugin configuration sections

**Build:**
- `Makefile.PL` - ExtUtils::MakeMaker configuration
- `MANIFEST` - Package file manifest
- `dist.sh` - Distribution build script

## Platform Requirements

**Development:**
- Perl 5.22+
- Standard UNIX build tools (make, curl for thirdparty dependencies)
- git (for version control)
- CPAN tools (cpanm for installing dependencies)

**Production:**
- Perl 5.22+
- SQLite 3.x
- Mojolicious application server (can use built-in Mojo server or reverse proxy)
- Web server with reverse proxy (nginx, Apache recommended for production)
- Filesystem write access for database and logs

## Database

**Type:** SQLite 3.x
**Connection:** Via `Mojo::SQLite` driver configured in `lib/CallBackery/Database.pm`
**Initialization:** Automatic migrations via `dbsetup.sql` (embedded in Database.pm)
**Features:** Foreign key constraints enabled by default

## Special Notes

- Application uses locale `C` for numeric and time operations to prevent regional formatting issues (see `lib/CallBackery.pm`)
- Test configuration expects SQLite database at path specified in config
- Third-party dependencies cached in `thirdparty/` directory for offline builds
- Multiple test files validate core functionality in `t/` directory

---

*Stack analysis: 2026-01-22*
