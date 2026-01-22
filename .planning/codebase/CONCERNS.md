# Codebase Concerns

**Analysis Date:** 2026-01-22

## Security Concerns

**String Evaluation in varCompiler:**
- Issue: `varCompiler` method uses `eval` to compile user-supplied Perl code from config files
- Files: `lib/CallBackery/GuiPlugin/Abstract.pm:414-431`
- Impact: If config files can be tampered with by attackers, arbitrary code execution is possible. The code includes a `## no critic (ProhibitStringyEval)` pragma acknowledging this risk
- Current mitigation: Config files are expected to be admin-controlled; not marked as user-editable input
- Recommendations: Validate that config files can only be modified by authorized administrators. Consider restricting the Perl code sandbox or using a safer evaluation mechanism

**Weak Password Hashing:**
- Issue: Passwords are hashed using `hmac_sha1_sum` (SHA-1 based HMAC) which is cryptographically weak
- Files: `lib/CallBackery/User.pm:212`, `lib/CallBackery/User.pm:226`; `lib/CallBackery/Config.pm:49,634`
- Impact: SHA-1 is vulnerable to collision attacks. Modern password cracking tools can potentially breach accounts
- Current mitigation: HMAC wrapper adds some additional security over plain SHA-1, but still insufficient
- Recommendations: Migrate to bcrypt, scrypt, or Argon2 for password hashing. This would be a breaking change requiring password reset mechanism

**Temporary Files Not Using Secure Generation:**
- Issue: Session secrets and database dumps are written to predictable temp files
- Files: `lib/CallBackery/Config.pm:528` (uses `/tmp/cbdump$$`), `lib/CallBackery/Config.pm:49,634` (random secrets)
- Impact: Process ID alone is insufficient for security; `/tmp` is world-readable on most systems
- Current mitigation: Secret files are chmod 0400 after generation, but database dumps are unprotected
- Recommendations: Use `File::Temp` for secure temporary file creation. Ensure database dumps are not world-readable

**SQL Injection Prevention Relies Entirely on quote_identifier/quote:**
- Issue: All database queries use manual string concatenation with `quote_identifier()` and `quote()`
- Files: `lib/CallBackery/Database.pm:100-139` (map2sql, map2where methods)
- Impact: While current implementation uses proper quoting, any missed call to these helpers or direct SQL construction could introduce injection
- Current mitigation: Helper methods enforce consistent quoting patterns; no direct variable interpolation observed
- Recommendations: Migrate to parameterized queries using Mojo::SQLite prepared statements with placeholders for all dynamic parts

**Sesame (Backdoor) Authentication Mode:**
- Issue: "Open Sesame" mode allows fallback authentication with pre-configured credentials
- Files: `lib/CallBackery/User.pm:209-215`, `lib/CallBackery/Config.pm:190-197`
- Impact: If sesame credentials are compromised or misconfigured, entire system is bypassed. Provides persistent backdoor access
- Current mitigation: Documented as optional feature; stored as HMAC in config
- Recommendations: Make this feature explicitly opt-in and logged. Consider requiring multi-factor authentication for sesame access. Audit when sesame login is used

**Unrestricted File Extraction from Archives:**
- Issue: `restoreConfigBlob` extracts plugin state files without full path validation
- Files: `lib/CallBackery/Config.pm:597-616`
- Impact: Malicious archives could potentially extract files outside intended directories (directory traversal) or overwrite critical files
- Current mitigation: Files checked against `stateFiles` whitelist; warnings logged
- Recommendations: Validate extracted file paths are within expected directories. Use `File::Spec->canonpath` to prevent `../` attacks

---

## Tech Debt & Architecture Issues

**Large Monolithic Modules:**
- Files: `lib/CallBackery/Config.pm:737 lines`, `lib/CallBackery/GuiPlugin/Abstract.pm:722 lines`, `lib/CallBackery/GuiPlugin/AbstractForm.pm:337 lines`
- Impact: Difficult to test, understand, and modify; high cyclomatic complexity; tight coupling between concerns
- Scaling impact: Adding new features increases module size; future refactoring will be painful
- Priority: Medium - not breaking but increases maintenance burden

**Critical System Call Using open3 Without Full Error Handling:**
- Issue: `systemNoFd` uses `IPC::Open3` with limited exception handling for process execution
- Files: `lib/CallBackery/GuiPlugin/Abstract.pm:639-645`
- Impact: Daemon processes could fail silently; output not captured if parent dies unexpectedly
- Recommendations: Implement timeout mechanisms. Ensure child processes are properly reaped in all exit paths

