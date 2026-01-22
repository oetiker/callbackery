# Testing Patterns

**Analysis Date:** 2026-01-22

## Test Framework

**Runner:**
- Test::More (Perl standard)
- Test::Mojo (Mojolicious web testing)
- Version: No explicit pinned versions; relies on Makefile.PL dependencies
- Config: `test => {TESTS => 't/*.t'}` in `Makefile.PL`

**Assertion Library:**
- Test::More built-in assertions: `ok()`, `is()`, `isnt()`, `like()`, `unlike()`
- Test::Mojo fluent assertions: `->status_is()`, `->content_like()`, `->json_is()`
- Test::Fatal used (listed in Makefile.PL)
- Custom assertions not implemented; standard Test::More used

**Run Commands:**
```bash
make test                 # Run all tests (via Makefile)
prove t/                  # Run all test files
perl -I lib t/basic.t     # Run single test
perl -Ilib -It/lib t/basic.t   # With test library path
```

## Test File Organization

**Location:**
- Co-located: Tests in `t/` directory at project root
- One test file per feature/component
- Test files named descriptively: `basic.t`, `invalidPlugin.t`

**Naming:**
- Pattern: `{feature}.t`
- All test files reside in `/home/oetiker/checkouts/callbackery/t/`
- Current test files:
  - `basic.t` - Basic application tests (RPC ping, doc endpoints)
  - `invalidPlugin.t` - Plugin error handling tests

**Structure:**
```
callbackery/
├── t/
│   ├── basic.t                    # Core functionality tests
│   ├── invalidPlugin.t            # Error handling tests
│   ├── callbackery.cfg            # Test configuration file
│   └── callbackery.cfg.secret     # Test secret file
├── thirdparty/
│   └── lib/perl5/                 # Test dependencies
└── lib/
    └── CallBackery/
```

## Test Structure

**Suite Organization:**

Test files use imperative style with chained assertions:

```perl
use Test::More;
use Test::Mojo;

$ENV{CALLBACKERY_CONF} = $FindBin::Bin.'/callbackery.cfg';

my $t = Test::Mojo->new('CallBackery');

# RPC call test
$t->post_ok('/QX-JSON-RPC' => json => {
    id => 1,
    service => 'default',
    method => 'ping'
})
  ->status_is(200)
  ->content_type_is('application/json; charset=utf-8')
  ->json_is({id => 1, result => "pong"});

done_testing();
```

**Patterns:**

1. **Setup Pattern:**
   - Set test config via environment variable: `$ENV{CALLBACKERY_CONF} = $FindBin::Bin.'/callbackery.cfg'`
   - Create test app instance: `my $t = Test::Mojo->new('CallBackery')`
   - Initialize Mojo event loop if needed
   - Register event listeners: `$t->app->log->on(message => sub { ... })`

2. **Teardown Pattern:**
   - No explicit teardown; test cleanup via scope destruction
   - `done_testing()` at end of file marks completion
   - Exit code typically 0 on success, 1 on failure

3. **Assertion Pattern:**
   - Method chaining on Test::Mojo object: `$t->assertion()->assertion()->...`
   - Sequential assertions on same HTTP transaction
   - Multiple loop iterations for repeated tests

**Example from basic.t:**
```perl
# Loop to test multiple times
for (1..2){
    $t->post_ok('/QX-JSON-RPC' => json => {
        id => 1,
        service => 'default',
        method => 'ping'
    })
      ->status_is(200)
      ->content_type_is('application/json; charset=utf-8')
      ->json_is({id => 1,result => "pong"});

    $t->get_ok('/doc')
      ->content_like('/CallBackery::Index/')
      ->status_is(200);

    $ENV{CALLBACKERY_RPC_LOG}=1;
}
```

## Mocking

**Framework:** Manual mocking via package creation

**Patterns:**

Tests create mock classes inline in the test file:

```perl
# From basic.t
package p1;
use Mojo::Base qw(CallBackery::Controller::RpcService);
sub passMatch {
    qr{lalala};
};
1;
```

Then instantiate the mock:
```perl
my $c = p1->new(app => $t->app);
$c->dataCleaner($data);
is ($data->{k}{lalala},'xxx','pass clean check');
```

**What to Mock:**
- Controller subclasses to test inherited behavior
- Override specific methods to test isolation (e.g., `passMatch()` regex)
- Create test-specific plugin implementations to verify plugin API
- Use test config files instead of mocking the Config module

**What NOT to Mock:**
- Database: Use test database (SQLite in-memory or test db)
- HTTP transport: Use Test::Mojo for full HTTP stack testing
- Event loop: Let Mojolicious handle it
- Logging: Capture via event listener, don't mock

