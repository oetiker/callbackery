# Coding Conventions

**Analysis Date:** 2026-01-22

## Naming Patterns

**Files:**
- Perl modules use `.pm` extension
- File names match package names with `::` converted to `/` (e.g., `CallBackery::User` → `CallBackery/User.pm`)
- PascalCase for module/package names (e.g., `CallBackery`, `RpcService`, `AbstractForm`)
- Lowercase with underscores for script files in `bin/` directory

**Functions/Methods:**
- camelCase for method names (e.g., `formData()`, `formPhase()`, `loginName`, `isUserAuthenticated`)
- camelCase for subroutines with descriptive action verbs (e.g., `dataCleaner()`, `logRpcCall()`, `validatePluginData()`)
- Private-like methods often use leading underscore convention but not enforced (e.g., `$self->{_lx}` in Translate.pm)
- Getter/setter patterns use attribute names directly (e.g., `$self->userId`, `$self->user`)

**Variables:**
- Lexical variables use lowercase with underscores (e.g., `$user_id`, `$config_hash`, `$db_handle`)
- Hash keys use lowercase with hyphens in config context (e.g., `tab-name`, `log_file`, `cfg_db`)
- Database identifiers use snake_case prefixed with table name (e.g., `cbuser_id`, `cbuser_login`)
- Instance variables stored in `$self->{_var}` for private data (e.g., `$self->{_lx}` for locale hash)

**Types/Classes:**
- Package names use PascalCase (e.g., `CallBackery`, `Exception`, `Config`, `Database`)
- Base class names use "Abstract" prefix for plugin base classes (e.g., `AbstractForm`, `AbstractTable`, `AbstractAction`)
- Namespace structure: `CallBackery::{Component}::{Type}` (e.g., `CallBackery::GuiPlugin::AbstractForm`, `CallBackery::Controller::RpcService`)

## Code Style

**Formatting:**
- Indentation: 4 spaces (per Emacs CPerl mode and vi modelines: `sw=4`)
- No tabs; spaces only
- Line length: No strict limit observed, but prefer readability
- Trailing whitespace removed
- Braces on same line for control structures: `if (...) { ... }`

**Editor Configuration:**
- Files end with Emacs modeline and vi modeline:
```perl
# Emacs Configuration
#
# Local Variables:
# mode: cperl
# eval: (cperl-set-style "PerlStyle")
# mode: flyspell
# mode: flyspell-prog
# End:
#
# vi: sw=4 et
```
- This sets Emacs to cperl-mode with PerlStyle, enables spell-checking, and vi to 4-space indents

**Linting:**
- No formal linting tool configured (no .perlcriticrc)
- Convention follows Perl best practices:
  - `use strict;` and `use warnings;` in traditional modules
  - Modern Mojo modules use `use Mojo::Base` which includes strict and warnings
  - `autodie` used in modules that perform file operations

## Import Organization

**Standard Order:**
1. Pragmas: `use strict;`, `use warnings;`
2. Mojo framework core: `use Mojo::Base ...`
3. Standard Perl libraries: `use Carp`, `use Scalar::Util`, etc.
4. Mojo utilities: `use Mojo::JSON`, `use Mojo::Util`, etc.
5. Third-party CPAN modules: `use Config::Grammar`, `use JSON::Validator`, etc.
6. Local CallBackery modules: `use CallBackery::*`
7. Exporter declarations: `use Exporter 'import'; @EXPORT_OK = ...`
8. Overload operators: `use overload (...)`

**Example from `CallBackery::Controller::RpcService`:**
```perl
use Mojo::Base qw(Mojolicious::Plugin::Qooxdoo::JsonRpcController),
    -signatures,-async_await;
use CallBackery::Exception qw(mkerror);
use CallBackery::Translate qw(trm);
use Mojo::JSON qw(encode_json decode_json from_json);
use Syntax::Keyword::Try;
use Scalar::Util qw(blessed weaken);
```

**Path Aliases:**
- No formal path aliases configured in build system
- Relative paths use `FindBin::Bin` for test setup:
```perl
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';
```

## Error Handling

**Patterns:**
- `die` with string message for fatal errors: `die "message"`
- `die` with exception object: `die mkerror(code, "message")`
- `croak` from Carp for die at caller's location: `croak "message"`
- `confess` for stack trace: rarely used, in `CallBackery::User` only
- `warn` for non-fatal issues: `warn "message"`
- Exception objects created with `CallBackery::Exception::mkerror(code, message)`

**Error Codes:**
- Custom error codes used in `mkerror(code, message)` calls:
  - Code 9999: Generic/unknown errors (e.g., "Couldn't process request", "unknown export type")
  - Code 3456: Configuration errors (e.g., "cardCfg must be defined in child plugin class")
  - Code 22: Bad error (example in Exception.pm docs)
  - Codes 1-3: RPC access levels in allow_rpc_access()

