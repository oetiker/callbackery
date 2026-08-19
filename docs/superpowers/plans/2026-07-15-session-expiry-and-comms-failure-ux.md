# Session-expiry & communication-failure UX — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn AGW GUI session-expiry from a silent popup storm into one clean "Session Expired → Reload" prompt, keep first-login on the login dialog, and give server-unreachable / proxy-garbage failures bounded silent retry then a single "Connection problem" dialog.

**Architecture:** Backend distinguishes *not-logged-in* (code 6 → login dialog) from *expired session* (new code 7 → reload) via a per-request `sessionExpired` flag on `CallBackery::User`, and stops the generic-error escape by `eval`-guarding plugin instantiation in `allow_rpc_access`. Frontend `callbackery.data.Server` routes code 7 to a single deduped reload prompt, and classifies non-JSON-RPC failures as *communication errors* that auto-retry (idempotent reads only) before showing one Retry/Reload dialog.

**Tech Stack:** Perl / Mojolicious (`Test::Mojo`), qooxdoo 7.x JS (JSON-RPC 2.0 via `qx.io.jsonrpc.Client`).

## Global Constraints

- Primary repo: `callbackery` at v0.57.0 (JSON-RPC 2.0 / qooxdoo 7.x). The backend and frontend halves MUST ship in the same callbackery release.
- Session-expired RPC code is **7** (`RPC_SESSION_EXPIRED`); it MUST match the frontend's reserved code 7. Not-logged-in stays **6**.
- Only application (JSON-RPC `Protocol`) exceptions may trigger login/reload; a transport-namespace code that equals 6/7 must NOT. The `application` flag stays load-bearing.
- Auth stays stateless (signed `X-Session-Cookie` header). No server-side session store.
- Retry-safe method allowlist (idempotent, no writes): `ping`, `getBaseConfig`, `getUserConfig`, `getSessionCookie`, `getPluginConfig`, `getPluginData`, `validatePluginData`. `processPluginData`, `login`, `logout` are NOT retry-safe.
- Comms auto-retry: 3 attempts, ~1.3s fixed backoff (≈4s total), in named constants.
- Comments/identifiers in English.
- Run the Perl suite with 4 cores max: `HARNESS_OPTIONS=j4 prove -l t/`.

---

### Task 1: `sessionExpired` flag on `CallBackery::User`

**Files:**
- Modify: `lib/CallBackery/User.pm` (add the attribute near the other `has` declarations, e.g. after `loginName`)
- Test: `t/session_expiry.t` (new)

**Interfaces:**
- Produces: `CallBackery::User::sessionExpired` — a Mojo::Base attribute, default `0`, readable as `$user->sessionExpired` and settable as `$user->sessionExpired(1)`. Per-request (the User object is per-transaction). Consumed by Task 2 and by the appliance override (Task 6).

- [ ] **Step 1: Write the failing test**

Create `t/session_expiry.t`:

```perl
use FindBin;
use lib $FindBin::Bin.'/../thirdparty/lib/perl5';
use lib $FindBin::Bin.'/../lib';

use Mojo::Base -strict;
use Test::More;
use Test::Mojo;
use Mojo::Transaction::HTTP;

$ENV{CALLBACKERY_CONF} = $FindBin::Bin.'/callbackery.cfg';

my $t = Test::Mojo->new('CallBackery');

# --- Task 1: sessionExpired defaults to false and is settable ---
{
    my $tx = Mojo::Transaction::HTTP->new;
    $tx->req->method('POST');
    my $c = CallBackery::Controller::RpcService->new(tx => $tx, app => $t->app);
    my $u = CallBackery::User->new(app => $t->app, controller => $c);
    is($u->sessionExpired, 0, 'sessionExpired defaults to 0');
    $u->sessionExpired(1);
    is($u->sessionExpired, 1, 'sessionExpired is settable');
}

done_testing();
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /home/oetiker/checkouts/callbackery && HARNESS_OPTIONS=j4 prove -l t/session_expiry.t`
Expected: FAIL — `Can't locate object method "sessionExpired" via package "CallBackery::User"`.

- [ ] **Step 3: Add the attribute**

