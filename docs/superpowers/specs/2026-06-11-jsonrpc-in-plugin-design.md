# Move JSON-RPC 2.0 dispatch into mojolicious-plugin-qooxdoo

Date: 2026-06-11
Status: Approved
Related: PR #242 (CallBackery qooxdoo-7 / JSON-RPC 2.0 migration)

## Problem

CallBackery must run on qooxdoo 7.x, whose client speaks JSON-RPC 2.0
(`qx.io.jsonrpc.Client`); the proprietary `qx.io.remote.Rpc` ("qx1") protocol
is deprecated. The RPC protocol machinery belongs in the reusable,
separately-versioned `Mojolicious::Plugin::Qooxdoo` plugin —
`CallBackery::Controller::RpcService` is a thin subclass that provides only its
`%allow` map, password-cleaning log overrides, and RPC methods, inheriting
`dispatch`, `renderJsonRpcResult`, and `renderJsonRpcError` from
`Mojolicious::Plugin::Qooxdoo::JsonRpcController`.

The plugin, however, only speaks qx1. To put CallBackery on JSON-RPC 2.0 while
keeping the protocol where it belongs, the plugin must learn JSON-RPC 2.0 and
CallBackery must inherit it.

## Goal

Two coordinated PRs:

1. **`mojolicious-plugin-qooxdoo`**: teach the plugin to speak JSON-RPC 2.0
   *in addition to* qx1, auto-detecting per request. Backward compatible for
   existing plugin consumers.
2. **CallBackery PR #242**: require the new plugin version and inherit its 2.0
   support; `RpcService.pm` carries no protocol overrides (a thin subclass).

## Non-goals

- No change to the frontend (`callbackery.data.Server` on `qx.io.jsonrpc.Client`,
  `_jsonSafe` NaN handling).
- No change to upload/download routes.
- No removal of qx1 support from the plugin (other consumers may still use it).

## Design

### Part 1 — plugin: auto-detecting dispatcher

In `Mojolicious::Plugin::Qooxdoo::JsonRpcController`:

Add a controller attribute to record the detected protocol:

```perl
has 'jsonRpc20';   # true when the current request is JSON-RPC 2.0
```

`dispatch` decodes the body exactly as today (POST `application/json`, or the
qx1 GET `_ScriptTransport_data` path), then branches on the envelope:

- **`defined $data->{jsonrpc}`** → JSON-RPC 2.0 mode (`jsonRpc20(1)`):
  - require `$data->{jsonrpc} eq '2.0'` else 500 with a clear message;
  - POST-only — a GET in 2.0 mode is an error (2.0 has no Script transport /
    crossDomain);
  - **no `service` check** (2.0 drops the qx1 `service` concept);
  - same downstream flow as qx1: `allow_rpc_access($method)` (die code 6 on
    denial), `can($method)` (die code 4 if missing), `logRpcCall`, invoke,
    `Mojo::Promise` handling, `render_later`.
  - **params (permissive):** `params` may be an array or a named object.
    - array → splat into the method arg list (`$self->$method(@$params)`), as
      qx1 does;
    - hashref → pass as a single argument (`$self->$method($params)`), so a
      method can `my $args = shift`;
    - anything else → 500 with a clear message.
- **else** → existing qx1 mode (`jsonRpc20` false): behavior byte-for-byte
  unchanged — `service` check, GET/crossDomain, etc.

`renderJsonRpcResult` branches on `jsonRpc20`:

```perl
my $reply = $self->jsonRpc20
    ? { jsonrpc => '2.0', id => $self->requestId, result => $data }
    : {                   id => $self->requestId, result => $data };
```

`renderJsonRpcError` branches on `jsonRpc20`:

- **2.0**: `{ jsonrpc => '2.0', id => $id, error => { code => int($code),
  message => $message, data => { origin => $origin // 2 } } }` — `origin`
  folded into `data` (2.0 forbids extra top-level error members), `code`
  coerced to integer (2.0 requires an integer code).
- **qx1**: `{ id => $id, error => { origin => $origin || 2, message, code } }`
  — unchanged.

The error classification (HASH-with-message / blessed-with-code+message /
fallback 9999) is shared between both modes.

`finalizeJsonRpcReply` is reused unchanged: in 2.0 mode `crossDomain` is always
false, so it just sets `application/json` and renders.

**Versioning:** 1.0.14 → **1.1.0** (additive, backward compatible). Bump
`$VERSION` in both `Qooxdoo.pm` and `JsonRpcController.pm`, and `Changes`.

### Part 2 — CallBackery (PR #242)

- **`lib/CallBackery/Controller/RpcService.pm`**: carries no protocol overrides
  — `dispatch`, `renderJsonRpcResult`, and `renderJsonRpcError` are inherited
  from the plugin. It provides only the `%allow` map, `has service => 'default'`
  (used in qx1 mode and in the error fallback log line), the password-cleaning
  `logRpcCall`/`logRpcReturn` overrides, and the RPC methods.
- **`Makefile.PL`**: `'Mojolicious::Plugin::Qooxdoo' => '1.1.0'`.
- **`CHANGES`**: breaking-change entry. The *backend* is protocol-backward-
  compatible (the plugin's auto-detect serves both old qx1 and new 2.0
  frontends); the breaking part is the bundled 2.0-only
  `callbackery.data.Server`, so apps upgrade frontend + backend together.
- **`t/jsonrpc.t`, `t/basic.t`**: exercise the inherited 2.0 behavior
  end-to-end.

### Part 3 — tests & sequencing

Plugin PR adds `t/` coverage:
- 2.0 success envelope (`{jsonrpc:"2.0", id, result}`);
- 2.0 error envelope with integer `code` and `data.origin`;
- 2.0 named-object params reach the method as a hashref;
- qx1 regression: existing tests stay green (the unchanged path).

Sequencing:
1. Implement the plugin change on a fork branch (`zaucker/…`), add tests,
   open PR to `oetiker/mojolicious-plugin-qooxdoo`.
2. Maintainer merges and releases 1.1.0 to CPAN.
3. CallBackery #242 rebases, bumps `Makefile.PL`, `make thirdparty`, re-runs
   `prove -l t/basic.t t/jsonrpc.t`.

For local end-to-end testing before the CPAN release, build the plugin branch
into CallBackery's `thirdparty/` (or `use lib` the plugin checkout, as the
camas harness already does for CallBackery).

## Risks

- **Coupling / release order:** #242 cannot land its `Makefile.PL` bump until
  1.1.0 is on CPAN. Mitigation: local build for testing; the maintainer owns
  both repos and controls the release.
- **Behavioral drift:** the plugin's 2.0 path must preserve the application
  error codes the frontend depends on (6 = login required, 7 = session
  expired). Mitigation: CallBackery's `t/jsonrpc.t` exercises the inherited
  path end-to-end and guards these codes.
