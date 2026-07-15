# CallBackery: Session-expiry & communication-failure UX

- **Date:** 2026-07-15
- **Status:** Approved design, pending implementation plan
- **Repo (primary):** `callbackery` (v0.57.0, JSON-RPC 2.0 / qooxdoo 7.x)
- **Cooperating repo:** `hin-access-suite/hin-agw-appliance` (one line + pin bump/rebuild)

## 1. Problem

On the AGW appliance, when a GUI session expires the app becomes "half dead":
the UI stays interactive but every backend call throws a red error popup, and no
login dialog or reload prompt ever appears.

### Root cause

Authentication is a stateless, signed **session cookie** carried in the
`X-Session-Cookie` HTTP header (a JS-held value in `callbackery.data.Server`, not
a browser cookie). The appliance expires that cookie after 600s of no refresh
(`HinAgwConfig::Model::User::cookieConf`), after which `isUserAuthenticated`
returns false.

`CallBackery::Controller::RpcService::allow_rpc_access` then reaches this line for
the level-3 RPC methods the GUI calls constantly (`getPluginConfig`,
`getPluginData`, `processPluginData`, `validatePluginData`):

```perl
/3/ && do {
    my $plugin = $self->rpcParams->[0];
    if ($self->config->instantiatePlugin($plugin,$self->user)->mayAnonymous){  # NOT in eval
        return 1;
    }
};
```

`instantiatePlugin` runs **outside any `eval`**. Instantiating a plugin for an
unauthenticated user typically dies (plugins read user rights/config); that death
escapes `allow_rpc_access`, and the dispatcher renders it as a *generic* error
(code 9999 / the plugin's own code). The frontend's `callAsyncSmart` turns that
into `MsgBox.exc()` — a popup. It never reaches the clean
`return 0 → code 6 → login dialog` path, so no login dialog appears.

Pure level-2 calls (`getUserConfig`, `getSessionCookie`) *would* yield code 6, but
the frequent level-3 plugin calls die first with generic codes.

A second, related gap: transport failures (server not responding, timeout, HTTP
5xx) and malformed/unexpected responses (a proxy serving a 502 HTML page, a
captive-portal login page, non-JSON, or JSON that isn't a valid JSON-RPC 2.0
envelope) also fall through to `MsgBox.exc()` — a popup storm with no coherent
recovery affordance.

## 2. Goals / non-goals

**Goals**

- Session expiry produces exactly **one** clean "Session Expired → Reload" prompt,
  not a popup storm.
- First login / not-logged-in keeps its current **login dialog** (code 6); it must
  NOT be mistaken for expiry (that would cause a reload loop).
- Server-unreachable / proxy-garbage failures recover silently when transient, and
  otherwise show a single "Connection problem → Retry / Reload" dialog.
- A proxy's "random answer" is never mistaken for a successful RPC result.

**Non-goals**

- Moving the appliance's 600s expiry policy into callbackery (explicitly kept in
  the appliance; see §5.3).
- Server-side session state / server-side session store (auth stays stateless).
- Auto-retrying non-idempotent writes.

## 3. Error taxonomy

Every failed RPC falls into exactly one class. `callbackery.data.Server._send`
already exposes `application = (ex instanceof qx.io.exception.Protocol)`, which is
the discriminator between "the server returned a JSON-RPC error object" and
everything else.

| Class | Detection | Backend code | Frontend UX |
|---|---|---|---|
| **A. Not logged in / first login** | app error, no valid cookie was presented | 6 | Login dialog + retry once *(unchanged)* |
| **B. Session expired** | app error, a validly-signed cookie was presented but is too old | **7** | One deduped "Session Expired → Reload" prompt |
| **C. Communication failure** | NOT a Protocol exception: transport error, timeout, HTTP 5xx, non-JSON, non-JSON-RPC envelope, wrong `id` | n/a | Bounded silent auto-retry (idempotent reads only) → one deduped "Connection problem → Retry / Reload" dialog |
| **D. Real application error** | app error, any other code | 9999 / custom | `MsgBox.exc()` popup *(unchanged — these are legitimate per-call errors)* |