In `lib/CallBackery/User.pm`, add after the `loginName` attribute block:

```perl
=head2 sessionExpired

True when a validly-signed session cookie was presented but is too old. Distinct
from "not authenticated at all" (no/invalid cookie), which leaves this false. Set
by whichever layer detects expiry (e.g. a subclass' C<cookieConf> that enforces a
max cookie age); read by the RPC dispatcher to choose the session-expired signal
(code 7) over the login-required signal (code 6). Per-request.

=cut

has sessionExpired => 0;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /home/oetiker/checkouts/callbackery && HARNESS_OPTIONS=j4 prove -l t/session_expiry.t`
Expected: PASS (2 subtests).

- [ ] **Step 5: Commit**

```bash
cd /home/oetiker/checkouts/callbackery
git add lib/CallBackery/User.pm t/session_expiry.t
git commit -m "add sessionExpired flag to CallBackery::User"
```

---

### Task 2: `allow_rpc_access` — guard plugin instantiation, emit code 7 on expiry

**Files:**
- Modify: `lib/CallBackery/Controller/RpcService.pm:63-83` (the `allow_rpc_access` sub) and add a constant near the top (after the `use` lines, ~line 10)
- Test: `t/session_expiry.t` (extend)

**Interfaces:**
- Consumes: `CallBackery::User::sessionExpired` (Task 1); `$self->user->isUserAuthenticated`; `$self->config->instantiatePlugin`; `$self->rpcParams`.
- Produces: `RPC_SESSION_EXPIRED` (constant `7`) in `CallBackery::Controller::RpcService`. `allow_rpc_access` now `die`s `mkerror(7, ...)` for unauthenticated access to an auth-required method when `sessionExpired` is true; still `return 0` (→ dispatcher code 6) when not expired; still `return 1` when allowed.

- [ ] **Step 1: Write the failing tests**

Append to `t/session_expiry.t`, before `done_testing();`. This uses a mock user and a hand-built POST transaction so it needs no DB rows:

```perl
# Mock user: control isUserAuthenticated / sessionExpired directly.
{
    package MockUser;
    use Mojo::Base -base;
    has authed  => 0;
    has expired => 0;
    sub isUserAuthenticated { shift->authed }
    sub sessionExpired      { shift->expired }
}

# Build an RpcService controller bound to a POST request, with a mock user and
# given rpc params. Returns the controller.
sub mk_ctrl {
    my (%arg) = @_;
    my $tx = Mojo::Transaction::HTTP->new;
    $tx->req->method('POST');
    my $c = CallBackery::Controller::RpcService->new(tx => $tx, app => $t->app);
    $c->user(MockUser->new(authed => $arg{authed}, expired => $arg{expired}));
    $c->rpcParams($arg{params} // []);
    return $c;
}

# authenticated user -> access to an auth-required method is allowed
{
    my $c = mk_ctrl(authed => 1);
    is($c->allow_rpc_access('getSessionCookie'), 1, 'authenticated -> allowed');
}

# unauthenticated + expired, level-2 method -> dies code 7
{
    my $c = mk_ctrl(authed => 0, expired => 1);
    my $ok = eval { $c->allow_rpc_access('getSessionCookie'); 1 };
    ok(!$ok, 'expired level-2 dies');
    is($@->code, 7, 'expired -> code 7');
    like($@->message, qr/session/i, 'code 7 message mentions session');
}

# unauthenticated + NOT expired, level-2 method -> returns 0 (dispatcher -> code 6)
{
    my $c = mk_ctrl(authed => 0, expired => 0);
    is($c->allow_rpc_access('getSessionCookie'), 0, 'not-expired level-2 -> 0 (code 6)');
}

# unauthenticated + expired, level-3 method whose plugin instantiation dies ->
# code 7 (regression: must NOT escape as a generic code-9999 popup)
{
    my $c = mk_ctrl(authed => 0, expired => 1, params => ['NoSuchPlugin']);
    my $ok = eval { $c->allow_rpc_access('getPluginData'); 1 };
    ok(!$ok, 'expired level-3 dies despite plugin-instantiation failure');
    is($@->code, 7, 'expired level-3 -> code 7, not 9999');
}

# unauthenticated + NOT expired, level-3 non-anonymous plugin -> returns 0 (code 6)
{
    my $c = mk_ctrl(authed => 0, expired => 0, params => ['NoSuchPlugin']);
    is($c->allow_rpc_access('getPluginData'), 0, 'not-expired level-3 -> 0 (code 6)');
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /home/oetiker/checkouts/callbackery && HARNESS_OPTIONS=j4 prove -l t/session_expiry.t`
Expected: FAIL — the expired cases return 0 / die with a generic code instead of 7 (current code has no code-7 path and `instantiatePlugin` is unguarded).