## Fixtures and Factories

**Test Data:**

No formal factory pattern implemented. Data created inline:

```perl
my $data = {
    k => { lalala => '123' }
};

my $login = ['tobi','secret'];
```

**Location:**
- Test data defined in test files: inline hashes, arrays, scalars
- Test configuration: `t/callbackery.cfg` (shared across tests)
- Test secrets: `t/callbackery.cfg.secret` (generated, read-only)

**Configuration Files:**

`t/callbackery.cfg` - Test environment configuration:
```
*** BACKEND ***
[backend config]

*** FRONTEND ***
[frontend config]

*** PLUGIN ***
[plugin configs]
```

Test setup loads this via:
```perl
$ENV{CALLBACKERY_CONF} = $FindBin::Bin.'/callbackery.cfg';
```

## Coverage

**Requirements:**
- No code coverage tool configured
- No coverage target enforced
- No coverage reports generated

**View Coverage:**
- Not applicable; coverage not measured
- Would require: `perl -MDevel::Cover ... && cover` (not in dependencies)

## Test Types

**Unit Tests:**
- Scope: Individual method behavior
- Approach: Direct method calls on test instances
- Example: `$c->dataCleaner($data)` then assertion on result
- Not fully isolated; uses real Mojo::Base objects

**Integration Tests:**
- Scope: Full RPC stack (HTTP, JSON encoding, routing, application logic)
- Approach: HTTP POST to `/QX-JSON-RPC` endpoint via Test::Mojo
- Framework: Test::Mojo provides full application integration
- Example: Test RPC method ping, error handling, plugin processing

**E2E Tests:**
- Framework: Not used
- Would require: Selenium or similar
- Not configured in Makefile.PL or test setup

## Test Patterns in Code

**Async Testing:**

Not explicitly used in current tests. When needed, Mojo::Promise pattern:

```perl
my $promise = $app->some_async_method();
$promise->then(sub {
    my $result = shift;
    # assertions here
})->catch(sub {
    # error handling
})->wait;
```

Or with Test::Mojo on async endpoints:
```perl
$t->get_ok('/async-endpoint')->status_is(200)->json_is(expected);
```

**Error Testing:**

Testing error conditions via RPC responses:

```perl
$t->post_ok('/QX-JSON-RPC' => json => {
    service => 'default',
    method=> 'processPluginData',
    id => 1,
    params => [
        "undefinedPlugin", { ... }, { ... }
    ]
})
    ->status_is(200, 'processPluginData returns 200')
    ->json_is('' => {
        id => 1,
        error => {
            origin  => 2,
            code    => 9999,
            message => "Couldn't process request",
        }
    }, 'Got correct error handling from JsonRPcController');
```

## Test Utilities

**Helper Functions:**

Custom test helpers in RpcService for logging verification:

```perl
$t->app->log->on(message => sub {
    my ($log, $level, @lines) = @_;
    if ($ENV{CALLBACKERY_RPC_LOG}){
       if ($lines[0] =~ /CALL|RETURN/){
          like($lines[0],qr{UNKNOWN});
       }
    }
});
```

**Data Cleaner Testing:**

Tests verify password sanitization in logs:

```perl
my $login = ['tobi','secret'];
$c->dataCleaner($login,'login');
is ($login->[1],'xxx','pass special login check');
```

Verifies that sensitive fields are masked with 'xxx' during logging.

## Common Assertions

**Test::Mojo Assertions:**
- `->status_is(200)` - HTTP status code
- `->content_type_is('application/json; charset=utf-8')` - Content-Type header
- `->content_like(qr{pattern})` - Response body matches pattern
- `->json_is({expected})` - JSON response matches structure
- `->get_ok(path)` - GET request returns success
- `->post_ok(path, json => {...})` - POST request with JSON payload

**Test::More Assertions:**
- `is($actual, $expected, 'description')` - String/numeric equality
- `like($string, qr{pattern}, 'description')` - Regex match
- `ok($condition, 'description')` - Boolean assertion
- `done_testing()` - Mark end of tests

## Known Test Limitations

**Coverage Gaps:**
- No database migration/schema tests
- Limited plugin loading tests (only invalid plugin error case)
- No authentication/permission tests beyond basic checks
- No concurrent/load tests
- Limited form validation tests
- Export (CSV/XLSX) functionality minimally tested

**Test Configuration:**
- Hardcoded paths via `FindBin`: `$FindBin::Bin.'/../lib'`
- Depends on thirdparty/ directory being populated via `make thirdparty`
- Test database created fresh for each test run

---

*Testing analysis: 2026-01-22*