**Database Handle Lifecycle Not Clearly Defined:**
- Issue: `mojoSqlDb` creates fresh database handles on each call, potentially leading to connection leaks
- Files: `lib/CallBackery/Database.pm:86-88`
- Impact: If many calls happen in sequence, SQLite connection pool could be exhausted or stale handles remain open
- Recommendations: Document connection pooling strategy. Consider caching handles within request lifecycle

**Configuration File Parsing Uses Global State:**
- Issue: Config parsing creates temporary grammar objects that are cleared after use
- Files: `lib/CallBackery/Config.pm:68-76`
- Impact: If config is re-parsed during runtime, grammar object destruction could affect concurrent operations
- Recommendations: Make grammar generation explicitly thread-safe or document that config must not be re-parsed at runtime

**Locale Settings Set at Module Load Time:**
- Issue: `LC_NUMERIC` and `LC_TIME` locales hardcoded to "C" at startup
- Files: `lib/CallBackery.pm:24-26`, duplicated at `lib/CallBackery.pm:136-137`
- Impact: Cannot support non-English number formats; inflexible for international deployments; hardcoding at two locations risks inconsistency
- Recommendations: Document why this is necessary (Perl number string conversion bugs). Move to a single configuration point

**No Transaction Management for Multi-Step Operations:**
- Issue: Config backup/restore operations execute multiple SQL operations without explicit transactions
- Files: `lib/CallBackery/Config.pm:520-555`, `lib/CallBackery/Config.pm:563-620`
- Impact: If system crashes mid-operation, database could be left in partially-restored state; backup integrity not guaranteed
- Recommendations: Wrap multi-step operations in explicit transactions. Add recovery/validation steps

---

## Test Coverage Gaps

**Limited Test Suite:**
- Files: Only `t/basic.t` and `t/invalidPlugin.t` exist
- What's not tested:
  - Database migration and schema validation
  - User authentication and authorization (login, may, rights)
  - Plugin loading and instantiation
  - Config file parsing and validation
  - Backup/restore functionality
  - Error handling in critical paths
- Risk: Core functionality changes could break silently. Authentication bugs could go undetected
- Priority: High - these are critical security and reliability paths

**No Integration Tests:**
- Issue: Tests only verify basic ping and doc endpoints
- Impact: Real-world workflows (user creation, config changes, plugin operations) untested
- Recommendations: Add integration tests covering: user lifecycle, plugin operations, config backup/restore cycles

**No Error Path Testing:**
- Issue: How system behaves with invalid config, missing plugins, database corruption is untested
- Impact: Errors in production could cascade unpredictably
- Recommendations: Add tests for: malformed configs, missing required plugins, database I/O failures, permission errors

---

## Known Issues & Fragile Areas

**Special User IDs Not Properly Validated:**
- Issue: Special user IDs like `__ROOT`, `__CONFIG`, `__SHELL`, `__CONSOLE` are used throughout with minimal validation
- Files: `lib/CallBackery/User.pm:66-79,104-110`
- Impact: If validation is missing in one code path, could bypass permission checks
- Recommendations: Create type-safe wrapper for userId; validate against whitelist

**eval Used Extensively Without Consistent Error Handling:**
- Issue: 24+ uses of `eval` blocks throughout codebase with inconsistent error handling patterns
- Files: Multiple locations, see grep results above
- Impact: Hard to predict what happens when eval fails; some evals ignore errors, others don't
- Recommendations: Create wrapper function for safe eval with consistent exception handling and logging

**Global `lastFlush` Variable Not Used:**
- Issue: Module-level variable in `Database.pm:57` is defined but never used
- Files: `lib/CallBackery/Database.pm:57`
- Impact: Dead code; suggests incomplete implementation or abandoned feature
- Recommendations: Remove if not needed; if needed, clarify purpose and usage

**No Validation of Plugin File Paths:**
- Issue: Plugin state files and unconfigure files extracted/deleted without path canonicalization
- Files: `lib/CallBackery/Config.pm:664-668`
- Impact: Plugin could specify malicious paths like `../../../etc/passwd` (though unlikely given plugin control)
- Recommendations: Canonicalize all file paths; validate they're within expected directories

**Version Pinning Missing:**
- Issue: Many dependencies use `0` (meaning "any version") in `Makefile.PL:24-25`
- Files: `Makefile.PL:24-25`, `Makefile.PL:26`, `Makefile.PL:31`
- Impact: Dependency updates could introduce breaking changes or security vulnerabilities
- Recommendations: Test with newer versions and pin to specific minimum versions. Add regular dependency audit process