- [ ] **Step 3: Add the constant**

In `lib/CallBackery/Controller/RpcService.pm`, after the existing `use` statements (around line 10), add:

```perl
# RPC error code the qooxdoo frontend maps to "session expired -> reload".
# Distinct from code 6 ("login required -> show login dialog").
use constant RPC_SESSION_EXPIRED => 7;
```

- [ ] **Step 4: Rewrite `allow_rpc_access`**

Replace the body of `allow_rpc_access` (`lib/CallBackery/Controller/RpcService.pm:63-83`) with:

```perl
sub allow_rpc_access ($self,$method) {
    if (not $self->req->method eq 'POST') {
        # sorry we do not allow GET requests
        $self->log->error("refused ".$self->req->method." request");
        return 0;
    }
    if (not exists $allow{$method}){
        return 0;
    }
    for ($allow{$method}){
        /1/ && return 1;                                 # public method
        return 1 if ($self->user->isUserAuthenticated); # forces cookieConf (sets sessionExpired)
        /3/ && do {
            # Level-3: allowed only for plugins that opt into anonymous access.
            # Guard the instantiation: for an unauthenticated user it commonly
            # dies (plugins read user rights/config); that death must resolve to
            # "not anonymous" here, never escape as a generic code-9999 popup.
            my $plugin = $self->rpcParams->[0];
            my $anon = eval {
                $self->config->instantiatePlugin($plugin,$self->user)->mayAnonymous
            };
            return 1 if $anon;
        };
        # Method needs auth and the user is not authenticated. If a session was
        # present and merely expired, signal that distinctly (code 7 -> reload);
        # otherwise fall through to code 6 (login dialog).
        die mkerror(RPC_SESSION_EXPIRED,
            trm('Your session has expired. Please reload to log in.'))
            if $self->user->sessionExpired;
        last;
    }
    return 0;
};
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /home/oetiker/checkouts/callbackery && HARNESS_OPTIONS=j4 prove -l t/session_expiry.t`
Expected: PASS (all subtests).

- [ ] **Step 6: Run the full suite (no regressions)**

Run: `cd /home/oetiker/checkouts/callbackery && HARNESS_OPTIONS=j4 prove -l t/`
Expected: PASS. In particular `t/jsonrpc.t`'s "unknown method → code 6" still passes (that path is `not exists $allow{$method}` → `return 0`, unchanged).

- [ ] **Step 7: Commit**

```bash
cd /home/oetiker/checkouts/callbackery
git add lib/CallBackery/Controller/RpcService.pm t/session_expiry.t
git commit -m "allow_rpc_access: emit code 7 on expired session, guard plugin instantiation"
```

---

### Task 3: `MsgBox` — Reload / Retry buttons and dialog helpers

**Files:**
- Modify: `lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/ui/MsgBox.js`

**Interfaces:**
- Produces:
  - two new buttons keyed `reload` ("Reload") and `retry` ("Retry"), each firing the existing `choice` data-event with its key on execute;
  - `MsgBox.sessionExpired(title, text)` — shows only `[reload]`;
  - `MsgBox.commError(title, text)` — shows `[retry, reload]`.
  Consumed by Tasks 4 and 5.

> No JS unit harness exists in callbackery; verification is a source check plus the manual smoke in Tasks 4/5 once the appliance is rebuilt against this callbackery.

- [ ] **Step 1: Add the buttons**

In the constructor of `MsgBox.js`, after the existing `__mk_btn` calls (after the `no` button, ~line 59), add:

```javascript
        this.__mk_btn('reload', this.tr("Reload"));
        this.__mk_btn('retry',  this.tr("Retry"));
```

- [ ] **Step 2: Add the helper methods**

In `members`, after the `yesno` method (~line 254), add:

```javascript
        ,

        /**
         * Session-expired prompt: a single Reload action.
         *
         * @param title {String} window title
         * @param text {String} content
         * @return {void}
         */
        sessionExpired : function(title, text) {
            this.__show_btn(['reload']);
            this.__open(title, text, false);
            return this;
        },

        /**
         * Communication-problem prompt: Retry (re-issue) or Reload (fresh page).
         *
         * @param title {String} window title
         * @param text {String} content
         * @return {void}
         */
        commError : function(title, text) {
            this.__show_btn(['retry','reload']);
            this.__open(title, text, false);
            return this;
        }
```

- [ ] **Step 3: Verify the source is well-formed**

Run: `cd /home/oetiker/checkouts/callbackery && node --check lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/ui/MsgBox.js`
Expected: no output (syntax OK). (If `node --check` rejects the qooxdoo class wrapper, instead visually confirm the two `__mk_btn` calls and the two methods are present and the surrounding commas/braces balance.)

- [ ] **Step 4: Commit**

```bash
cd /home/oetiker/checkouts/callbackery
git add lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/ui/MsgBox.js
git commit -m "MsgBox: add reload/retry buttons and sessionExpired/commError prompts"
```

---

### Task 4: `Server.js` — code-7 dedup reload prompt + post-expiry guard

**Files:**
- Modify: `lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/data/Server.js` (the `callAsync` `wrapped` handler, ~lines 163-201)

**Interfaces:**
- Consumes: `MsgBox.sessionExpired` (Task 3).
- Produces: singleton latch `this.__sessionExpiredHandled` (terminal — reset only by page reload). Read again in Task 5's guard.

- [ ] **Step 1: Add the post-expiry guard at the top of `wrapped`**

In `callAsync`, at the very start of the `wrapped` function body (before the `if (exc && exc.application)` check, ~line 166), add:

```javascript
                // A reload is already committed for this expired session; keep
                // quiet so late-arriving failures don't pop error boxes.
                if (origThis.__sessionExpiredHandled) { return; }
```

- [ ] **Step 2: Replace the code-7 branch with a deduped reload prompt**

Replace the existing `case 7:` block (~lines 181-197) with:

```javascript
                        case 7: {
                            // Session expired: exactly one reload prompt owns the
                            // UX; every other concurrent expired call is swallowed.
                            if (origThis.__sessionExpiredHandled) { return; }
                            origThis.__sessionExpiredHandled = true;
                            if (window.console) {
                                window.console.log("Session Expired. Prompting for reload.");
                            }
                            callbackery.ui.Busy.getInstance().vanish();
                            let mb = callbackery.ui.MsgBox.getInstance();
                            mb.addListenerOnce('choice', () => {
                                window.location.reload(true);
                            });
                            mb.sessionExpired(mb.tr('Session Expired'), mb.xtr(exc.message));
                            return;
                        }
```

- [ ] **Step 3: Verify syntax**

Run: `cd /home/oetiker/checkouts/callbackery && node --check lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/data/Server.js`
Expected: no output. (If the class wrapper is rejected, visually confirm brace/paren balance around the edited region.)

