# JSON-RPC 2.0 in mojolicious-plugin-qooxdoo — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JSON-RPC 2.0 support to the reusable `Mojolicious::Plugin::Qooxdoo` plugin, where it auto-detects qx1 vs 2.0 per request, and have CallBackery's controller inherit it.

**Architecture:** The plugin's `JsonRpcController::dispatch` gains a protocol-detection branch keyed on the presence of a `jsonrpc` member in the decoded request. A new `jsonRpc20` controller attribute records the mode; `renderJsonRpcResult` and `renderJsonRpcError` branch on it to emit either the legacy qx1 envelope or a strict 2.0 envelope. The legacy path is byte-for-byte unchanged, so existing consumers are unaffected (minor version bump 1.1.0). CallBackery requires the new plugin version and inherits the dispatcher — its controller carries no protocol overrides.

**Tech Stack:** Perl 5, Mojolicious, `Mojo::JSON`, `Test::Mojo`. Two repos:
- `PLUGIN` = `~/checkouts/mojolicious-plugin-qooxdoo` (fork `zaucker/`, branch `feature/jsonrpc-2.0`)
- `CB` = `/home/zaucker/checkouts/callbackery` (branch `feature/qooxdoo7-jsonrpc`, PR #242)

**Reference:** `docs/superpowers/specs/2026-06-11-jsonrpc-in-plugin-design.md`

---

## File Structure

**PLUGIN repo:**
- Modify: `lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm` — add `jsonRpc20` attribute; protocol detection in `dispatch`; mode-branching in `renderJsonRpcResult` / `renderJsonRpcError`; permissive params. Bump `$VERSION` → `1.1.0`.
- Modify: `lib/Mojolicious/Plugin/Qooxdoo.pm` — bump `$VERSION` → `1.1.0`.
- Modify: `Changes` — add 1.1.0 entry.
- Modify: `t/simple.t` — append JSON-RPC 2.0 assertions (success, error, named-params, version/method/transport guards). The existing qx1 assertions stay untouched as the regression guard.

**CB repo:**
- Modify: `lib/CallBackery/Controller/RpcService.pm` — carries no protocol overrides; inherits `dispatch`/`renderJsonRpcResult`/`renderJsonRpcError` from the plugin (matches master).
- Modify: `Makefile.PL` — dependency `'Mojolicious::Plugin::Qooxdoo' => '1.1.0'`.
- Modify: `CHANGES` — refine the breaking-change wording.

---

## Task 1: Set up the plugin fork and confirm a green baseline

**Files:** none modified (environment setup).

- [ ] **Step 1: Fork and clone the plugin**

```bash
gh repo fork oetiker/mojolicious-plugin-qooxdoo --clone=false --remote=false 2>/dev/null || true
cd ~/checkouts
rm -rf mojolicious-plugin-qooxdoo
git clone git@github.com:zaucker/mojolicious-plugin-qooxdoo.git
cd ~/checkouts/mojolicious-plugin-qooxdoo
git remote add upstream https://github.com/oetiker/mojolicious-plugin-qooxdoo.git
git fetch upstream --quiet
git checkout -b feature/jsonrpc-2.0 upstream/master
```

- [ ] **Step 2: Build the plugin's own thirdparty deps**

Run: `cd ~/checkouts/mojolicious-plugin-qooxdoo && perl Makefile.PL && make thirdparty`
Expected: completes; creates `thirdparty/lib/perl5` with `Test::Mojo` etc. (If `make thirdparty` fails on XS mismatch, `rm -rf thirdparty` and retry against the system perl — same gotcha as CallBackery.)

- [ ] **Step 3: Run the existing test suite (baseline must be green)**

Run: `cd ~/checkouts/mojolicious-plugin-qooxdoo && prove -lv t/simple.t`
Expected: all assertions PASS (qx1 echo, async, exceptions, GET Script transport). This is the regression baseline — every later task must keep it green.

- [ ] **Step 4: Commit the branch point (no-op marker)**

No commit needed yet — the branch already points at `upstream/master`. Proceed to Task 2.

---

## Task 2: Detect JSON-RPC 2.0 and render the success envelope

**Files:**
- Modify: `~/checkouts/mojolicious-plugin-qooxdoo/lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm`
- Test: `~/checkouts/mojolicious-plugin-qooxdoo/t/simple.t`

- [ ] **Step 1: Write the failing test** — append before `done_testing();` in `t/simple.t`:

```perl
# --- JSON-RPC 2.0 ---

# 2.0 positional-params success
$t->post_ok('/root/jsonrpc', json => {jsonrpc=>"2.0","id"=>1,"method"=>"echo","params"=>["hello"]})
  ->json_is('',{jsonrpc=>"2.0",id=>1,result=>'hello'},'2.0 success envelope')
  ->content_type_is('application/json; charset=utf-8')
  ->status_is(200);
```

- [ ] **Step 2: Run it to verify it fails**

Run: `prove -lv t/simple.t :: 2>&1 | grep -A3 '2.0 success'`
Expected: FAIL — without the change the controller treats the request as qx1, errors on the missing `service`, so the body is not the 2.0 envelope.

- [ ] **Step 3: Add the `jsonRpc20` attribute** — in `JsonRpcController.pm`, alongside the other `has` lines (after `has 'rpcParams';`):

```perl
has 'rpcParams';

# true when the current request used the JSON-RPC 2.0 envelope
has 'jsonRpc20';
```

- [ ] **Step 4: Add protocol detection + 2.0 request parsing in `dispatch`** — replace the whole block from `if (not defined $self->requestId){` down to (and including) the line `$self->methodName($method);` with:

```perl
    # Detect protocol: a 'jsonrpc' member selects strict JSON-RPC 2.0;
    # its absence keeps the legacy qooxdoo "qx1" behaviour intact.
    $self->jsonRpc20(defined $data->{jsonrpc} ? 1 : 0);

    if (not defined $self->requestId){
        my $error = "Missing 'id' property in JsonRPC request.";
        $log->error($error);
        $self->render(text => $error, status=>500);
        return;
    }

    my $method;
    if ($self->jsonRpc20) {
        # --- JSON-RPC 2.0 ---
        if ($data->{jsonrpc} ne '2.0') {
            my $error = "Invalid 'jsonrpc' version (must be \"2.0\").";
            $log->error($error);
            $self->render(text => $error, status=>500);
            return;
        }
        if ($self->crossDomain) {
            my $error = "JSON-RPC 2.0 requests must be POST.";
            $log->error($error);
            $self->render(text => $error, status=>500);
            return;
        }
        $method = $data->{method};
        if (not defined $method) {
            my $error = "Missing 'method' property in JsonRPC request.";
            $log->error($error);
            $self->render(text => $error, status=>500);
            return;
        }
    }
    else {
        # --- legacy qx1 ---
        # Check if service property is available
        $data->{service} or do {
            my $error = "Missing service property in JsonRPC request.";
            $log->error($error);
            $self->render(text => $error, status=>500);
            return;
        };
        # Check if method is specified in the request
        $method = $data->{method} or do {
            my $error = "Missing method property in JsonRPC request.";
            $log->error($error);
            $self->render(text => $error, status=>500);
            return;
        };
    }
    $self->methodName($method);
```

(`crossDomain` is already set true only on the GET path, so reusing it as the "is GET" signal is correct.)

- [ ] **Step 5: Guard the qx1-only service check inside the eval** — in `dispatch`, replace:

```perl
        die {
            origin => 1,
            message => "service $service not available",
            code=> 2
        } if not $self->service eq $service;
```

with:

```perl
        die {
            origin => 1,
            message => "service ".$data->{service}." not available",
            code=> 2
        } if not $self->jsonRpc20 and not $self->service eq $data->{service};
```

(The `my $service = ...` line was removed in Step 4, so reference `$data->{service}` directly.)

- [ ] **Step 6: Branch `renderJsonRpcResult` on the mode** — replace its body:

```perl
sub renderJsonRpcResult {
    my $self = shift;
    my $data = shift;
    my $reply = $self->jsonRpc20
        ? { jsonrpc => '2.0', id => $self->requestId, result => $data }
        : {                   id => $self->requestId, result => $data };
    $self->logRpcReturn(dclone($reply));
    $self->finalizeJsonRpcReply(encode_json($reply));
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `prove -lv t/simple.t 2>&1 | grep -E '2.0 success|Result:'`
Expected: `2.0 success envelope` PASS and overall `Result: PASS` (the qx1 assertions still pass).

- [ ] **Step 8: Commit**

```bash
cd ~/checkouts/mojolicious-plugin-qooxdoo
git add lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm t/simple.t
git commit -m "feat: detect JSON-RPC 2.0 envelope and render 2.0 result"
```

---

## Task 3: Render the JSON-RPC 2.0 error envelope

**Files:**
- Modify: `~/checkouts/mojolicious-plugin-qooxdoo/lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm`
- Test: `~/checkouts/mojolicious-plugin-qooxdoo/t/simple.t`

- [ ] **Step 1: Write the failing tests** — append before `done_testing();`:

```perl
# 2.0 access-denied error (origin folded into data, integer code)
$t->post_ok('/root/jsonrpc', json => {jsonrpc=>"2.0","id"=>1,"method"=>"test"})
  ->json_is('',{jsonrpc=>"2.0",id=>1,error=>{code=>6,message=>"rpc access to method test denied",data=>{origin=>1}}},'2.0 access-denied envelope')
  ->status_is(200);

# 2.0 application exception propagated (blessed code+message -> origin 2)
$t->post_ok('/root/jsonrpc', json => {jsonrpc=>"2.0","id"=>1,"method"=>"echo","params"=>[]})
  ->json_is('',{jsonrpc=>"2.0",id=>1,error=>{code=>123,message=>"Argument Required!",data=>{origin=>2}}},'2.0 exception envelope');
```

- [ ] **Step 2: Run to verify it fails**

Run: `prove -lv t/simple.t 2>&1 | grep -E '2.0 (access-denied|exception)'`
Expected: FAIL — current `renderJsonRpcError` always emits the qx1 shape (`{id,error:{origin,message,code}}`), not the 2.0 shape.

- [ ] **Step 3: Rewrite `renderJsonRpcError` to branch on the mode** — replace the whole sub:

```perl
sub renderJsonRpcError {
    my $self = shift;
    my $exception = shift;
    my ($origin, $message, $code);
    for (ref $exception){
        /HASH/ && $exception->{message} && do {
            $origin  = $exception->{origin} // 2;
            $message = $exception->{message};
            $code    = $exception->{code};
            last;
        };
        /.+/ && $exception->can('message') && $exception->can('code') && do {
            $origin  = 2;
            $message = $exception->message();
            $code    = $exception->code();
            last;
        };
        $self->log->error("Error while processing " . ($self->service // '') . "::" . $self->methodName . ": $exception");
        $origin  = 2;
        $message = "Couldn't process request";
        $code    = 9999;
    }
    $self->log->error("JsonRPC error sent to client: '$code: $message'");

    my $reply;
    if ($self->jsonRpc20) {
        # JSON-RPC 2.0: error.code must be an integer; non-standard 'origin'
        # is carried inside the permitted 'data' member.
        $reply = {
            jsonrpc => '2.0',
            id      => $self->requestId,
            error   => {
                code    => defined $code ? int($code) : 9999,
                message => $message,
                data    => { origin => $origin },
            },
        };
    }
    else {
        $reply = {
            id    => $self->requestId,
            error => { origin => $origin || 2, message => $message, code => $code },
        };
    }
    $self->finalizeJsonRpcReply(encode_json($reply));
}
```

- [ ] **Step 4: Run to verify it passes (and qx1 errors still match)**

Run: `prove -lv t/simple.t 2>&1 | grep -E '2.0 (access-denied|exception)|invalid service|invalid method|generic exception|Result:'`
Expected: the two new `2.0 …` assertions PASS, the legacy `json error for invalid service` / `invalid method` / `propagating generic exception` still PASS, overall `Result: PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm t/simple.t
git commit -m "feat: render JSON-RPC 2.0 error envelope (integer code, origin in data)"
```

---

## Task 4: Guard 2.0 version and transport

**Files:**
- Test: `~/checkouts/mojolicious-plugin-qooxdoo/t/simple.t` (implementation already added in Task 2 Step 4 — these tests lock it in)

- [ ] **Step 1: Write the tests** — append before `done_testing();`:

```perl
# wrong jsonrpc version is rejected
$t->post_ok('/root/jsonrpc', json => {jsonrpc=>"1.0","id"=>1,"method"=>"echo","params"=>["hi"]})
  ->content_like(qr/Invalid 'jsonrpc' version/,'2.0 version guard')
  ->status_is(500);

# 2.0 over GET (Script transport) is rejected
$t->get_ok('/root/jsonrpc?_ScriptTransport_id=1&_ScriptTransport_data={"jsonrpc":"2.0","id":1,"method":"echo","params":["hi"]}')
  ->content_like(qr/must be POST/,'2.0 POST-only guard')
  ->status_is(500);
```

- [ ] **Step 2: Run to verify they pass**

Run: `prove -lv t/simple.t 2>&1 | grep -E '2.0 (version|POST-only) guard|Result:'`
Expected: both PASS, overall `Result: PASS`. (The logic was added in Task 2; this task is pure test coverage.)

- [ ] **Step 3: Commit**

```bash
git add t/simple.t
git commit -m "test: cover JSON-RPC 2.0 version and POST-only guards"
```

---

## Task 5: Permissive params (array splat or named-object hashref)

**Files:**
- Modify: `~/checkouts/mojolicious-plugin-qooxdoo/lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm`
- Test: `~/checkouts/mojolicious-plugin-qooxdoo/t/simple.t`

- [ ] **Step 1: Write the failing test** — append before `done_testing();`. `echo` returns its first arg verbatim, so a named-object `params` must arrive as a single hashref and round-trip:

```perl
# 2.0 named (object) params are passed to the method as a single hashref
$t->post_ok('/root/jsonrpc', json => {jsonrpc=>"2.0","id"=>1,"method"=>"echo","params"=>{name=>"bob"}})
  ->json_is('',{jsonrpc=>"2.0",id=>1,result=>{name=>"bob"}},'2.0 named params reach method as hashref');
```

- [ ] **Step 2: Run to verify it fails**

Run: `prove -lv t/simple.t 2>&1 | grep -E 'named params|Result:'`
Expected: FAIL — the current invocation does `$self->$method(@{$self->rpcParams})`, which on a hashref throws "Not an ARRAY reference" (a 9999 error envelope), not the round-tripped hash.

- [ ] **Step 3: Make invocation permissive** — in `dispatch`, replace:

```perl
        $self->logRpcCall($method,dclone($self->rpcParams));

        # reply
        no strict 'refs';
        return $self->$method(@{$self->rpcParams});
```

with:

```perl
        $self->logRpcCall($method,dclone($self->rpcParams));

        # reply
        no strict 'refs';
        my $params = $self->rpcParams;
        if (ref $params eq 'ARRAY') {
            return $self->$method(@$params);          # positional params
        }
        elsif (ref $params eq 'HASH') {
            return $self->$method($params);           # named params -> single hashref
        }
        die {
            origin  => 1,
            message => "'params' must be an array or an object",
            code    => 4
        };
```

- [ ] **Step 4: Run to verify it passes**

Run: `prove -lv t/simple.t 2>&1 | grep -E 'named params|post request|async request|Result:'`
Expected: `named params …` PASS; the legacy array-param assertions (`post request`, `async request`) still PASS; overall `Result: PASS`.

- [ ] **Step 5: Commit**

```bash
git add lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm t/simple.t
git commit -m "feat: accept JSON-RPC 2.0 named (object) params as a hashref"
```

---

## Task 6: Version bump and changelog

**Files:**
- Modify: `~/checkouts/mojolicious-plugin-qooxdoo/lib/Mojolicious/Plugin/Qooxdoo.pm`
- Modify: `~/checkouts/mojolicious-plugin-qooxdoo/lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm`
- Modify: `~/checkouts/mojolicious-plugin-qooxdoo/Changes`

- [ ] **Step 1: Bump `Qooxdoo.pm`** — change `our $VERSION = '1.0.14';` to:

```perl
our $VERSION = '1.1.0';
```

- [ ] **Step 2: Bump `JsonRpcController.pm`** — change `our $VERSION = '1.0.15';` to:

```perl
our $VERSION = '1.1.0';
```

(Note the pre-existing skew — the two files were out of sync at 1.0.14 / 1.0.15. This realigns them.)

- [ ] **Step 3: Add the `Changes` entry** — insert at the very top of `Changes`:

```
1.1.0 2026-06-11 00:00:00 +0100 Fritz Zaucker <fritz.zaucker@oetiker.ch>

 - support JSON-RPC 2.0 in addition to the legacy qooxdoo protocol; the
   dispatcher auto-detects the envelope (a 'jsonrpc' member selects 2.0).
   The 2.0 path drops the 'service' concept, is POST-only, returns
   {jsonrpc,id,result|error}, uses an integer error code, carries the
   non-standard 'origin' inside error.data, and accepts named (object)
   params as a single hashref. Legacy qx1 behaviour is unchanged.
 - realign $VERSION across Qooxdoo.pm and JsonRpcController.pm

```

(The maintainer's `make` release target restamps the date/author on release; the line above is a sensible placeholder.)

- [ ] **Step 4: Run the full suite once more**

Run: `cd ~/checkouts/mojolicious-plugin-qooxdoo && prove -lv t/simple.t t/source.t`
Expected: `Result: PASS` for both — all legacy qx1 assertions plus the new 2.0 assertions.

- [ ] **Step 5: Commit**

```bash
git add lib/Mojolicious/Plugin/Qooxdoo.pm lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm Changes
git commit -m "chore: release prep 1.1.0 (JSON-RPC 2.0 support)"
```

---

## Task 7: Push the branch and open the plugin PR

**Files:** none.

- [ ] **Step 1: Push the branch to the fork**

```bash
cd ~/checkouts/mojolicious-plugin-qooxdoo
git push -u origin feature/jsonrpc-2.0
```

- [ ] **Step 2: Open the PR against upstream**

```bash
gh pr create --repo oetiker/mojolicious-plugin-qooxdoo \
  --base master --head zaucker:feature/jsonrpc-2.0 \
  --title "Support JSON-RPC 2.0 (auto-detected) alongside the legacy protocol" \
  --body-file /tmp/mpq-pr-body.md
```

Write `/tmp/mpq-pr-body.md` first, summarizing: auto-detection rule, the 2.0 envelope/semantics, backward compatibility (qx1 path unchanged, existing tests green), permissive params, minor version bump, and that it pairs with CallBackery PR #242. End with the Claude Code attribution line.

- [ ] **Step 3: Record the PR URL**

Run: `gh pr view --repo oetiker/mojolicious-plugin-qooxdoo --json url -q .url`
Expected: prints the new PR URL. Note it for the CallBackery PR cross-reference.

---

## Task 8: CallBackery #242 — inherit from the plugin (local integration)

**Files:**
- Modify: `/home/zaucker/checkouts/callbackery/lib/CallBackery/Controller/RpcService.pm`
- Modify: `/home/zaucker/checkouts/callbackery/Makefile.PL`
- Modify: `/home/zaucker/checkouts/callbackery/CHANGES`

- [ ] **Step 1: Ensure `RpcService.pm` carries no protocol overrides**

`RpcService.pm` must inherit `dispatch`, `renderJsonRpcResult`, and `renderJsonRpcError` from the plugin — it defines none of them and does not `use Storable qw(dclone);`. It provides only the `%allow` map, `allow_rpc_access`, the password-cleaning `logRpcCall`/`logRpcReturn` overrides, and the RPC/upload/download methods (the controller's master shape).

- [ ] **Step 2: Verify the file matches master exactly**

Run: `cd /home/zaucker/checkouts/callbackery && git diff master -- lib/CallBackery/Controller/RpcService.pm | wc -l`
Expected: `0` (no diff — the controller carries no protocol overrides).

- [ ] **Step 3: Bump the plugin dependency in `Makefile.PL`** — change `'Mojolicious::Plugin::Qooxdoo' => '1.0.14',` to:

```perl
    'Mojolicious::Plugin::Qooxdoo' => '1.1.0',
```

- [ ] **Step 4: Stage the 1.1.0 plugin into CallBackery's thirdparty for local testing**

(Until 1.1.0 is on CPAN, copy the branch's modules over the vendored 1.0.14 copy — exactly what `make thirdparty` will fetch post-release.)

```bash
cp ~/checkouts/mojolicious-plugin-qooxdoo/lib/Mojolicious/Plugin/Qooxdoo.pm \
   /home/zaucker/checkouts/callbackery/thirdparty/lib/perl5/Mojolicious/Plugin/Qooxdoo.pm
cp ~/checkouts/mojolicious-plugin-qooxdoo/lib/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm \
   /home/zaucker/checkouts/callbackery/thirdparty/lib/perl5/Mojolicious/Plugin/Qooxdoo/JsonRpcController.pm
```

- [ ] **Step 5: Run CallBackery's RPC tests against the inherited dispatcher**

Run: `cd /home/zaucker/checkouts/callbackery && prove -l t/basic.t t/jsonrpc.t`
Expected: PASS. `t/jsonrpc.t` asserts the 2.0 success envelope (`{jsonrpc:"2.0",id:1,result:"pong"}`), the code-6 error envelope, and 500 on a non-2.0 body — all produced by the inherited plugin code, proving the inherited path is behavior-preserving.

- [ ] **Step 6: Refine the `CHANGES` breaking-change wording** — update the UNRELEASED entry to note the new property: the 2.0 dispatch now lives in `Mojolicious::Plugin::Qooxdoo` ≥ 1.1.0 (auto-detecting), so the CallBackery *backend* serves both old qx1 and new 2.0 frontends; the breaking part is the bundled 2.0-only `callbackery.data.Server`, so apps still upgrade frontend + backend together. Keep the existing note that `deprecated.qx.io.remote` removal is optional.

- [ ] **Step 7: Commit**

```bash
cd /home/zaucker/checkouts/callbackery
git add lib/CallBackery/Controller/RpcService.pm Makefile.PL CHANGES
git commit -m "refactor: inherit JSON-RPC 2.0 dispatch from Mojolicious::Plugin::Qooxdoo 1.1.0

RpcService inherits dispatch/renderJsonRpcResult/renderJsonRpcError from the
plugin (auto-detecting qx1 vs 2.0); the controller carries no protocol
overrides.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 8: Cross-link the PRs**

Update PR #242's body (via `gh api repos/oetiker/callbackery/pulls/242 -X PATCH -F body=@…`, since `gh pr edit` fails on this repo's Projects-classic deprecation) to reference the plugin PR and note the release-ordering dependency (plugin 1.1.0 must land on CPAN before #242's `Makefile.PL` bump resolves).

---

## Notes on sequencing

The `Makefile.PL` bump to `1.1.0` (Task 8 Step 3) only resolves from CPAN once the plugin PR (Task 7) is merged and released. Steps 4–5 validate the integration locally before that release. Do not run `make thirdparty` in CallBackery against a clean environment expecting 1.1.0 until the release exists — the staged copy in Step 4 is the interim.