Load-bearing guard: only class A/B/D (Protocol / `application === true`) may
trigger login/reload/msgbox-by-code. A transport code that happens to equal `6`
or `7` (the `qx.io.exception.Transport` namespace has its own `FAILED=7`) must
never trip login/reload. The `application` flag already enforces this and stays
load-bearing.

## 4. The A-vs-B distinction (why it is essential)

Both "not logged in" and "expired" make `isUserAuthenticated` false, so they must
be told apart or first login breaks.

Boot flow (`callbackery/Application.js:56-80`): every page load calls
`getBaseConfig` (public) then immediately `getUserConfig` (needs auth). On a fresh
browser, `getUserConfig` fails auth and today yields **code 6 → login dialog** —
that code-6 path *is* the first-login mechanism.

If unauthenticated always mapped to code 7 (reload), a first-time visitor would
loop: `getUserConfig → code 7 → reload → getUserConfig → code 7 → …`, never
seeing a login dialog.

The server can distinguish them because the cookie is stateless:

- **A / not logged in:** no cookie / empty / bad signature was presented.
- **B / expired:** a validly-signed cookie *was* presented, but its timestamp is
  older than the max age.

Resulting flows:

- **First login:** no cookie → code 6 → login dialog → log in → retry → done.
  (No reload — already on a clean page.)
- **Expiry:** valid-but-old cookie → code 7 → reload prompt → reload. After reload
  the JS-held cookie is gone, so the next `getUserConfig` presents no cookie →
  code 6 → login dialog. **No loop.** Expiry also gets the clean-slate reload
  (stale translations/config/in-flight calls cleared).

## 5. Backend design (callbackery)

### 5.1 `CallBackery::User` — expose expiry as distinct state

Add a per-request flag that any expiry-detecting code can raise. It is set **only**
when a validly-signed cookie was presented but is too old; no cookie / bad
signature / bad structure leaves it false (→ "not logged in").

```perl
has sessionExpired => 0;   # public reader; per-request (User is per-transaction)
```

Base callbackery only owns the flag's declaration and default. Base header cookies
have no age limit of their own — that policy (and thus the actual setter for the
GUI session) is the appliance's (§5.3). The base's only pre-existing expiry path is
the 300s `xsc` param-cookie used by form submissions, which `die`s `38445` and is
caught in `handleUpload`/`handleDownload` — a separate flow from `allow_rpc_access`;
it is left as-is. Reading order is safe: `allow_rpc_access` calls
`isUserAuthenticated` → `userInfo` → `userId` → `cookieConf` (memoized), so the
override has run and set the flag before the flag is read.

### 5.2 `CallBackery::Controller::RpcService::allow_rpc_access` — branch on the flag

```perl
use constant RPC_SESSION_EXPIRED => 7;   # matches the frontend's reserved code

sub allow_rpc_access ($self,$method) {
    return 0 if $self->req->method ne 'POST';      # unchanged (GET refused)
    return 0 if not exists $allow{$method};        # unchanged (unknown method)
    for ($allow{$method}) {
        /1/ && return 1;                           # public method
        return 1 if $self->user->isUserAuthenticated;   # forces cookieConf (sets flag)
        /3/ && do {                                # level-3: maybe an anonymous plugin
            my $plugin = $self->rpcParams->[0];
            my $anon = eval {                      # guarded: unauth instantiation death
                $self->config->instantiatePlugin($plugin,$self->user)->mayAnonymous
            };
            return 1 if $anon;                     # genuinely anonymous-allowed
        };
        # unauthenticated: expired session vs never logged in
        die mkerror(RPC_SESSION_EXPIRED,
            trm('Your session has expired. Please reload to log in.'))
            if $self->user->sessionExpired;
        last;                                      # else fall through to code 6
    }
    return 0;   # no session ever presented => code 6 => login dialog
}
```

Two effects:

- The `eval` around `instantiatePlugin` kills the generic-error popup cascade at
  the source: an unauthenticated instantiation death now resolves to "not
  anonymous", never escapes as code 9999.
- The `die` is reached only when unauthenticated (any authenticated user already
  returned `1`), so it never fires for authenticated-but-unauthorized — those
  `may()` checks still happen later inside the plugin, unchanged.

### 5.3 Appliance cooperating change (one line)