- [ ] **Step 4: Manual smoke (deferred to appliance rebuild — document, don't block)**

Record this procedure in the commit body / rollout notes; it runs when the appliance is rebuilt against this callbackery (Task 6 rollout):
1. Log into the appliance GUI.
2. Force expiry: wait past the 600s cookie age with the tab backgrounded, or set the appliance `cookieConf` age threshold low temporarily.
3. Trigger any backend action.
   - Expected: exactly ONE "Session Expired" dialog with a single **Reload** button; no red RPC-error popups. Clicking Reload reloads to the login dialog.

- [ ] **Step 5: Commit**

```bash
cd /home/oetiker/checkouts/callbackery
git add lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/data/Server.js
git commit -m "Server: dedup session-expired (code 7) into one reload prompt"
```

---

### Task 5: `Server.js` — communication-failure auto-retry + deduped dialog

**Files:**
- Modify: `lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/data/Server.js` (add retry constants + allowlist to `members`/`statics`; extend the `_send` error path and the `wrapped` handler)

**Interfaces:**
- Consumes: `MsgBox.commError` (Task 3); `this.__sessionExpiredHandled` (Task 4).
- Produces: singleton latch `this.__commsErrorHandled` (recoverable — cleared on any successful response and on Retry). Retry-safe method allowlist. Bounded-retry constants.

**Design notes for the implementer:**
- A *communication failure* is any rejection where `exc.application` is **false** (transport error, timeout, HTTP 5xx, non-JSON, non-JSON-RPC envelope, `id` mismatch). `qx.io.jsonrpc.Client` already rejects a response that isn't a valid JSON-RPC 2.0 reply to this request id, so proxy garbage lands here — never as a bogus `result`.
- Auto-retry applies **only** to communication failures **and** only when the method is in the retry-safe allowlist. Application errors (codes 6/7/9999/…) are deterministic and are never retried.
- The retry counter is **per call**; the dialog latch is **per singleton**.

- [ ] **Step 1: Add constants and the retry-safe allowlist**

Near the top of the `members` block in `Server.js` (after `__client: null`, ~line 37), add:

```javascript
        __sessionExpiredHandled: false,
        __commsErrorHandled: false,

        // Bounded silent retry for transient communication failures.
        _COMMS_RETRY_MAX: 3,
        _COMMS_RETRY_BACKOFF_MS: 1300,

        // Idempotent methods that are safe to retry silently. Writes
        // (processPluginData) and auth calls (login/logout) are excluded.
        _retrySafe: {
            ping: true, getBaseConfig: true, getUserConfig: true,
            getSessionCookie: true, getPluginConfig: true,
            getPluginData: true, validatePluginData: true
        },
```

- [ ] **Step 2: Clear the recoverable latch on any success**

In `_send`, in the success continuation (the `function(result) { invoke(result, null, null); }`, ~line 123), set the latch clear before `invoke`:

```javascript
                function(result) {
                    // connectivity is healthy again
                    self.__commsErrorHandled = false;
                    invoke(result, null, null);
                },
```

(Note: use `self`, which `_send` already captures via `this._getClient()`; if `_send` lacks a `self`, add `var self = this;` at the top of `_send`.)

- [ ] **Step 3: Add a comms-failure handler used by `callAsync`**

Add a new member method (after `_send`, ~line 142) that decides retry-vs-dialog for a communication failure. It re-issues via `_send` so retries reuse the exact original request:

```javascript
        /**
         * Handle a communication failure (non-application exception): bounded
         * silent retry for idempotent methods, otherwise one deduped dialog.
         *
         * @param resend {Function} zero-arg thunk that re-issues the original _send
         * @param methodName {String} the RPC method (for the retry-safe check)
         * @param attempt {Integer} 1-based attempt number that just failed
         */
        _handleCommsFailure: function(resend, methodName, attempt) {
            var self = this;
            if (this._retrySafe[methodName] && attempt < this._COMMS_RETRY_MAX) {
                qx.event.Timer.once(function() {
                    resend(attempt + 1);
                }, this, this._COMMS_RETRY_BACKOFF_MS);
                return;
            }
            // exhausted, or a non-retry-safe (write) call: one dialog owns the UX
            if (this.__commsErrorHandled) { return; }
            this.__commsErrorHandled = true;
            callbackery.ui.Busy.getInstance().vanish();
            var mb = callbackery.ui.MsgBox.getInstance();
            mb.addListenerOnce('choice', function(e) {
                if (e.getData() === 'reload') {
                    window.location.reload(true);
                }
                else { // retry
                    self.__commsErrorHandled = false;
                    resend(1);
                }
            });
            mb.commError(
                mb.tr('Connection problem'),
                mb.tr('The server is not responding or returned an unexpected answer.')
            );
        },
```

- [ ] **Step 4: Route comms failures from `callAsync` into the handler**

In `callAsync`, the `wrapped` handler currently ends with `origHandler(ret, exc, id);`. Replace that tail so a communication failure (non-application exc) is intercepted. The `_send` call at the bottom of `callAsync` also needs an attempt-aware resend. Update the end of `callAsync` as follows.

Replace the final section of `callAsync` (from the `origHandler(ret, exc, id);` line through the closing `this._send(wrapped, methodName, params);`, ~lines 200-203) with:

```javascript
                if (exc && !exc.application) {
                    // communication failure -> retry (idempotent) or dialog
                    origThis._handleCommsFailure(
                        function(nextAttempt) { doSend(nextAttempt); },
                        origMethod,
                        currentAttempt
                    );
                    return;
                }
                origHandler(ret, exc, id);
            };
            var params = args.concat([{ qxLocale: localeMgr.getLocale() }]);
            // Per-call attempt counter (closure-local, so concurrent callAsync
            // invocations never clobber each other's retry state).
            var currentAttempt = 1;
            var doSend = function(attempt) {
                currentAttempt = attempt;
                origThis._send(wrapped, methodName, params);
            };
            doSend(1);
```

> Note: `currentAttempt` and `doSend`/`params` are closed over per `callAsync` invocation, so each in-flight call retries the identical request with its own counter. Keep `origMethod` defined earlier in `callAsync` (it already is, ~line 160).

- [ ] **Step 5: Verify syntax**

Run: `cd /home/oetiker/checkouts/callbackery && node --check lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/data/Server.js`
Expected: no output. (If the class wrapper is rejected by `node --check`, visually confirm brace/paren/comma balance across the edited `members` block.)

- [ ] **Step 6: Manual smoke (deferred to appliance rebuild — document, don't block)**

Record for the appliance-rebuild verification:
1. **Transient blip:** with the GUI open, restart the appliance backend service; idle-refresh/read calls should retry silently and recover with no dialog.
2. **Hard down:** stop the backend; within ~4s a single "Connection problem" dialog appears with **Retry** and **Reload**; further failures don't stack more dialogs. Restart backend, click Retry → recovers.
3. **Proxy garbage:** point the browser at an endpoint returning a 502 HTML page or arbitrary JSON; expect the same "Connection problem" dialog, never a fake success and never the "Session Expired" prompt.
4. **Write during blip:** trigger a form submit (`processPluginData`) while the backend is down; expect the dialog immediately (no silent retry).

- [ ] **Step 7: Commit**

```bash
cd /home/oetiker/checkouts/callbackery
git add lib/CallBackery/qooxdoo/callbackery/source/class/callbackery/data/Server.js
git commit -m "Server: bounded auto-retry + single dialog for communication failures"
```

---

### Task 6: callbackery CHANGES + appliance cooperating change

**Files:**
- Modify: `callbackery/CHANGES`
- Modify: `hin-access-suite/hin-agw-appliance/lib/HinAgwConfig/Model/User.pm:122-131` (the `cookieConf` override)
- Modify: `hin-access-suite/hin-agw-appliance/CHANGES`

**Interfaces:**
- Consumes: `CallBackery::User::sessionExpired` (Task 1).

> The appliance one-liner is inert until the appliance pins the new callbackery release (see rollout). It is committed now so the change set is complete and reviewable.

- [ ] **Step 1: callbackery CHANGES entry**

Prepend a new version stanza to `callbackery/CHANGES` (match the existing format; use the next patch/minor after 0.57.0 per the maintainer's convention):

```
0.57.1  <date>  <author>

 - Session expiry now surfaces as a dedicated RPC code 7 ("session expired"),
   distinct from code 6 ("login required"). allow_rpc_access guards plugin
   instantiation so an expired session no longer escapes as a generic error.
   CallBackery::User gains a per-request `sessionExpired` flag for subclasses
   that enforce a cookie max-age.

 - Frontend data.Server: session expiry shows a single deduplicated
   "Session Expired -> Reload" prompt instead of a storm of error popups.
   Communication failures (server unreachable / proxy returning garbage) now
   retry silently for idempotent reads, then show one "Connection problem"
   dialog with Retry / Reload. MsgBox gains reload/retry buttons.
```

- [ ] **Step 2: Commit callbackery CHANGES**

```bash
cd /home/oetiker/checkouts/callbackery
git add CHANGES
git commit -m "CHANGES: session-expiry and communication-failure UX"
```

- [ ] **Step 3: Appliance cooperating one-liner**

In `hin-access-suite/hin-agw-appliance/lib/HinAgwConfig/Model/User.pm`, in the `cookieConf` override, set the flag where it currently only returns `{}`:

```perl
has cookieConf => sub ($self) {
    my $conf = $self->SUPER::cookieConf;
    return $conf unless $conf->{t};
    my $cookieAge = gettimeofday() - $conf->{t};
    if ($cookieAge > 600) {
        $self->log->debug(qq{Cookie is expired ($cookieAge seconds old)});
        $self->sessionExpired(1);   # signal expiry -> RPC code 7 (reload prompt)
        return {};
    }
    return $conf;
};
```

- [ ] **Step 4: Appliance CHANGES entry**

Prepend to `hin-access-suite/hin-agw-appliance/CHANGES` (match existing format):

```
 - Expired GUI sessions now show a single "Session Expired -> Reload" prompt
   instead of repeated backend-error popups (requires CallBackery >= 0.57.1).
```

- [ ] **Step 5: Commit appliance change**

```bash
cd /home/oetiker/checkouts/hin-access-suite/hin-agw-appliance
git add lib/HinAgwConfig/Model/User.pm CHANGES
git commit -m "hin-agw-appliance: signal session expiry to CallBackery (code 7 reload prompt)"
```

---

## Rollout (post-merge, not a code task)

1. Release callbackery (0.57.1) with the backend + frontend changes together.
2. In the appliance, bump `thirdparty/cpanfile` `CallBackery '== 0.56.8'` → `== 0.57.1`. Confirm CallBackery 0.57.1 pulls `Mojolicious::Plugin::Qooxdoo >= 1.1.0` (no carton snapshot → resolved at build).
3. Rebuild the appliance frontend (already on `@qooxdoo/framework ^7.9.1`) **and** backend together, then run the manual smoke from Tasks 4/5 (expiry → one reload prompt; backend down → retry then Connection-problem dialog; proxy garbage → same dialog; upload/download under expiry).
4. Optional appliance hardening (spec §10): in `frontend/source/class/hin_agw_appliance/Application.js`, switch the 60s keep-alive refresh from `callAsyncSmart` to `callAsync` so the handler observes failures and resets its `running` guard in all paths.

---

## Self-Review

**Spec coverage:**
- §3 taxonomy A/B/C/D → Task 2 (A/B codes), Task 4 (B UX), Task 5 (C UX); D unchanged (still `MsgBox.exc`). ✓
- §4 A-vs-B distinction → `sessionExpired` flag (Task 1) + branch (Task 2). ✓
- §5.1 flag / §5.2 allow_rpc_access / §5.3 appliance line → Tasks 1, 2, 6. ✓
- §6.1 code 6 unchanged → not touched (verified in Task 2 Step 6). ✓
- §6.2 code-7 dedup → Task 4. ✓
- §6.3 class-C retry + allowlist + params → Task 5. ✓
- §6.4 envelope validation → relied upon + documented in Task 5 design note + smoke #3. ✓
- §6.5 MsgBox buttons/methods → Task 3. ✓
- §8 backend tests → Task 1/2 tests; frontend manual smoke → Tasks 4/5. ✓
- §9 rollout / §10 follow-up / §11 files → Rollout section + Task 6. ✓

**Placeholder scan:** no TBD/TODO; all code steps carry concrete code. (Dates in CHANGES stanzas are filled at commit time by the author, matching repo convention.) ✓

**Type/name consistency:** `sessionExpired` (User method + flag), `RPC_SESSION_EXPIRED` (7), `__sessionExpiredHandled` / `__commsErrorHandled` latches, `_retrySafe`, `_handleCommsFailure`, `MsgBox.sessionExpired` / `MsgBox.commError` — used identically across Tasks 1-6. ✓