**Try-Catch:**
- Modern modules use `Syntax::Keyword::Try` for structured exception handling
- Traditional modules use `eval { ... } if ($@) { ... }` pattern
```perl
eval { die mkerror(22,'Bad Error'); }
if ($@){
    print "Code: ".$@->code()." Message: ".$@->message()."\n"
}
```

## Logging

**Framework:** Mojo::Log (built into Mojolicious)

**Access Pattern:**
- Via controller: `$self->log->debug("message")`
- Via app: `$self->app->log->debug("message")`
- Via user object: `$self->user->log->debug("message")`

**Log Levels Used:**
- `debug()`: Detailed diagnostic information (e.g., RPC call logging with `CALLBACKERY_RPC_LOG`)
- `error()`: Error conditions (e.g., "Cannot read secrets file")
- `warn()`: Warning conditions (e.g., "Failed to load Plugin")
- Methods chain calls: `$self->log->debug(...)->warn(...)`

**Patterns:**
- RPC call logging to ENV `CALLBACKERY_RPC_LOG`: When set, logs all RPC calls with sanitized data
- Data sanitization: Passwords and fields matching `(?i)(?:password|_pass)` replaced with `'xxx'` in logs
- User identification: Log entries include userId and remote address: `[$userId|$remoteAddr] CALL method(json_data)`

## Comments

**When to Comment:**
- Complex algorithms or non-obvious logic (e.g., "properly figure your own path when running under fastcgi")
- Security-related decisions (e.g., "prevent click jacking", "the browser should obey the servers settings")
- Voodoo/workarounds with explanation (e.g., dummy login screen for browser password autofill)
- Historical context in HISTORY section
- TODO and FIXME markers for future work (rarely used; not enforced)

**Comment Style:**
- Single-line comments: `# comment text`
- Block comments: Multiple lines starting with `#`
- No inline comments preferred; comments on preceding lines
- VCS comment format: `# $Id: File.pm 539 2013-12-09 22:28:11Z oetiker $`

**Pod/TSDoc:**
- Extensive POD (Plain Old Documentation) in Perl style:
  - `=head1 NAME`: Module name and brief description
  - `=head1 SYNOPSIS`: Usage example
  - `=head1 DESCRIPTION`: Detailed description
  - `=head2 methodName`: Individual method documentation
  - `=item` for list items
  - `=over`/`=back` for lists
  - Inline method parameter documentation
  - Link syntax: `L<Module::Name>` for cross-references
  - Code examples in verbatim blocks (indented)
- Pod format (not JSDoc)
- Pod included inline with code; extracted by Pod::Simple tools

**Example Pod Structure (from `CallBackery::Database`):**
```perl
=head1 NAME

CallBackery::Database - database access helpers

=head1 SYNOPSIS

 use CallBackery::Database;
 my $db = CallBackery::Database->new(app=>$self->config);

=head2 map2sql(table,data)

Provide two hash pointers and quote the field names...

=cut
```

## Function Design

**Size Guidelines:**
- No strict line limit enforced
- Favor readability over brevity
- Complex logic broken into helper methods
- Database operations often multi-line with clear variable names

**Parameters:**
- Method parameters passed via constructor-style `->new(key => value)` (Mojo::Base)
- Subroutine parameters often positional: `sub method { my ($self, $arg1, $arg2) = @_ }`
- Signature-style parameters (with `-signatures`): `sub method ($self, $arg1, $arg2) { ... }`
- Hash/array refs preferred for multiple related parameters
- Default values via `has attr => sub { ... }` pattern

**Return Values:**
- Scalar context: Single value or undef
- List context: Multiple values returned as list
- Hash refs: Configuration/data structures returned as hash refs
- Array refs: Collections returned as array refs
- Method chaining supported in some classes (e.g., Test::Mojo fluent interface)
- `undef` returned for missing values (not empty string or zero)

**Method Attributes (Mojo::Base style):**
```perl
has 'attributeName';                          # Basic attribute
has attributeName => 'default_value';         # With default
has attributeName => sub { ... };             # With lazy default
has attributeName => sub { ... }, weak => 1;  # Weak reference
```

## Module Design

**Exports:**
- Most modules do not export functions by default
- Specific exports via `@EXPORT_OK` for utility modules:
  - `CallBackery::Exception` exports `mkerror`
  - `CallBackery::Translate` exports `trm`
- Usage: `use Module qw(function1 function2)`

**Inheritance:**
- Single inheritance using `use Mojo::Base 'ParentClass'`
- Multiple base classes: `use Mojo::Base qw(Class1 Class2)`
- Plugin pattern: GuiPlugin classes inherit from Abstract base classes
- Controller pattern: `RpcService` inherits from `Mojolicious::Plugin::Qooxdoo::JsonRpcController`

**Barrel Files:**
- Not used; direct module imports from full paths
- Each module file contains one package

---

*Convention analysis: 2026-01-22*