`HinAgwConfig::Model::User::cookieConf` owns the 600s header-cookie policy; it just
needs to feed the flag:

```perl
has cookieConf => sub ($self) {
    my $conf = $self->SUPER::cookieConf;
    return $conf unless $conf->{t};
    my $cookieAge = gettimeofday() - $conf->{t};
    if ($cookieAge > 600) {
        $self->log->debug(qq{Cookie is expired ($cookieAge seconds old)});
        $self->sessionExpired(1);   # NEW: mark expired, not merely absent
        return {};
    }
    return $conf;
};
```

## 6. Frontend design (`callbackery.data.Server`, 0.57.0)

Two singleton latches live on the `Server` instance:

- `__sessionExpiredHandled` — **terminal** (a reload is imminent; never cleared in
  JS, resets naturally on page reload).
- `__commsErrorHandled` — **recoverable** (cleared on any successful response and
  on Retry).

### 6.1 Class A — code 6 (unchanged)

Login dialog + retry-once, exactly as today. This is the first-login / re-auth
driver.

### 6.2 Class B — code 7 (deduped reload prompt)

```js
case 7: {
    if (origThis.__sessionExpiredHandled) { return; }   // first expired call owns UX
    origThis.__sessionExpiredHandled = true;
    callbackery.ui.Busy.getInstance().vanish();
    let mb = callbackery.ui.MsgBox.getInstance();
    mb.addListenerOnce('choice', () => window.location.reload(true));
    mb.sessionExpired(mb.tr('Session Expired'), mb.xtr(exc.message));  // single [Reload]
    return;
}
```

Plus a guard at the top of the `wrapped` handler so any exception arriving after
expiry is detected is swallowed rather than popped:

```js
if (origThis.__sessionExpiredHandled) { return; }   // reload pending — stay quiet
```

### 6.3 Class C — communication failure (auto-retry, then deduped dialog)

Applies when the exception is **not** a `Protocol` exception (`application` false),
covering transport errors, timeouts, HTTP 5xx, non-JSON, non-JSON-RPC envelopes,
and `id` mismatches.

Per-call logic (attempt counter is per call; latch is per singleton):

1. On a class-C failure, if the method is **retry-safe** and attempts remain,
   schedule a silent retry after a short backoff (re-issue via `_send`), increment
   the counter. Do not touch the UI (Busy indicator, if any, stays up).
2. If retries are exhausted, or the method is **not** retry-safe:
   - if `__commsErrorHandled` is set → swallow (return);
   - else set `__commsErrorHandled = true`, `Busy…vanish()`, and show one
     `MsgBox.commError()` dialog with **Retry** and **Reload**:
     - **Reload** → `window.location.reload()`.
     - **Retry** → clear `__commsErrorHandled`, reset the counter, re-issue this
       call.
3. On **any** successful response (anywhere in `Server`), clear
   `__commsErrorHandled` (connectivity recovered → silence any pending notice
   state).

**Retry-safe method allowlist** (idempotent, no writes):
`ping`, `getBaseConfig`, `getUserConfig`, `getSessionCookie`, `getPluginConfig`,
`getPluginData`, `validatePluginData`.
**Not retry-safe:** `processPluginData` (may write) and `login`/`logout` (special)
→ dialog immediately, no silent retry.

**Retry parameters (constants):** 3 attempts, ~1.3s fixed backoff (≈4s total).
Tunable in one place.

### 6.4 Envelope validation (security / correctness requirement)

A response is accepted as a result **only** if it is a valid JSON-RPC 2.0 reply to
*this* request: `jsonrpc === "2.0"`, `id` matches the outgoing request, and exactly
one of `result` / `error` is present. Anything else (proxy HTML, captive-portal
page, arbitrary JSON, wrong/missing `id`) becomes a class-C exception — never a
silent bogus `result`. `qx.io.jsonrpc.Client` enforces this; the requirement is
made explicit and covered by a test so it cannot silently regress.

### 6.5 `callbackery.ui.MsgBox` additions

Add two buttons and two thin methods (the current fixed set is
cancel/apply/ok/yes/no):

- buttons `reload` ("Reload") and `retry` ("Retry"), created like the others in the
  constructor and wired to fire `choice` with their key;