---

## Performance Bottlenecks

**Database Queries Not Using Indexes Efficiently:**
- Issue: `map2where` builds WHERE clauses but no query plan analysis present
- Files: `lib/CallBackery/Database.pm:121-139`
- Impact: With large tables, queries could be slow without proper indexes
- Recommendations: Add database explain plan tests; ensure indexes on frequently queried columns (user lookup, config lookup)

**Archive Processing Loads Entire Backup Into Memory:**
- Issue: `getConfigBlob` and `restoreConfigBlob` load full zip archives and database dumps into memory
- Files: `lib/CallBackery/Config.pm:520-555`, `lib/CallBackery/Config.pm:563-620`
- Impact: Large deployments with gigabytes of config data could cause OOM errors
- Recommendations: Stream archive processing; limit maximum backup size

**Socket Cleanup Loop Uses glob on /proc/self/fd:**
- Issue: `systemNoFd` iterates all file descriptors to find sockets for FIOCLEX
- Files: `lib/CallBackery/GuiPlugin/Abstract.pm:617`
- Impact: With thousands of open FDs, this becomes slow; glob pattern expansion is expensive
- Recommendations: Use `/proc/self/fdinfo` if available; limit to reasonable FD range

---

## Dependency & Compatibility Risks

**Perl 5.022000 Minimum Requirement:**
- Issue: Strict minimum version requirement excludes older systems
- Files: `Makefile.PL:1`, `Makefile.PL:34`
- Impact: Cannot run on systems with Perl 5.20 or earlier (already EOL but still in use on some LTS systems)
- Current status: Reasonable for modern deployments
- Recommendations: Document why 5.022 is needed (likely for signatures/async_await features)

**Mojolicious 9.33 Version Pinning:**
- Issue: Mojolicious pinned to specific minimum version; may not be compatible with future major versions
- Files: `Makefile.PL:15`
- Impact: Upgrades to Mojolicious 10.x+ might require code changes not yet made
- Recommendations: Test with Mojolicious 10.x; update tests and dependencies

**Future::AsyncAwait and Syntax::Keyword::Try Still Experimental:**
- Issue: These are async/await features that are still evolving in Perl
- Files: `Makefile.PL:19-20`, used in multiple modules with `-async_await`
- Impact: Future Perl versions may change these features; custom code relying on them could break
- Recommendations: Monitor Perl RFC discussions; plan migration to stable async approach when available

---

## Missing Critical Features

**No Rate Limiting:**
- Issue: Login attempts, API endpoints have no rate limiting or throttling
- Impact: Brute force attacks on passwords possible; DDoS via API calls
- Recommendations: Add request rate limiting per IP/user; implement exponential backoff for failed logins

**No Audit Logging:**
- Issue: Admin actions (user creation, deletion, config changes) not logged
- Impact: Cannot detect unauthorized changes; no compliance trail for sensitive operations
- Recommendations: Add audit log table; log all config changes, user operations, permission modifications

**No Session Timeout:**
- Issue: Session management not visible; unclear if sessions expire
- Files: Session handling in `Controller/RpcService.pm` uses makeSessionCookie but timeout not found
- Impact: Stolen session cookies grant indefinite access
- Recommendations: Implement session timeout; refresh mechanism for long-running operations

**No CSRF Protection:**
- Issue: No visible CSRF token validation in RPC calls
- Files: `lib/CallBackery/Controller/RpcService.pm`
- Impact: Cross-site request forgery possible if user is tricked into visiting malicious site
- Recommendations: Implement SameSite cookie flag; add CSRF token validation for state-changing operations

---

## Recommendations Summary (Priority Order)

1. **HIGH:** Add comprehensive test suite for authentication, authorization, and config operations
2. **HIGH:** Migrate password hashing from SHA-1 to bcrypt/Argon2
3. **HIGH:** Implement rate limiting and session timeouts
4. **HIGH:** Add audit logging for sensitive operations
5. **MEDIUM:** Refactor large modules (Config.pm, Abstract.pm) into smaller, testable units
6. **MEDIUM:** Migrate database queries to parameterized statements
7. **MEDIUM:** Pin all dependencies to specific versions and implement regular audit process
8. **MEDIUM:** Add CSRF protection to state-changing operations
9. **LOW:** Use secure temporary file generation (File::Temp)
10. **LOW:** Document and test locale handling; move to single configuration point

---

*Concerns audit: 2026-01-22*