- `sessionExpired(title, text)` → shows `['reload']`;
- `commError(title, text)` → shows `['retry','reload']`.

## 7. UX flows (summary)

- **First login:** boot → `getUserConfig` code 6 → login dialog → success.
- **Expiry (tab open):** 60s refresh or next click → code 7 → one Reload prompt →
  reload → code 6 → login dialog.
- **Comms blip (service restarting ~2s):** read calls retry silently → recover →
  user never notices; a write during the blip → immediate "Connection problem"
  dialog, user hits Retry once it is back.
- **Server hard-down:** reads retry, exhaust → one "Connection problem" dialog with
  Retry / Reload; further failures swallowed.
- **Proxy garbage / captive portal:** response fails envelope validation → class C
  → same "Connection problem" dialog; never interpreted as success or as expiry.

## 8. Testing

**Backend (Perl, `Test::Mojo`)**

- `allow_rpc_access`: authenticated → allowed; unauthenticated + `sessionExpired`
  → dies code 7; unauthenticated + not expired → returns 0 (→ code 6); level-3
  with an anonymous plugin → allowed; level-3 whose plugin instantiation dies for
  an unauthenticated user → code 7 (regression test for the popup bug), not 9999.
- `CallBackery::User::sessionExpired`: false with no cookie / bad signature; true
  with a validly-signed but too-old cookie.

**Frontend (manual smoke on the appliance GUI + unit where practical)**

- First login shows a login dialog (no reload loop).
- Force expiry (wait past 600s / tamper timestamp): single Reload prompt; after
  reload, login dialog.
- Kill the backend mid-session: reads retry then one "Connection problem" dialog;
  restart backend + Retry recovers.
- Point at a proxy returning a 502 HTML page / arbitrary JSON: "Connection
  problem" dialog, never a fake success.
- Upload/download flows (`handleUpload`/`handleDownload`) behave under expiry.

## 9. Rollout / migration

- Backend and frontend halves ship in the **same** callbackery release (the code-7
  reload branch and the dedup only exist in 0.57.0's frontend). Do not ship the
  backend half against a pre-0.57.0 frontend (code 7 would have no branch → popup).
- Appliance: bump `thirdparty/cpanfile` `CallBackery '== 0.56.8'` → `0.57.0`, add
  the §5.3 one-liner, rebuild the frontend (already on `@qooxdoo/framework ^7.9.1`,
  so the qooxdoo-7 prerequisite is met) and backend together, and smoke-test the
  GUI. Confirm CallBackery 0.57.0 pulls `Mojolicious::Plugin::Qooxdoo >= 1.1.0`
  (no carton snapshot → resolved at build).

## 10. Related follow-up (appliance, optional)

`hin_agw_appliance/Application.js` keep-alive refresh sets `running = true` and
only resets it in the *success* handler (`callAsyncSmart` swallows exceptions), so
a failed refresh can wedge the 60s timer. Recommended hardening: use `callAsync`
so the handler sees the exception and resets `running` in all paths. Out of scope
for the callbackery fix; tracked here so it is not lost.

## 11. Files touched

**callbackery**

- `lib/CallBackery/User.pm` — declare the `sessionExpired` flag (default 0). The
  operative setter lives in the appliance override; base leaves its 300s `xsc` die
  path unchanged.
- `lib/CallBackery/Controller/RpcService.pm` — restructured `allow_rpc_access`
  (`eval` around plugin instantiation; code-7 die on expired; `RPC_SESSION_EXPIRED`
  constant).
- `.../callbackery/data/Server.js` — code-7 dedup latch + top-of-handler guard;
  class-C auto-retry + `__commsErrorHandled` latch + retry-safe allowlist;
  envelope-validation test hook.
- `.../callbackery/ui/MsgBox.js` — `reload`/`retry` buttons; `sessionExpired()` and
  `commError()` methods.
- `t/…` — backend tests per §8; `CHANGES`.

**hin-agw-appliance**

- `lib/HinAgwConfig/Model/User.pm` — one line: `$self->sessionExpired(1)`.
- `thirdparty/cpanfile` — CallBackery pin bump; frontend rebuild.
