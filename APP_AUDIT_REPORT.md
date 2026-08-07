# BSG App — Full Codebase Audit Report

**Scope:** Raw, file-by-file, folder-by-folder audit of the `bsg_app` Flutter codebase, based strictly on the actual source code (no `.md`/skill/doc files used as input for the analysis itself). No fixes or refactors were applied — analysis and issue-detection only.

**Files covered:** root (`lib/main.dart`, `lib/constants.dart`), `lib/models/` (4 files), `lib/providers/` (3 files), `lib/screens/` (4 files), `lib/services/` (6 files), `lib/theme/` (3 files), `lib/widgets/` (10 files), `test/` (1 file), plus project configuration (`pubspec.yaml`, `analysis_options.yaml`).

**Format key:** Each file audit uses four numbered sections (**#1**–**#4**). Items inside each section are lettered (**#A**, **#B**, **#C**...). Section #4 keeps its four fixed categories (🐛/🗑️/⚔️/🔗) as the lettered items, each with its own findings listed beneath.

**Correction note:** One finding was revised mid-audit. An earlier pass on `lib/theme/app_text_styles.dart` concluded Oswald weight 700 was unregistered in `pubspec.yaml`, based on a `grep` command whose output was truncated before reaching the relevant line. A direct read of the full file found weight 700 **is** registered. This is corrected at its source (`app_text_styles.dart`, #4B) and reflected in the consolidated summary — flagged transparently rather than silently removed.

---

## Table of Contents

1. [# 1.1 : Root](#root)
2. [# 1.2 : `lib/models/`](#models)
3. [# 1.3 : `lib/providers/`](#providers)
4. [# 1.4 : `lib/screens/`](#screens)
5. [# 1.5 : `lib/services/`](#services)
6. [# 1.6 : `lib/theme/`](#theme)
7. [# 1.7 : `lib/widgets/`](#widgets)
8. [# 1.8 : `test/`](#test)
9. [# 1.9 : Project Configuration](#config)
10. [# 1.10 : Consolidated Cross-Codebase Findings](#consolidated)

---

<a name="root"></a>
# 1.1 : Root

#1 (A) : `lib/constants.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `kSupabaseUrl` (top-level `const String`) — value: `https://pkwifufxakvwyqjamywo.supabase.co`
► `kSupabaseAnonKey` (top-level `const String`) — a JWT-formatted Supabase anon key (decodable header/payload, not just an opaque token)

#1 (B): Database & Backend Connections
► This file is the backend connection definition. It hardcodes the Supabase project endpoint (`kSupabaseUrl`) and the anonymous public API key (`kSupabaseAnonKey`) used to initialize the Supabase client elsewhere in the app (`main.dart`).
► No table names, RPC calls, or query logic live here — this is purely the connection credential layer.
► Decoding the JWT payload (base64, non-cryptographic — for audit purposes only): `iss: "supabase"`, `ref: "pkwifufxakvwyqjamywo"`, `role: "anon"`, `iat: 1785237373`, `exp: 2100813373`. The expiry decodes to the year 2036 — an unusually long-lived anon key.

#1 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** A single static configuration file exposing two compile-time constants: the Supabase project URL and its public "anon" API key. Consumed wherever the Supabase client SDK is initialized (`Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey)`). Because they're `const`, they're baked into the compiled app binary at build time — not fetched at runtime, not environment-specific.
► **Non-Coder Explanation:** The app's "return address and mailbox key" for talking to its cloud database. Every balance check, bet log, or history fetch uses this address and key. Because it's one fixed address/key baked into every copy of the app, there's no way to point a test version at a different database without editing this file and rebuilding.

#1 (D): Game Functionality Structure
► **Supabase URL Definition** — `kSupabaseUrl`: hardcoded project endpoint string, base URL for all Supabase REST/Realtime/Auth calls.
► **Supabase Anon Key Definition** — `kSupabaseAnonKey`: hardcoded public API key (JWT), authenticates the app itself (not a specific user), gating access via Row Level Security (RLS) policies on the backend.

#1 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None — static data, nothing executes, no null risk, no race conditions.
► 🗑️ **Unused / Dead Code:** Cannot confirm consumer usage from this file alone — confirmed used in `main.dart` once that file was audited.
► ⚔️ **Functionality Conflicts:** N/A — single-purpose, no competing logic.
► 🔗 **Database & Web Dashboard Misalignment:**
  - No dev/staging/prod split (no `--dart-define`, no `.env`, no build flavors) — single-environment hardcoding.
  - Anon key being public is expected/by-design for Supabase, but its safety is entirely contingent on RLS being correctly configured on every table — unverifiable from this file alone.
  - The distant expiry (2036) suggests a newer long-lived key format or a manually extended expiry — a fact worth flagging for whoever manages credential rotation, not itself a bug.

---

#2 (A) : `lib/main.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `main()` — async entrypoint function.
► `_navigatorKey` — top-level `GlobalKey<NavigatorState>`.
► `_ForcedLogoutWatcher` — `StatelessWidget`, watches `AuthProvider.forcedLogout` and redirects to `/login`.
► `BsgApp` — root `StatelessWidget`: `MultiProvider`, `ThemeData`, named routes.

#2 (B): Database & Backend Connections
► `Supabase.initialize(url: kSupabaseUrl, anonKey: kSupabaseAnonKey)` — the single point where the app establishes its backend client (auto token refresh, RPC, realtime plumbing).
► SharedPreferences key `'bsg_local_game_history'` — removed on every startup. **Confirmed dead** via codebase-wide grep (see `services/auth_service.dart` #4B) — nothing else in the app reads or writes this key. The real drawn-numbers history key is `'bsg_drawn_numbers_history'`, correctly cleared at session boundaries elsewhere.
► No direct table queries or RPC calls — delegates all backend logic to providers/services.

#2 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** The app entrypoint. Sequentially: ensures Flutter binding, initializes Supabase, wipes a (dead) local-history cache, locks portrait orientation, enables immersive fullscreen, enables wakelock, then runs `BsgApp`. `BsgApp` wires three `ChangeNotifierProvider`s app-wide, defines a dark casino `ThemeData`, sets up named-route navigation, and wraps the navigator in `_ForcedLogoutWatcher` — documented as fix **"F-4"**: previously the heartbeat logged a player out internally but left them on a fully interactive, dead game screen.
► **Non-Coder Explanation:** The "front door and building manager." Connects to the cloud database, clears yesterday's leftover history, locks the phone into upright mode, hides the status bar, and keeps the screen awake. It also posts a security guard at the door of every screen — if the server ends a session (banned, or logged in elsewhere), the guard walks the player back to login instead of leaving them tapping on a dead game.

#2 (D): Game Functionality Structure
► **Supabase Initialization** — blocking (`await`); no screen renders until it completes or throws.
► **Startup Local History Wipe** — deletes `bsg_local_game_history` on every cold start, wrapped in a silent `try/catch`. Confirmed dead — see #4B.
► **Orientation Lock** — portrait-only, set once at startup, not re-asserted on screen changes.
► **Immersive Fullscreen Mode.**
► **Wakelock Enable** — never explicitly disabled anywhere in this file.
► **Provider Registration** — `AuthProvider`, `GameProvider`, `HistoryProvider` via `MultiProvider`.
► **Forced-Logout Watcher ("F-4" fix)** — redirects to `/login` when `AuthProvider.forcedLogout` fires, clears the flag, surfaces `forcedLogoutReason` as an error on the login screen.
► **Theming** — dark casino palette, `DMSans` default font, flat app bar.
► **Named Route Table** — `/splash → /login → /lobby → /game`, `/splash` as initial route.

#2 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - No try/catch around `Supabase.initialize()` — a network/config failure crashes the app before any UI renders, with no fallback screen.
  - Silent exception swallowing on the history-clear (`catch (_) {}`), zero logging.
  - `_ForcedLogoutWatcher` could theoretically schedule multiple post-frame navigation callbacks across rapid rebuilds — low risk given idempotent navigation.
  - Wakelock enabled at startup with no visible `disable()` call anywhere in the file — effectively always-on; potential unnecessary battery drain outside gameplay.
  - Orientation lock is launch-only, not re-asserted — a latent fragility if any screen changes system UI mode without restoring it.
► 🗑️ **Unused / Dead Code:**
  - `// ignore: deprecated_member_use` on `anonKey:` — the SDK itself flags this parameter as deprecated (not dead code, but a flagged technical-debt marker).
  - **Confirmed dead**: the `'bsg_local_game_history'` startup-clear (see backend map #B).
► ⚔️ **Functionality Conflicts:** None internally; cross-file item resolved — the local-history wipe here does not conflict with any resume-session feature, since the real key is handled correctly in `services/auth_service.dart`.
► 🔗 **Database & Web Dashboard Misalignment:** Nothing directly queryable here beyond the Supabase bootstrap already covered in `constants.dart`'s audit.

### Root — Folder Completion Summary
1. **Architecture & Overview:** Two files form the app's bootstrap layer — credentials (`constants.dart`) and entrypoint/wiring (`main.dart`).
2. **Interdependencies:** `main.dart` imports `constants.dart` for Supabase credentials, instantiates all three providers consumed throughout `screens/`, and defines the sole navigation graph every screen transition must go through.
3. **Bug & Conflict Summary:** No error handling around `Supabase.initialize()`; wakelock never disabled; confirmed dead SharedPreferences key; deprecated SDK parameter usage; no environment split for the Supabase connection.

---

<a name="models"></a>
# 1.2 : `lib/models/`

#1 (A) : `lib/models/bet_model.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `ChipValue` — enum: `two, five, ten, fifty, hundred`.
► `ChipValueX` — extension on `ChipValue`: `amount` getter, `fromAmount(int v)` static method.
► `BoardType` — enum: `single, double_, triple` (trailing underscore avoids the `double` keyword).
► `BetAction` — class: `board`, `cellKey`, `amount` — immutable undo record.
► `BetBoardState` — class: three `Map<String,int>` boards (`single` "0"-"9", `double_` "00"-"99", `triple` "000"-"999"); `boardFor(BoardType)`, `total`/`singleTotal`/`doubleTotal`/`tripleTotal`, `isEmpty`, `clearAll()`.

#1 (B): Database & Backend Connections
► None directly — pure client-side domain model, no Supabase/API references.
► The `cellKey` string format convention ("0"-"9"/"00"-"99"/"000"-"999") is a cross-file contract with the backend, later confirmed server-enforced (malformed keys rejected outright — see `services/round_api_service.dart` #4D).

#1 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Core data model for a three-board numbers game. `ChipValue` is a closed enum with bidirectional int conversion. `BetAction` is an immutable placement record for undo. `BetBoardState` is the mutable aggregate root holding three independent boards with derived totals and a bulk clear.
► **Non-Coder Explanation:** The "rulebook and scoreboard" for chip placement — what chip sizes exist, the three board types, and a running tally of exactly how much is staked on each number.

#1 (D): Game Functionality Structure
► **Chip Denomination Enum** — the fixed chip sizes selectable in the tray.
► **Chip Amount Conversion** — maps enum to integer value via exhaustive `switch`.
► **Chip Reverse Lookup** — linear search (trivial at n=5) recovering a `ChipValue` from a raw int, `null` on no match.
► **Board Type Enum** — single/double/triple distinction.
► **Bet Action Record** — immutable placement event for undo/remove.
► **Board State Container** — three independent maps, not a unified structure.
► **Board Selector (`boardFor`)** — returns the live, mutable map reference.
► **Total Calculators** — recomputed on every access, not cached.
► **Empty Check** — true only if all three boards are empty.
► **Clear All** — empties all three maps in place.

#1 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - No validation anywhere that a `cellKey` matches its board's expected format — enforced only by comment convention, not code. Any caller can insert `single["999"] = 100` and the model happily totals it.
  - No non-negative amount validation on stakes.
  - `boardFor` returns the internal map by reference — any caller holding it can mutate board state outside a controlled API, making mutation sites hard to trace.
  - Totals recomputed on every access — fine at these board sizes, but no memoization if called in a hot render loop.
► 🗑️ **Unused / Dead Code:** Cannot confirm `BetAction`'s only consumer from this file alone (later confirmed used for undo in `game_provider.dart`).
► ⚔️ **Functionality Conflicts:** The `double_`/`double` naming workaround (Dart keyword collision) is a recurring landmine every consumer must remember is Dart-only, not present in JSON.
► 🔗 **Database & Web Dashboard Misalignment:** Cannot assess from this file alone — later resolved: the server validates and rejects malformed keys outright (fail-closed), so the risk is confined to client-side display math, not server-side mis-settlement.

---

#2 (A) : `lib/models/play_limits_config.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `BetRejectReason` — enum: `none, cellMaxExceeded, cellMinNotMet, insufficientBalance`.
► `BetRejection` — class: `reason`, `board`, `cellKey`, `cap`; static const `ok`.
► `PlayLimits` — class: `min`, `max`; factory `fromJson`.
► `PlayLimitsConfig` — class: `byBoard` map; factories `.fallback()` and `.fromJson()`; method `limitsFor(BoardType)`.

#2 (B): Database & Backend Connections
► `PlayLimits.fromJson` expects keys `'min'`/`'max'` (both `int`), a direct contract with the backend's play-limits payload.
► `PlayLimitsConfig.fromJson` expects top-level keys `'single'`/`'double'`/`'triple'` — note the JSON key is the clean `'double'`, not the Dart-only `'double_'`.
► The comment documents a historical bug ("M-3") and references RPC `submit_round_bet` and error code `P0007`. **Both are stale**: confirmed in `services/api_contract.dart` that the actual current RPC is `place_bet` and the actual error code is `ErrCode.belowMin = 'P0123'`. The code itself is unaffected (correct constants are used elsewhere) — only this comment has drifted.
► Hardcoded fallback limits (single 2/10000, double 2/1000, triple 2/100) are explicitly documented as duplicating server-side fallback values — a second hardcoded copy with no shared source of truth.

#2 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Client's representation of per-board betting limits and bet-rejection taxonomy. `PlayLimitsConfig` has two construction paths: `.fallback()` (hardcoded, used immediately at provider construction so limits are never null) and `.fromJson()` (real server data).
► **Non-Coder Explanation:** The "house rules card" for min/max bets per board. The app memorizes safe default rules so it's never caught without them, then swaps in the real rules once the server responds.

#2 (D): Game Functionality Structure
► **Bet Rejection Reason Taxonomy.**
► **Bet Rejection Result Object** — reason + optional context for a specific user-facing message.
► **Per-Board Limit Pair.**
► **Per-Board Limit Deserialization** — unsafe direct cast (`as int`), no null guard.
► **Full Limits Config Container.**
► **Fallback Config Factory** — documented "Bug #8" fix, guarantees limits are never null.
► **JSON Config Factory.**
► **Board Limit Lookup** — force-unwraps (`!`) the map lookup.

#2 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - `limitsFor`'s `byBoard[t]!` force-unwrap throws if any `BoardType` key is missing from a partial/malformed server response — no defensive fallback merge.
  - `PlayLimits.fromJson`'s unsafe casts throw a `TypeError` on any type mismatch (missing field, wrong type) — no `tryParse`/type-checking fallback.
  - `PlayLimitsConfig.fromJson`'s unguarded key access (`j['single']` etc.) throws if any board key is missing from the response.
  - No validation that `min <= max` — a malformed config would be silently accepted.
► 🗑️ **Unused / Dead Code:** `BetRejection.cap`/`cellKey` usage unconfirmed from this file alone — later confirmed populated/read in `game_provider.dart`.
► ⚔️ **Functionality Conflicts:**
  - Naming inconsistency between the Dart enum (`double_`) and its JSON key (`double`) — handled correctly here, but a landmine for any other file independently parsing board-keyed JSON.
  - Duplicated fallback values (client vs. server) — a change to house limits requires updating at least two places.
► 🔗 **Database & Web Dashboard Misalignment:** The most concrete misalignment risk in this file: since parsing is unguarded, any shape change in the server's play-limits response risks crashing the load path entirely rather than degrading gracefully to the fallback.

---

#3 (A) : `lib/models/spin_result_model.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `SpinResult` — class: `id, red, green, black, mode, selections, chipValue, won, deductedAmount, winAmount, singleWinAmount, doubleWinAmount, tripleWinAmount, netChange, createdAt`; getters `resultString`, `modeLabel`; `fromJson`, `toJson`.
► `Transaction` — class: `id, amount, type, balanceAfter, note, createdAt`; getter `isCredit`, `typeLabel`; `fromJson`.

#3 (B): Database & Backend Connections
► `SpinResult.fromJson`/`toJson` round-trip snake_case keys: `id, red, green, black, mode, selections, chip_value, won, deducted_amount, win_amount, single_win_amount, double_win_amount, triple_win_amount, net_change, created_at`.
► `Transaction.fromJson` reads: `id, amount, type, balance_after, note, created_at`. Known `type` values: `admin_topup, agent_topup, game_bet, game_win`.
► These snake_case keys map directly to Postgres/Supabase table columns (exact table names not declared here — confirmed later in `services/history_provider.dart`'s live queries).

#3 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Two heavily-defensive DTOs. `SpinResult` is one round's outcome (result digits, mode, financial breakdown, per-board win amounts). `Transaction` is a ledger entry. Both use `(x as num?)?.toInt()` safe casting and `?? default` fallbacks throughout, degrading to zeros/empty-strings/`DateTime.now()` rather than throwing.
► **Non-Coder Explanation:** A "spin receipt" and a "bank statement line." Both are built to be forgiving — if the server sends an incomplete record, the app fills in safe defaults instead of crashing.

#3 (D): Game Functionality Structure
► **Spin Result Data Holder.**
► **Result String Getter (`resultString`)** — concatenates red+green+black into a display string, no padding/validation.
► **Mode Label Getter** — derives "which board(s) won" from per-board win amounts, falls back to raw `mode`.
► **JSON Deserialization** — defensive, every field null-safe.
► **JSON Serialization** — mirrors `fromJson`'s key set for round-tripping.
► **Transaction Data Holder.**
► **Credit Check** — `amount > 0` (implies signed amount).
► **Transaction Type Label** — hardcoded 4-type switch, unknown types pass through raw.
► **Transaction JSON Deserialization** — same defensive pattern.

#3 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - `resultString` has no digit padding/validation — a malformed/missing digit (silently defaulted to `0` by the parser) is indistinguishable from a legitimate `0` result. A real trust concern for a gambling app's displayed result.
  - All-defensive-fallback parsing silently defaults core financial fields (`winAmount`, `deductedAmount`, `netChange`, `amount`, `balanceAfter`) to zero/false on any parse failure, with zero logging of the fallback having triggered.
  - `createdAt` fallback to `DateTime.now()` fabricates a client-side timestamp for what should be a server-authoritative record time.
  - `Transaction.note` is the one field with no default fallback (inconsistent with everything else, though defensible since `null` is a valid "no note" state).
► 🗑️ **Unused / Dead Code:** `toJson()`'s actual call sites unconfirmed from this file alone.
► ⚔️ **Functionality Conflicts:** None internally — two independent, non-overlapping models.
► 🔗 **Database & Web Dashboard Misalignment:** `Transaction.typeLabel`'s hardcoded 4-type switch is a client-side copy of a backend-defined set — a new backend transaction type shows an unpolished raw string until the app is updated.

---

#4 (A) : `lib/models/user_model.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `UserModel` — class: `id, username, role, coinBalance, ledgerVersion, isActive, token`; `fromJson`, `copyWith`, `toJson`.

#4 (B): Database & Backend Connections
► `fromJson` reads `user_id` (preferred) or `id` (fallback) → `id`; `username`; `role`; `coin_balance` (BIGINT, DB CHECK-enforced non-negative/non-fractional); `ledger_version`; `is_active`; `token`.
► `toJson` writes `id, username, role, coin_balance, ledger_version, is_active` — **`token` deliberately omitted**, documented as fixing audit finding **S-1** (avoiding a duplicate plaintext JWT in a second SharedPreferences key).
► `role` comment states app sessions are always `'player'`, enforced by the server-side `session_login` RPC.
► Historical comment: a prior `agentName` field was always null due to a camelCase/snake_case mismatch (`agentName` emitted vs. `agent_name` read) and was removed entirely rather than fixed, since RLS prevents a player reading their agent's profile row anyway.

#4 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Client-side session model, deserialized with defensive fallbacks, supporting partial immutable updates via `copyWith`. The dual-key `id` fallback suggests two different backend response shapes feed this same constructor.
► **Non-Coder Explanation:** The player's "ID badge" — username, role, coins, an internal version stamp for ordering balance updates, active status, and login token (deliberately not saved to disk alongside the rest, for security).

#4 (D): Game Functionality Structure
► **User/Session Data Holder.**
► **JSON Deserialization** — dual-key `id` fallback, defensive on every field.
► **Partial Update (`copyWith`)** — `id`/`username`/`role` always carried over unchanged, only `coinBalance`/`ledgerVersion`/`isActive`/`token` are overridable.
► **JSON Serialization for Persistence** — excludes `token` (S-1 fix).

#4 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - `copyWith` cannot update `role` — rigid if that invariant ever changes, though low risk given the stated "always player" contract.
  - Dual-key `id` fallback silently produces `''` if neither key is present — an empty-string user ID could propagate downstream without immediately surfacing as an error.
  - `coinBalance` defaults to `0` on parse failure — a silently-wrong balance display, however brief, is a meaningfully bad failure mode for a real-money app.
  - `ledgerVersion` defaults to `0` on parse failure — **later found to be moot**: `AuthProvider` tracks its own independent `_ledgerVersion`, never reading this model's field again after login (see #4B below and `providers/auth_provider.dart` #4A).
► 🗑️ **Unused / Dead Code:** **Confirmed in the `providers/` audit** — `UserModel.ledgerVersion` is set once at login and never read again; `AuthProvider`'s own separate `_ledgerVersion` field is what's actually used for staleness checks. Effectively dead data on the model after construction.
► ⚔️ **Functionality Conflicts:** Cross-file pointer: the comment names `AuthProvider.updateBalanceWithVersion` as the consumer of `ledgerVersion` — confirmed and analyzed in the `providers/` audit.
► 🔗 **Database & Web Dashboard Misalignment:** This file is a positive example of a previously-found, now-resolved misalignment (`balance`/`coin_balance`, `agentName`/`agent_name`) — good evidence this bug class has occurred before and was significant enough to be named, reinforcing every other naming-drift risk found elsewhere. `role` is trusted from the server with no client-side assertion, despite the comment claiming server enforcement — pure trust, no defensive check.

### `models/` — Folder Completion Summary
1. **Architecture & Overview:** Four pure data models, no backend calls of their own, consistent snake_case/defensive-parsing convention.
2. **Interdependencies:** `play_limits_config.dart` imports `bet_model.dart` for `BoardType`. `spin_result_model.dart` re-encodes the same three-way board split as parallel named fields instead of reusing the enum — an early instance of "board identity modeled multiple ways," which recurs later in `providers/`.
3. **Bug & Conflict Summary:** Systemic silent-fallback parsing on financial fields across all models; no client-side `cellKey` format validation; crash-prone unguarded parsing in `play_limits_config.dart` (inconsistent with the rest of the folder's defensive style); confirmed dead `UserModel.ledgerVersion` field after login; a documented, already-fixed naming-drift history that recurs as a live pattern elsewhere in the app; stale RPC-name/error-code references in comments (`submit_round_bet`/`P0007`).

---

<a name="providers"></a>
# 1.3 : `lib/providers/`

#1 (A) : `lib/providers/auth_provider.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `AuthProvider extends ChangeNotifier`.
► State: `_user, _sessionStartAt, _loading, _error, _heartbeatTimer, _forcedLogout, _forcedLogoutReason, _ledgerVersion, _uncommittedStakeGetter`.
► Getters: `user, sessionStartAt, isLoggedIn, isLoading, error, coinBalance, username, token, ledgerVersion, forcedLogout, forcedLogoutReason`.
► Methods: `setUncommittedStakeGetter, clearForcedLogout, updateBalance, updateBalanceWithVersion, syncAuthoritativeBalance, applyOptimisticBalance, login, _startHeartbeat, _endSession, logout, clearError, setError, changePassword, dispose`.

#1 (B): Database & Backend Connections
► Depends on `ApiService()` (`.login`, `.heartbeat`, `.logout`, `.changePassword`) and `AuthService()` (`.saveSession`, `.clearSession`).
► Uses `api_contract.dart` constants: `Field.ledgerVersion, Field.allowed, Field.reason, Field.coinBalance, ReasonCode.accountBlocked`.
► Heartbeat polls every **15 seconds** via `ApiService().heartbeat(token)`.

#1 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Owns the session and coin balance under a documented **v2 "ledger version" ordering scheme** — every server balance response carries a version; updates apply only if `version >= _ledgerVersion`, preventing a delayed/stale response from rolling back a newer balance. Explicitly replaces a v1 design using two global locks that could "freeze the displayed balance" (documented findings **F-2**/**F-2b**).
► **Non-Coder Explanation:** The session manager and money-order-taker. Checks in with the server every 15 seconds and only ever accepts a balance update at least as new as what it already has — like only accepting the latest-dated letter, so the balance never mistakenly jumps backward.

#1 (D): Game Functionality Structure
► **Session State Fields.**
► **Uncommitted Stake Getter Registration** — allows an external caller (`GameProvider`, wired from `game_screen.dart`) to register a callback for heartbeat balance reconciliation.
► **Forced Logout Clear** — called by `main.dart`'s `_ForcedLogoutWatcher` after handling the redirect.
► **Local-Only Balance Update (`updateBalance`)** — no version bump; for optimistic local UI changes (chip placement).
► **Version-Gated Balance Update (`updateBalanceWithVersion`)** — discards stale/out-of-order server responses.
► **Authoritative Balance Sync (`syncAuthoritativeBalance`)** — unconditional overwrite; used after definitive server actions.
► **Optimistic Balance Application (`applyOptimisticBalance`)** — pre-increments `_ledgerVersion` by exactly 1 and applies a predicted balance instantly on a known win, before server confirmation. Documented as valid **only** when the DB is guaranteed to increment by exactly one slot for this event.
► **Login Flow (`login`)** — sets loading, calls `ApiService().login`, builds `_user` and `_ledgerVersion` from the profile, persists via `AuthService().saveSession`, starts heartbeat.
► **Heartbeat Loop (`_startHeartbeat`)** — every 15s; `null` = transient hiccup (session kept alive); `allowed != true` triggers forced session end.
► **Session Termination (`_endSession`)** — cancels heartbeat, calls `ApiService().logout()`, clears persisted session, resets state.
► **Explicit Logout / Error Management / Change Password / Dispose.**

#1 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **[Initially flagged, later resolved]** No try/catch around `ApiService().login()`/the heartbeat call. Confirmed in `services/api_service.dart`'s audit: both are fully exception-safe by design (every I/O path wrapped in try/catch, returning a failed result rather than throwing). This was not a live bug.
  - `applyOptimisticBalance`'s self-documented sharp edge: calling it for a non-guaranteed DB increment would permanently freeze balance updates for the rest of the session, since the `>=` version gate would then reject all future legitimate updates. Confirmed only called correctly today (in `game_provider.dart`'s win-payout branch), but a high-blast-radius single point of failure if that ever changes.
  - Heartbeat balance can clamp to a displayed `0` if uncommitted stake exceeds the reported balance — a poor failure mode for a real-money app (briefly shows `0` instead of the real balance).
  - `_uncommittedStakeGetter` registration-order race: if `GameProvider` hasn't wired the getter before the first heartbeat fires, uncommitted stake defaults to `0` for that cycle — 15s is normally enough time, but it's an implicit ordering dependency.
► 🗑️ **Unused / Dead Code:** **Confirmed** — `UserModel.ledgerVersion` (the field on the model) is set once at login and never read again; `AuthProvider`'s own separate `_ledgerVersion` field is the live one.
► ⚔️ **Functionality Conflicts:**
  - Heartbeat's binary reason check (blocked vs. "opened elsewhere") — **initially flagged as risky, later resolved**: `api_contract.dart`'s `ReasonCode` documentation confirms the heartbeat can only realistically return those two values (`sessionActiveElsewhere` is login-only), making the binary check correctly exhaustive.
  - Four different balance-mutation entry points place significant correctness burden on callers to choose the right one — no type-system enforcement against misuse.
► 🔗 **Database & Web Dashboard Misalignment:** The entire ledger-version scheme is a client-side reconstruction of a server-side DB trigger invariant this file cannot verify — the single most consequential cross-system dependency in this file.

---

#2 (A) : `lib/providers/game_provider.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `BetSubmissionStatus` — enum: `idle, submitting, submitted, failed`.
► `GameProvider extends ChangeNotifier` — extensive state: `_playLimits, _balanceSyncFailed, _betStatus, _submittedRoundId, _lastRejection, _mode, _isDrawerOpen, _activeChip, _lastActiveChip, _board, _history, _lastBetSnapshot, _rebetUsed, _submittedBets, _isSpinning, _isWaitingForResult, _spinAborted, _lastResult, _lastWinBoxResult, _pendingResult, _error, _countdown, _countdownTimer, _onTimerExpire, _blackHistory, _spinHistory, _globalHistory, _triplePage, _onNoBets`.
► Key methods: `setBetStatus, resetBetSubmissionStatus, clearRejection, openDrawerWithMode, closeDrawer, selectChip, deselectChip, placeBet, placeBetOnRow, placeRandomBets, doDouble, clearBets, removeLast, removeChipFromCell, removeChipFromRow, clearRebetSnapshot, clearLastResult, rebet, loadGlobalHistory, startCountdown, stopCountdown, abortSpin, resetCountdown, onGlobalResult, _syncBalanceInBackground, clearSpinHistory, markBetsSubmitted, validateMinimums, refundRejectedBets, setTriplePage, dispose`.

#2 (B): Database & Backend Connections
► `RoundApiService().getPlayLimits()`, `.getRecentRounds(limit: 10)`, `.getMyRoundResult(roundId)`.
► `RoundSyncService().syncedNowSecs` (server-synced UTC epoch seconds), `.betRoundId`.
► SharedPreferences key `'bsg_drawn_numbers_history'` — read/written directly, hardcoded literal rather than referencing `AuthService.keyDrawnNumbers` (currently matching, but an unenforced duplicate).
► Referenced backend concepts (comments, to confirm downstream): `submit_round_bet` RPC (stale name — actual is `place_bet`), `profiles.ledger_version`, `resolve_round_payouts`, `triple_chance_bets`, `get_my_round_result`, `get_current_round`.

#2 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** The entire client-side game engine — betting, a wall-clock-synchronized countdown (103-second cycle math, must match the server's `EXTRACT(EPOCH FROM NOW())` formula), and the full round-result lifecycle (`onGlobalResult`) with an optimistic-then-authoritative balance-reconciliation pattern. Win amounts computed entirely client-side from locally-snapshotted bets against server-provided digits (fixed multipliers ×9/×90/×900), with actual money reconciled asynchronously via `applyOptimisticBalance` + `_syncBalanceInBackground` (up to 4 retries). Unusually rich in documented, already-fixed bugs: Bug #7/#8, F-8, F-11, M-3, M-5, FIX #2/#3A/#3B, BUG #6, C-3, BUG-03.
► **Non-Coder Explanation:** The casino floor manager. Remembers every chip placed, runs the countdown clock synced to the server, computes wins the instant the wheel stops using only what's on the player's own screen, then quietly double-checks with the server in the background to correct any mismatch.

#2 (D): Game Functionality Structure
► **Constructor Initialization** — safe fallback play limits applied immediately (Bug #8 fix), then async-loads history and real limits.
► **Play Limits State** — non-nullable, server values override the fallback once fetched; silent no-op on fetch failure.
► **Balance Sync Failure Flag** — non-blocking UI warning (Bug #7 fix).
► **Bet Submission Status.**
► **Rejection State.**
► **Persisted Spin History** — SharedPreferences-backed, defensive try/catch.
► **Drawer/Mode Management** — blocked during spin or countdown ≤5.
► **Chip Selection.**
► **Single-Cell Bet Placement (`placeBet`)** — validates countdown/chip/balance/cap, mutates board, records undo, deducts balance, updates timer.
► **Row Bet Placement (`placeBetOnRow`)** — skips (not fails) capped cells, partial-fills on insufficient balance.
► **Random Bet Placement (`placeRandomBets`)** — refunds existing bets on the target board first, then randomly stakes.
► **Double Button (`doDouble`)** — "F-8"-fixed logic ensures undo-history entries double only for cells actually doubled (previously a documented mismatch bug).
► **Clear/Remove (Last/Cell/Row) Buttons.**
► **Rebet** — restores the previous round's full snapshot.
► **Global History Load** — "C-3" fix: only real settled rounds, no synthesized MD5 digits.
► **Countdown Engine** — self-healing every tick from wall-clock time; "F-11" fix replaced a hardcoded reset value.
► **Spin Abort** — see #4A for a confirmed gap here.
► **Global Round Result Handler (`onGlobalResult`)** — snapshots pre-clear bet state and balance, computes wins via multi-format (padded/unpadded) key lookups, drives an 8s wheel animation + a 5s result-display window, applies an optimistic balance update on a win, triggers background authoritative sync, then clears state — **unless aborted partway through, see #4A**.
► **Background Balance Reconciliation** — up to 4 retries, 2s apart.
► **Minimum Validation ("M-3" fix)** — client-side pre-check before submission, avoids a round trip the server would reject.
► **Rejected Bet Refund** — undoes a round's local deduction when the server rejects submission.
► **Triple Page Switching** — bets persist by key across page switches.

#2 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **[High severity, apparently unaddressed]** `abortSpin()` mid-round doesn't clear `_board`/`_history`/`_submittedBets` — every early-return in `onGlobalResult` on abort (`_spinAborted` checks) skips the tail cleanup block. **Confirmed cross-file** in `screens/game_screen.dart`'s `dispose()`, which never compensates either. A player exiting mid-spin can return to a stale, already-charged board.
  - Ambiguous padded/unpadded cell-key lookups in `onGlobalResult`'s win calculation could under-credit a win if a cell were ever double-staked under two key spellings. **Partially resolved** in `services/round_api_service.dart`: the server rejects malformed keys outright (fail-closed), confining this risk to client-side win-display math, not actual settlement.
  - `openDrawerWithMode`'s mode string is unvalidated — a typo silently shows `0` for that tab.
  - Redundant/dead fallback in the single-board key lookup (round-trips through `int.tryParse(...).toString()`, always identical to the primary lookup).
► 🗑️ **Unused / Dead Code:** None found within this file itself; `NOTE` comment confirms a legacy `doSpin` method was already cleanly removed (BUG-03).
► ⚔️ **Functionality Conflicts:**
  - Board identity modeled three different ways across the codebase (enum, plain mode strings, parallel named fields) — confirmed now spanning `models/` and `providers/`.
  - `_board.total`'s assumption that the local board always matches what the server accepted — self-healed by `_syncBalanceInBackground`'s `placedBetNotFound` branch, not an unguarded bug.
► 🔗 **Database & Web Dashboard Misalignment:** Fixed payout multipliers (×9/×90/×900) are hardcoded client-side constants for display prediction — **later found to have an exact structural twin, unfixed**: `widgets/overlays/info_dialog.dart`'s payout-rate cards, hardcoded the same way play-limits used to be before the documented "F-15" fix.

---

#3 (A) : `lib/providers/history_provider.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `HistoryProvider extends ChangeNotifier` — `pageSize = 50`; `_records, _page, _totalRecords, _totalStake, _totalPayout, _isLoading, _error`.
► Methods: `loadFirstPage, loadPage, _loadSessionTotals, clearLocal`.

#3 (B): Database & Backend Connections
► First file with **direct live Supabase queries**: `Tbl.bets` joined `rounds!inner(round_number, red, green, black)`.
► Columns: `id, round_id, single_bets, double_bets, triple_bets, total_stake, single_payout, double_payout, triple_payout, total_payout, is_settled, created_at`.
► Query: `.order('created_at', ascending: false).range(from, from+pageSize-1).count(CountOption.exact)`, optional `.gte('created_at', since)`.
► `_loadSessionTotals` runs a separate, unpaginated query on the same table, `.limit(10000)`, summed client-side.
► Explicit comment confirms RLS restricts returned rows to the signed-in player — no client-side user filter needed.

#3 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Direct Supabase query layer for personal bet/round history, paginating 50 at a time, joining each bet to its resolved round. Maintains session-wide totals via a second, independent full-session query. Documents two fixed bugs: "F-3" (a broken `hasMore` calculation that made page 2 unreachable, fixed via `CountOption.exact`), and a v1 issue where payouts were recomputed client-side and could disagree with the dashboard (now fixed by trusting stored server values directly).
► **Non-Coder Explanation:** The bank-statement printer for a player's history — fetches rounds 50 at a time, joined with the actual winning numbers, plus a running grand total.

#3 (D): Game Functionality Structure
► **Page Size Constant.**
► **First Page Load** — resets all local state, delegates to `loadPage(1)`.
► **Paginated Load** — guards against concurrent loads, queries with exact count, maps rows, triggers session totals reload.
► **Row-to-Model Mapping** — trusts stored `total_stake`/payouts directly, doesn't recompute.
► **`hasMore` Calculation** — the F-3-fixed pagination boundary check.
► **Session Totals** — up to 10,000 stake/payout pairs, summed client-side.
► **Local State Reset (`clearLocal`)** — no backend call, presumably on logout.

#3 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **Fetched-but-discarded `selections` data** — `single_bets`/`double_bets`/`triple_bets` are queried but the mapped `SpinResult.selections` is always `[]`. Likely an incomplete feature (a history detail screen intended to show which cells were bet on) rather than intentional waste.
  - `_loadSessionTotals`'s hardcoded `.limit(10000)` silently truncates totals for very active players/long date ranges.
  - `_loadSessionTotals` fails silently (`debugPrint` only, no `_error`) while `loadPage`'s main fetch surfaces a user-facing error — inconsistent posture within the same class.
  - Redundant full re-fetch of session totals on every page turn, not just the first load.
► 🗑️ **Unused / Dead Code:** `round_number` and `is_settled` are fetched but never used in the row mapping.
► ⚔️ **Functionality Conflicts:** None internally — single, consistent responsibility.
► 🔗 **Database & Web Dashboard Misalignment:**
  - Positive: payouts read directly from server-stored columns rather than recomputed client-side, specifically to prevent the app and dashboard disagreeing about the same hand — a genuine, deliberate fix.
  - `rounds!inner(...)` join means a bet whose round was ever pruned/deleted (a hypothetical retention policy) would silently vanish from history rather than showing with placeholder data.
  - The 10,000-row cap is itself a dashboard-drift risk if a long-tenured/high-volume player's real totals exceed it.

### `providers/` — Folder Completion Summary
1. **Architecture & Overview:** Three `ChangeNotifier` providers — session/balance, the entire game engine, and paginated history — registered once at the app root, living for the app's lifetime. Contains the highest concentration of documented historical bug-fixes in the codebase.
2. **Interdependencies:** `GameProvider` threads `AuthProvider` explicitly through nearly every mutating method rather than holding an internal reference. `AuthProvider.setUncommittedStakeGetter` is wired to `GameProvider.uncommittedStake` from `screens/game_screen.dart`. `HistoryProvider` is fully independent, relying on RLS alone.
3. **Bug & Conflict Summary:** Confirmed high-severity `abortSpin`/board-not-cleared bug; the "board identity modeled multiple ways" pattern now spans two folders; `UserModel.ledgerVersion` confirmed dead; several initially-flagged concerns (unguarded exceptions in login/heartbeat, the binary heartbeat-reason check) resolved by evidence found later in `services/`; `HistoryProvider`'s unused `selections` fetch and silent-failure totals path; the fixed payout multipliers here have an unfixed structural twin in `widgets/overlays/info_dialog.dart`.

---

<a name="screens"></a>
# 1.4 : `lib/screens/`

#1 (A) : `lib/screens/splash_screen.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `SplashScreen`/`_SplashScreenState` — `_ctrl, _scaleAnim, _fadeAnim`.
► External widget dependency: `LoadingBar3D`.

#1 (B): Database & Backend Connections
► None — pure timed transition screen, no network/Supabase calls.

#1 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** 900ms elastic-scale/fade-in animation, decoupled from a fixed 2400ms auto-navigation to `/login`.
► **Non-Coder Explanation:** The logo animation shown for ~2.4s on launch, then always sends the player to login.

#1 (D): Game Functionality Structure
► **Orientation Re-Lock** — redundant with `main.dart`'s identical call.
► **Animation Setup** — 900ms controller, elastic scale + fade tween confined to the first 50%.
► **Fixed-Delay Auto-Navigation** — waits 2400ms, `mounted`-guarded, then unconditional `pushReplacementNamed('/login')`.
► **Visual Composition** — background, vignette, centered animated logo + `LoadingBar3D`.
► **Cleanup** — disposes the controller.

#1 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - No existing-session check before navigating to `/login` — always routes there regardless of a valid saved session; unclear whether intentional (always-require-reauth for a real-money app) or a gap.
  - `mounted` check present but no explicit cancellation of the delayed `Future` itself — harmless in practice.
► 🗑️ **Unused / Dead Code:** None.
► ⚔️ **Functionality Conflicts:** Redundant portrait-lock call (first of three occurrences across the codebase — `main.dart`, here, and `login_screen.dart`). Animation timeline (900ms) is much shorter than the navigation delay (2400ms) with no shared constant tying them.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable — no backend interaction.

---

#2 (A) : `lib/screens/login_screen.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `LoginScreen`/`_LoginScreenState` — `_usernameCtrl, _passwordCtrl, _showPassword, _shaking`.

#2 (B): Database & Backend Connections
► Delegates entirely to `AuthProvider.login(username, password)`.
► Consumes new `LoginOutcome` fields: `success, error, sessionHeldElsewhere, secondsUntilFree` — implementing the documented **Q6** policy: a second-device login is refused, not allowed to displace the first.

#2 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Standard credential form. Trims and validates non-emptiness locally, awaits `AuthProvider.login`, routes to `/lobby` on success, branches into a specific "session held elsewhere" message on that particular failure, or falls back to the provider's generic error. A failed attempt triggers a "shake" via `TweenAnimationBuilder`.
► **Non-Coder Explanation:** The login form, with a specific "someone's already logged in elsewhere" message instead of a generic wrong-password error, so the player doesn't mistake it for a typo and keep retrying.

#2 (D): Game Functionality Structure
► **Text Controllers Setup/Teardown.**
► **Orientation Re-Lock.**
► **Login Submission (`_handleLogin`)** — clears prior error, trims inputs, local empty-field guard, delegates to provider, routes on success, branches on `sessionHeldElsewhere` otherwise.
► **Shake Feedback (`_shake`)** — toggles state for 500ms via `setState` + delayed reset.
► **Screen Composition.**
► **Card Shake Wrapper** — see #4A for a functional concern.
► **Card Content / Section Label / Username Field / Password Field.**
► **Login Button** — `Consumer`-driven, button entirely removed from the tree (not just disabled) while loading.
► **Error Message** — `Consumer`-driven conditional row.

#2 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **[Likely UI bug]** The shake-on-failure animation is probably non-functional. `TweenAnimationBuilder`'s `begin` value is only used on the very first build — subsequent tween changes animate from the widget's last rendered value toward the new `end`, and `end` is hardcoded to `0` in both shaking/non-shaking states. Since the widget starts at `0` and the target (`end`) never changes, there's likely no value to animate through — the card almost certainly never visibly moves.
  - **[Initially flagged, later resolved]** No try/catch around `auth.login(...)`. Confirmed via `services/api_service.dart`: `ApiService.login()` is fully exception-safe, so this was not a live risk.
  - Generic "Wrong username or password" shown for the empty-fields case, identical to an actual wrong-credential failure — possibly a deliberate security choice, possibly an oversight.
► 🗑️ **Unused / Dead Code:** The outer `AnimatedBuilder(animation: const AlwaysStoppedAnimation(0), ...)` wrapping the shake logic is inert — `AlwaysStoppedAnimation` never notifies listeners, so this wrapper only ever builds once and serves no purpose. Vestigial, likely from an earlier implementation attempt.
► ⚔️ **Functionality Conflicts:** Third occurrence of the redundant portrait-lock call.
► 🔗 **Database & Web Dashboard Misalignment:** `secondsUntilFree`'s accuracy/units depend entirely on the backend's cooldown calculation, unverifiable from this file alone.

---

#3 (A) : `lib/screens/lobby_screen.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `LobbyScreen`/`_LobbyScreenState` — static `_games` list (10 entries, only index 0 active), landscape lock.
► `_TopBar` — profile/disclaimer/balance/logout.
► `_SecurityAccountDialog`/`_SecurityAccountDialogState` — password-change + logout dialog.
► `_GameCard`/`_GameCardState` — game tile with press-scale feedback and locked-game dialog.
► `_GameInfo` — `name, imagePath, isActive`.

#3 (B): Database & Backend Connections
► No direct calls — delegates to `AuthProvider.changePassword`, `.logout`, and `HistoryProvider.clearLocal`.
► The 10-slot game catalog (`_games`) is entirely hardcoded client-side, with **no backend/entitlement query of any kind** — see #4D.

#3 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Landscape-locked grid of 10 game slots (only "Triple Chance" active). Security dialog carefully separates its own `BuildContext` (used only to pop itself) from a captured `lobbyContext` for all post-close operations, avoiding a mid-disposal context. Locked-game dialog auto-dismisses after 5s with an `isClosed` guard preventing a double-pop race.
► **Non-Coder Explanation:** The game selection lobby — one playable game, nine "Coming Soon" tiles that pop up a "contact your agent to activate this slot" message.

#3 (D): Game Functionality Structure
► **Static Game Catalog.**
► **Landscape Orientation Lock.**
► **Grid Layout.**
► **Top Bar** — responsive, `LayoutBuilder`-driven.
► **Security Dialog Trigger.**
► **Password Change Flow (`_handleChangePassword`)** — client-side validation chain (non-empty, 6+ chars, confirmation match, new≠current).
► **Logout Flow (`_handleLogout`)** — pops dialog, clears `HistoryProvider`, awaits `AuthProvider.logout()`, navigates if still mounted.
► **Password Field Builder.**
► **Locked Game Dialog** — 5s auto-dismiss, shared `isClosed` flag.
► **Game Card Interaction.**

#3 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - "LOGOUT ACCOUNT" doesn't guard against an in-flight password-change request (no `_isSubmitting` check, unlike "UPDATE PASSWORD") — a real, if narrow, unguarded concurrency edge case.
  - Client-side password minimum (6 chars) isn't sourced from any server-confirmed policy, unlike `PlayLimitsConfig`'s pattern elsewhere in the app.
► 🗑️ **Unused / Dead Code:** None found.
► ⚔️ **Functionality Conflicts:** No `WillPopScope`/`PopScope` handling on this screen — asymmetric with `game_screen.dart`, which has careful exit-confirmation handling.
► 🔗 **Database & Web Dashboard Misalignment:** **[Significant finding]** The locked-game dialog's own text ("Contact your agent to activate this slot") implies a per-account, agent-controlled entitlement system that **does not exist in the code** — `_games` is a `static const` list, identical for every user, with no server query of any kind for game access. Messaging promises functionality the current implementation cannot deliver.

---

#4 (A) : `lib/screens/game_screen.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `GameScreen`/`_GameScreenState` — `_allowPop`, `_gameProvider` (nullable — documented "F-7" crash fix).
► Methods: `initState, _handleEarlyBetSubmission, _handleSpin, dispose, _showExitConfirmation, _showBetRejectedDialog, _showInsufficientCoinsDialog, build`.
► `_NoConnectionBanner` — `_message`, `_icon` getters.

#4 (B): Database & Backend Connections
► Orchestrates `RoundSyncService` (`.attach, .detach, .submitBets, .fetchAndDeliverResult, .retry, .connectionError, .isConnected, .lastSubmitError, .betRoundId`).
► Reads `BetError` sentinels from `api_contract.dart`.
► `_showBetRejectedDialog`'s `reason` is documented as coming from `RoundApiService._mapSubmitError` — **this method name does not exist**; the actual method is the public `mapError` (confirmed comment drift, see `services/round_api_service.dart` #4C).

#4 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Main gameplay screen. Wires bet submission at two moments: `_handleEarlyBetSubmission` (countdown=5, "NO MORE PLAY") and `_handleSpin` (draw boundary — fallback submitter + unconditional result-fetch trigger for every player). Handles four dialog/banner states with well-documented rationale: exit confirmation, bet rejection (6 causes, "M-3" fix), insufficient coins, and a connection banner explicitly fixed to report the real cause instead of always saying "NO_CONNECTION."
► **Non-Coder Explanation:** The actual game table — wheel, boards, controls, and every "something went wrong" message a player might see.

#4 (D): Game Functionality Structure
► **Screen Init** — sound flag, landscape lock, deferred (post-frame) provider wiring: captures `GameProvider`, wires the uncommitted-stake getter into `AuthProvider`, registers spin/no-bets callbacks, attaches `RoundSyncService`.
► **Early Bet Submission** — closes drawer, marks submitted, validates minimums, submits via `RoundSyncService`, refunds+dialogs on rejection.
► **Spin Trigger** — submits only if not already marked submitted (fallback safety net), then unconditionally fetches/delivers the result.
► **Cleanup (`dispose`)** — see #4A for a confirmed gap.
► **Exit Confirmation** — 5s auto-dismiss defaulting to "stay," shared `isClosed` guard.
► **Bet Rejection Dialog** — 6-reason switch (BELOW_MIN, EXCEEDS_MAX, INSUFFICIENT_COINS, ROUND_CLOSED, UNAUTHENTICATED, OFFLINE, default).
► **Insufficient Coins Dialog.**
► **Build-Time Deferred Side Effects** — "consume-once" pattern: synchronously clears non-notifying flags, schedules the actual dialog/snackbar via `addPostFrameCallback`.
► **Screen Layout** — `PopScope`-gated; hardcoded `158.0` (tab-strip width) and `28%` (right-panel fraction) layout constants — see #4C.
► **No-Connection Banner** — maps `BetError` sentinels to specific messages, honest fallback for unrecognized reasons.

#4 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **[Confirmed, cross-file]** `dispose()` never clears `_board`/`_history` — no compensation for `GameProvider.abortSpin()`'s own gap (see `providers/game_provider.dart` #4A).
  - **[New]** `dispose()`'s `game.clearSpinHistory()` permanently empties in-app spin history for the rest of the session, since `_loadDrawnNumbersHistory()` only reloads once, in the `GameProvider` constructor. Compounds the (otherwise-harmless) SharedPreferences key duplication found in `providers/`/`services/`, and confirmed to also degrade `widgets/overlays/info_dialog.dart`'s history fallback.
  - `auth.logout()` not awaited in `_NoConnectionBanner`'s "LOG IN" handler — inconsistent with `lobby_screen.dart`'s correctly-awaited equivalent.
► 🗑️ **Unused / Dead Code:** None found.
► ⚔️ **Functionality Conflicts:**
  - Hardcoded `158.0` and `0.28` layout constants — **later confirmed** in `widgets/panels/left_tab_strip.dart` to be independently duplicated there too, with the `0.28` case being the more consequential (feeds a live grid-width computation).
  - Dual bet-status tracking (`GameProvider._submittedBets` vs. `_betStatus`) — **later confirmed safe by design** once `services/round_sync_service.dart` was audited.
► 🔗 **Database & Web Dashboard Misalignment:** Positive: the no-connection banner's "honest reason" fix is a genuine, well-documented improvement over a prior all-failures-are-"NO_CONNECTION" bug. Comment drift confirmed: references a nonexistent `RoundApiService._mapSubmitError` method (see backend map #C).

### `screens/` — Folder Completion Summary
1. **Architecture & Overview:** Four screens matching `main.dart`'s route table. Portrait for splash/login, landscape for lobby/game (a real requirement), though the portrait lock itself is redundantly re-asserted three times.
2. **Interdependencies:** `GameScreen` is the most complex node, directly characterizing `RoundSyncService`'s full public surface. `LobbyScreen`/`GameScreen` share a dialog-chrome pattern (not extracted into a shared widget).
3. **Bug & Conflict Summary:** Confirmed cross-file `abortSpin`/dispose board-clearing gap; new dispose-time spin-history-wipe bug; `LobbyScreen`'s hardcoded game catalog contradicting its own agent-activation messaging; likely-non-functional login shake animation; asymmetric back-button handling between `LobbyScreen` and `GameScreen`; several earlier-flagged concerns resolved by this folder's own evidence.

---

<a name="services"></a>
# 1.5 : `lib/services/`

#1 (A) : `lib/services/api_contract.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `Rpc` — 8 RPC name constants: `sessionLogin, sessionHeartbeat, sessionLogout, getPlayLimits, getCurrentRound, getRecentRounds, placeBet, getMyRoundResult`.
► `RpcParam` — `sessionToken, roundId, singleBets, doubleBets, tripleBets, limit`.
► `Field` — response-key constants across Money/Session/Round/Bet domains.
► `Tbl` — `profiles, bets, rounds` (direct-read tables; all writes go through RPCs).
► `ReasonCode` — `accountBlocked, sessionActiveElsewhere` (login-only), `sessionDisplaced` (heartbeat-only).
► `ErrCode` — 10 Postgres error codes, `P0100`–`P0125`.
► `BetError` — 9 UI-facing sentinel constants, deliberately separate from `ErrCode`.

#1 (B): Database & Backend Connections
► This file **is** the database/API map — the single shared naming contract, explicitly cross-referenced to a specific SQL migration file (`20260807000200_rebuild_v2_functions.sql`).
► Designed to make a backend rename a compile error rather than a silent no-op, citing the `agentName`/`agent_name` incident by name.

#1 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Pure constants file, zero logic. Every cross-system name declared once. Documents specific backend business rules in comments: session takeover is refused rather than allowed, and the server (not the client) is authoritative for computed stake totals.
► **Non-Coder Explanation:** The official shared dictionary between the app and the server — so a backend rename fails the build instead of quietly breaking the app.

#1 (D): Game Functionality Structure
► **RPC Registry** — 8 procedure names with documented signatures and behavioral notes.
► **RPC Parameter Registry.**
► **Response Field Registry** — every JSON key the app reads.
► **Direct-Read Table Registry** — 3 tables, writes-via-RPC-only architecture.
► **Session Disallow Reasons** — 3 reasons, each scoped to which RPC can return it.
► **Postgres Error Code Registry** — 10 codes.
► **UI Sentinel Registry** — 9 presentation-layer sentinels.

#1 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** Two `ErrCode` values (`notAPlayer` P0114, `roundNotFound` P0120) initially appeared to have no `BetError` counterpart. **Later found** in `round_api_service.dart`: `roundNotFound` *is* actually handled (aliased to `roundClosed`); only `notAPlayer` remains genuinely unmapped.
► 🗑️ **Unused / Dead Code:** `Tbl.rounds` may be unused as a Dart identifier — the actual join in `history_provider.dart` uses PostgREST's inline relation-name syntax, not the constant.
► ⚔️ **Functionality Conflicts:**
  - **Documentation drift**: `submit_round_bet` used here correctly in past-tense (describing a v1 bug), but used present-tense in `providers/play_limits_config.dart`/`game_provider.dart` comments to describe *current* behavior — the actual current RPC is `place_bet`.
  - **Documentation drift**: `P0007` (stale, in `play_limits_config.dart`) vs. actual `ErrCode.belowMin = 'P0123'`.
  - Positive: resolves the `AuthProvider` binary heartbeat-reason concern — `sessionActiveElsewhere` is login-only, `sessionDisplaced` is heartbeat-only, confirming that check is exhaustive.
► 🔗 **Database & Web Dashboard Misalignment:** This file is the primary defense against exactly the naming-drift bug class this codebase has already been bitten by once (the `agentName` incident).

---

#2 (A) : `lib/services/api_service.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `LoginOutcome` — `success, profile, error, sessionHeldElsewhere, secondsUntilFree`.
► `ApiService` (singleton) — `emailFor, login, heartbeat, logout, fetchProfile, changePassword`.

#2 (B): Database & Backend Connections
► `_db.auth.signInWithPassword`, `_db.rpc(Rpc.sessionLogin/.sessionHeartbeat/.sessionLogout)`, `_db.from(Tbl.profiles).select(...)`, `_db.auth.updateUser(...)`.
► Identity convention: `email = lower(username) || '@bestsmartgame.com'`, DB CHECK-enforced.

#2 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Auth/profile service layer — **resolves two previously-speculative concerns**: `login()` and `heartbeat()` are fully wrapped in try/catch across every I/O call, never propagating an exception. Documents two more resolved bugs: "M-6" (a duplicate, driftable dashboard login implementation, eliminated) and the Q6 single-device-session refusal policy.
► **Non-Coder Explanation:** The "front desk" — signs in, verifies you're a player (not staff), keeps the session alive, signs out cleanly, fetches profiles, and changes passwords (by re-signing-in with the old password as proof).

#2 (D): Game Functionality Structure
► **`LoginOutcome`.**
► **`emailFor`.**
► **`login`** — fully exception-safe, 3 distinct `allowed=false` branches + a role check.
► **`heartbeat`** — returns `null` on any error.
► **`logout`** — correct ordering: `session_logout` before `auth.signOut()`.
► **`fetchProfile`.**
► **`changePassword`** — re-authentication as a password-verification proxy.

#2 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **[New]** A rejected staff-account login (role check fails *after* `session_login` already succeeded and claimed a session) only calls `auth.signOut()`, never `session_logout` — unlike the correctly-ordered `logout()` method two methods below it. Could leave an orphaned claimed session server-side.
  - **[New]** `changePassword`'s re-authentication may rotate the session's access token; neither this method nor `AuthProvider.changePassword` updates the cached `token` afterward. Could silently degrade heartbeat calls post-password-change (masked by `heartbeat()`'s designed-safe null-on-error return).
  - Bare-`String` throws in `changePassword` instead of proper `Exception` types.
► 🗑️ **Unused / Dead Code:** `fetchProfile` not called from any file audited so far.
► ⚔️ **Functionality Conflicts:** `emailFor`'s `@`-passthrough branch has no validation — a mistyped full email as "username" fails with only a generic message.
► 🔗 **Database & Web Dashboard Misalignment:** Confirms zero inline-string contract violations — fully disciplined use of `api_contract.dart` constants throughout.

---

#3 (A) : `lib/services/auth_service.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `AuthService` — `_keyUser, _keySessionStart, keyDrawnNumbers = 'bsg_drawn_numbers_history'`.
► Methods: `saveSession, loadSession, clearSession`.

#3 (B): Database & Backend Connections
► None — pure local SharedPreferences persistence.
► `bsg_auth_user` (JSON `UserModel.toJson()`, token excluded), `bsg_session_start_at`, `bsg_drawn_numbers_history` (confirmed the exact key `game_provider.dart` uses).

#3 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Documents fix **"F-10"**: the drawn-numbers history key is deliberately cleared at every session boundary (login and logout) so one player's history can't bleed into the next player's session on a shared device. The comment explicitly names the v1 bug this replaces: "v1 wrote this key but never removed it, and cleared an unrelated key instead."
► **Non-Coder Explanation:** The session filing cabinet — saves just enough profile to render the UI instantly on next launch (without the secret token), and makes sure history is wiped clean at every login/logout boundary.

#3 (D): Game Functionality Structure
► **Save Session** — persists user + start time, removes drawn-numbers key.
► **Load Session** — defensive, `null` on any parse failure.
► **Clear Session** — removes all three keys.

#3 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None found in this file's own logic.
► 🗑️ **Unused / Dead Code:** **[Confirms and resolves an earlier finding]** This file's own comment describes exactly what `main.dart`'s `'bsg_local_game_history'` startup-clear line still does today. A codebase-wide grep confirms that key is written/read nowhere else. This **meaningfully downgrades** the earlier "does history leak between players?" concern: it does not — this file correctly handles that at the true session boundary. Only `main.dart`'s line is dead code.
► ⚔️ **Functionality Conflicts:** `game_provider.dart` hardcodes the literal `'bsg_drawn_numbers_history'` instead of referencing `AuthService.keyDrawnNumbers` — currently matching, but an unenforced duplicate.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable — no backend interaction.

---

#4 (A) : `lib/services/round_api_service.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `GlobalRoundState`, `PlaceBetResult`, `PlayerRoundResult`, `RecentRound` — typed RPC result models.
► `RoundApiService` (singleton) — `mapError, lastRoundError, getCurrentRound, placeBet, getMyRoundResult, getRecentRounds, getPlayLimits`.

#4 (B): Database & Backend Connections
► `_db.rpc(Rpc.getCurrentRound)`, `.placeBet(params: {roundId, singleBets, doubleBets, tripleBets})`, `.getMyRoundResult(roundId)`, `.getRecentRounds(limit)`, `.getPlayLimits()` — all five round RPCs consumed here.
► `mapError` cross-references `ErrCode.*` (Postgres codes) to `BetError.*` (UI sentinels) — this is the actual implementation the "M-3"/`game_screen.dart` comments allude to (under a different, incorrectly-named method).

#4 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Round-lifecycle RPC gateway with a centralized error-mapping function (code-first, text-fallback matching). Class-doc documents a **resolved security/integrity issue**: v1 allowed round data — including winning digits — to be fetched via the anon key with no session; v2 hides `rounds` via RLS until settled, RPCs granted to `authenticated` only.
► **Non-Coder Explanation:** The "round desk" — asks the server what round is active, submits bets, checks results, fetches history, fetches limits, and translates cryptic database errors into plain-English categories.

#4 (D): Game Functionality Structure
► **`GlobalRoundState`** — phase/timing/digits, `acceptsBets` derived logic.
► **`PlaceBetResult`** — server-authoritative response, including server-recomputed stake.
► **`PlayerRoundResult`** — read-only settlement status (actual settlement happens in `settle_round`, a separate function).
► **`RecentRound`.**
► **Error Mapping (`mapError`)** — fixed priority order: unauthenticated → blocked → insufficient → below-min → exceeds-max → round-closed → round-not-found (aliased) → bad-key → empty-bet → default.
► **Current Round Fetch** — records `lastRoundError` on every call.
► **Bet Placement** — relies entirely on server-side key-format/limit validation.
► **My Round Result** — `null` uniformly on any failure.
► **Recent Rounds** — defensive type-check on response shape.
► **Play Limits** — the only one of the five RPC wrappers with no dedicated typed result class.

#4 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **[High-value finding]** `mapError`'s catch-all default (`return BetError.offline`) contradicts the codebase's own documented design goal of not conflating server errors with network errors (per `game_screen.dart`'s `_NoConnectionBanner` comment). Any unrecognized error — including the genuinely unmapped `ErrCode.notAPlayer` — is still funneled into "no internet connection," undermining that fix at its actual source.
  - First-checked substring match (`'auth'`) is unusually broad and positioned first in the priority chain — could misclassify an unrelated error type.
  - `getMyRoundResult`'s blanket catch doesn't distinguish a true transport failure from a malformed-response bug — both trigger the same 4-attempt retry in `GameProvider._syncBalanceInBackground`.
► 🗑️ **Unused / Dead Code:** None found — every class/method is consumed by `providers/`/`services/round_sync_service.dart`.
► ⚔️ **Functionality Conflicts:** `getPlayLimits` is the only RPC wrapper without a dedicated typed result class — internal design inconsistency, not a functional bug. `ErrCode.roundNotFound` is actually handled (aliased to `BetError.roundClosed`) — partially resolves the `api_contract.dart` concern.
► 🔗 **Database & Web Dashboard Misalignment:**
  - Positive: the documented v1→v2 fix closing pre-authentication round-data exposure is a genuinely significant integrity fix for a real-money product.
  - Bet-key format correctness is fully delegated to server-side validation — resolves part of the `game_provider.dart` key-ambiguity concern (malformed keys are rejected outright, not silently mis-settled).

---

#5 (A) : `lib/services/round_sync_service.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `RoundSyncService extends ChangeNotifier` (singleton) — `_currentRound, _betRoundId, _isConnected, _isConnecting, _connectionError, _failedPollCount, _lastSubmitError, _deliveredRoundNumber, _serverTimeOffset, _pollTimer, _pollInFlight`.
► Methods: `_calibrateServerTimeOffset, attach, detach, _startPolling, _poll, _fetchInitialRound, fetchAndDeliverResult, submitBets, _deliverResult, retry`.

#5 (B): Database & Backend Connections
► Wraps `RoundApiService`: repeated calls to `getCurrentRound()` (attach, every 2s poll, up to 8 attempts in `fetchAndDeliverResult`), and `placeBet(...)`.
► **Confirms** the dual bet-status tracking is real and safe by design: `submitBets` sets `game.setBetStatus(BetSubmissionStatus.submitted/.failed, ...)` here.

#5 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Orchestration layer replacing a documented prior design (round data read only twice per cycle, causing stale-round bets and missed-tick result delivery). Makes delivery "level-triggered rather than edge-triggered" via continuous 2s polling + an 8-attempt draw-boundary fallback, both sharing a single `_deliveredRoundNumber` exactly-once delivery guard — verified safe against concurrent-path races via Dart's single-threaded continuation semantics.
► **Non-Coder Explanation:** The synchronization clerk — keeps the app's clock matched to the server's, makes sure the wheel always actually spins with a real result even if the exact tick was missed, and prevents a bet from ever being submitted twice.

#5 (D): Game Functionality Structure
► **Server Clock Calibration** — recomputed on every successful round fetch.
► **Attach/Detach** — lifecycle hooks called from `game_screen.dart`.
► **Continuous Polling** — every 2s, 2-consecutive-failure debounce before flagging disconnection.
► **Initial Round Fetch** — mid-spin catch-up if the player joins during a draw.
► **Robust Result Delivery** — 8-attempt, 1s-spaced loop at the draw boundary.
► **Bet Submission** — idempotency-checked (skips if already submitted/in-flight for the current round), re-anchors balance via `syncAuthoritativeBalance` on success.
► **Result Delivery (`_deliverResult`)** — see #4A for a redundancy finding.
► **Manual Retry.**

#5 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **[New]** `_deliverResult` calls both `game.onGlobalResult(...)` (manually inserts a rich locally-computed history entry) *and* `game.loadGlobalHistory()` (immediately overwrites `_globalHistory` with a placeholder-only server refetch) back-to-back — the richer local insert is always immediately superseded, plus a wasted network round-trip on every single round delivery.
  - Duplicated 103-second cycle-boundary formula, independently reimplemented here and in `game_provider.dart`.
  - Overlapping polling during the draw window (2s background poll + 8-attempt/1s loop running simultaneously) — real, avoidable load at the highest-contention moment; safe from a correctness standpoint thanks to the shared delivery guard.
► 🗑️ **Unused / Dead Code:** None found.
► ⚔️ **Functionality Conflicts:** **Confirms** the `_submittedBets`/`_betStatus` dual-tracking is deliberate and safe — this file is where `_betStatus` is actually set, on a different lifecycle than `_submittedBets`.
► 🔗 **Database & Web Dashboard Misalignment:** Positive — correctly implements the documented v2 fix: the server recomputes stake; no client-sent total is ever transmitted.

---

#6 (A) : `lib/services/sound_service.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `SoundService` (singleton) — `_player, _sfxPlayer, _voicePlayer, isMuted` (public, unencapsulated), `_isInGameScreen, _fadeSessionId`.
► Methods: `setInGameScreen, playSpinStart/Stop, playWin, playLose, playChipClick, playButtonClick, playNumberSelect, playRimSelect, playNoBets, playNotification, toggleMute, mute, unmute, stopAll, dispose`.

#6 (B): Database & Backend Connections
► None — local audio playback via `audioplayers`, loading assets from `assets/sounds/`.

#6 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Three independent `AudioPlayer`s for layered playback (main/SFX/voice). `playSpinStop()` implements a manual volume fade-out with a session-ID cancellation token so a new spin cleanly aborts a prior fade-out.
► **Non-Coder Explanation:** The app's sound board — spin sounds, win/lose chimes, button clicks, a "no more bets" voice line, routed through three independent channels so a click doesn't cut off the spinning-wheel sound.

#6 (D): Game Functionality Structure
► **Initialization** — global audio context config, once, in the private constructor.
► **In-Game Screen Flag** — stops the voice player when leaving the game screen.
► **Category Playback Helpers** — stop-then-play per category; muted state and playback errors both silently no-op'd.
► **Spin Start** — bumps the fade-session ID, cancelling any in-progress fade-out.
► **Spin Stop with Fade** — documented as 500ms, actually ~550ms (11 iterations × 50ms).
► **Named Sound Triggers.**
► **No-Bets Voice Line** — gated on `_isInGameScreen`.
► **Mute Controls.**
► **Stop All / Dispose.**

#6 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - `playSpinStop()`'s actual fade duration is ~550ms, not the documented 500ms — a minor off-by-one.
  - **Every playback error is swallowed with zero logging** — unlike every other service in this codebase, which consistently `debugPrint`s caught exceptions. The justifying comment ("Sound files may not exist yet") reads like an unrevisited dev-time accommodation that could equally mask a genuine bug.
► 🗑️ **Unused / Dead Code:** `playLose()` appears unused — no round-outcome-handling code anywhere calls it (only `playWin()` is called on a win, with no corresponding call on a loss). `dispose()` likely never called (singleton, no call site found).
► ⚔️ **Functionality Conflicts:** `isMuted` is a public, directly-mutable field — bypassing it (instead of `mute()`/`toggleMute()`) would suppress future sounds but not stop currently-playing ones.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable — no backend interaction.

### `services/` — Folder Completion Summary
1. **Architecture & Overview:** Six files — the shared contract, auth/profile, local session persistence, round RPCs, round orchestration, and audio — the folder with the richest documented bug-fix history in the app, including a genuine resolved security/integrity issue.
2. **Interdependencies:** `api_contract.dart` underpins everything; `round_sync_service.dart` sits above `round_api_service.dart` and is directly depended on by `providers/`.
3. **Bug & Conflict Summary:** `mapError`'s still-conflating catch-all (undermines a documented fix elsewhere); a real orphaned-session risk on staff-account rejection; a real silent-heartbeat-degradation risk after password change; a redundant/overwriting double-fetch in round delivery; three confirmed instances of comment-only documentation drift; several earlier speculative concerns fully resolved by this folder's evidence.

---

<a name="theme"></a>
# 1.6 : `lib/theme/`

#1 (A) : `lib/theme/app_colors.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `AppColors` — static-only class; ~35 named `Color` constants (Backgrounds, Gold system, Wheel ring colors, Cell colors, UI), plus 7 named `LinearGradient` constants.

#1 (B): Database & Backend Connections
► None — pure visual design tokens.

#1 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Flat, static color palette — no logic, no state, purely `const` declarations, organized by usage area.
► **Non-Coder Explanation:** The app's paint palette — every color used anywhere is defined once by name.

#1 (D): Game Functionality Structure
► **Background Colors** (4). #B **Gold System** (5). #C **Casino Accent Colors.** #D **Wheel Ring Colors** (paired shades). #E **Cell Colors** — see #4B, later found unused. #F **UI Colors.** #G **Gradients** (7).

#1 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None — a pure constants file has no executable logic.
► 🗑️ **Unused / Dead Code:** Cannot determine usage from this file alone — several colors (`cellSelTop/Bot`, `blueLens/blueLensDark`, `historyStart/End`) hadn't appeared in any file audited yet. **Later confirmed**: `cellGreenTop/Bot/Border`/`cellPinkTop/Bot/Border`/`cellSelTop/Bot` are dead (see `widgets/panels/grid_cells.dart` #4B), and `blueLens`/`blueLensDark` are dead (see `widgets/wheel/result_lens.dart` #4B).
► ⚔️ **Functionality Conflicts:** Several named constants share identical hex values under different names (`bgPanel`/`blackRim`, `goldBright`/`textGold`, `casinoGreen`/`greenRing2`, `darkRed`/`tabDarkerRed`); gradients re-type raw literals instead of referencing the named single-color constants. Currently self-consistent, but no single source of truth.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

---

#2 (A) : `lib/theme/app_decorations.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► Parameterized functions: `goldBorderPanel, textField, goldButton, actionButton`.
► Fixed static decorations: `loginCard, cellGreen, cellPink, cellSelected, cellBetPlaced, rightPanel, leftTabStrip, activeTab, drawerPanel, gridFrame, lobbyCard, resultCard, balanceBox`.

#2 (B): Database & Backend Connections
► None — pure UI decoration definitions.

#2 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Static library of pre-built `BoxDecoration`/`InputDecoration` objects for every major visual surface, composing `AppColors` for borders/fills but layering in independent raw hex literals for many shadow colors and cell-state gradients.
► **Non-Coder Explanation:** The "stencil kit" for the app's visual style — pre-made templates so every screen looks consistent.

#2 (D): Game Functionality Structure
► **Gold Border Panel.** #B **Login Card.** #C **Text Field Decoration.** #D **Gold Button.** #E **Action Button.** #F **Betting Cell States** (`cellGreen/cellPink/cellSelected/cellBetPlaced`) — see #4B, a significant finding. #G **Structural Panels** (right/left/active-tab/drawer). #H **Smaller Elements** (grid frame, lobby card, result card, balance box).

#2 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None — declarative styling only.
► 🗑️ **Unused / Dead Code:** **[Significant finding]** `app_colors.dart`'s dedicated "Cell colors" (`cellGreenTop/Bot/Border`, `cellPinkTop/Bot/Border`, `cellSelTop/Bot`) do not match this file's actual `cellGreen`/`cellPink`/`cellSelected` decorations at all — strong evidence of dead constants. **Later proven conclusively** in `widgets/panels/grid_cells.dart` #4B: a *third*, different, and actually-live set of values is what really renders.
► ⚔️ **Functionality Conflicts:** Systemic raw-literal duplication of `AppColors` shadow-alpha variants throughout. Inconsistent `const`-ness across static decorations (only `leftTabStrip` uses `const`).
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

---

#3 (A) : `lib/theme/app_text_styles.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `AppTextStyles` — `gameTitle, number, numberMedium, countdown, label, labelLight, button, balance, sectionHeader` — parameterized `TextStyle` factories.

#3 (B): Database & Backend Connections
► None — pure typography definitions across two font families (DMSans, Oswald).

#3 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Parameterized `TextStyle` factories with sensible default colors from `AppColors`, several with a matching glow shadow.
► **Non-Coder Explanation:** The app's font styling cookbook — pre-defined text looks for every category of text.

#3 (D): Game Functionality Structure
► **Game Title.** #B **Number.** #C **Number Medium.** #D **Countdown.** #E **Label / Label Light.** #F **Button.** #G **Balance.** #H **Section Header.**

#3 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None functionally — pure typography config.
► 🗑️ **Unused / Dead Code:**
  - ~~An earlier pass here claimed `number()`/`countdown()`/`balance()` (all `FontWeight.w700` for Oswald) were unregistered in `pubspec.yaml` and rendered as synthesized/fake bold.~~ **CORRECTED** — a follow-up direct read of the full `pubspec.yaml` (Section 9 below) found the earlier `grep` output had been truncated before reaching the Oswald-Bold entry. **`Oswald-Bold.ttf` at weight 700 is correctly registered.** `number()`/`countdown()`/`balance()` are not affected by any font-synthesis issue. This correction is recorded here rather than silently removed.
  - `assets/fonts/Oswald-Light.ttf` (300) exists on disk (confirmed in the `widgets/` folder listing) but is registered nowhere in `pubspec.yaml` and requested nowhere in code — this part of the original finding still holds: a genuinely dead font asset.
► ⚔️ **Functionality Conflicts:** None found within this file.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

### `theme/` — Folder Completion Summary
1. **Architecture & Overview:** Pure declarative design system, no logic, so no runtime bugs possible.
2. **Interdependencies:** `app_decorations.dart` and `app_text_styles.dart` both build on `app_colors.dart`.
3. **Bug & Conflict Summary:** The cell-color three-way fragmentation (confirmed dead constants in two of three files); systemic literal-duplication throughout, consistent with the broader "no single source of truth" pattern found across the whole app. (The originally-claimed Oswald weight-700 gap was a research error, corrected in Section 9; a narrower, real gap remains only at weight 800, affecting `result_overlay.dart` specifically.)

---

<a name="widgets"></a>
# 1.7 : `lib/widgets/`

*(Corrected from an initial mis-scan: this folder is not empty — 10 files across `common/`, `controls/`, `overlays/`, `panels/`, `wheel/`.)*

#1 (A) : `lib/widgets/common/loading_bar.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `LoadingBar3D` — `StatefulWidget`; params `width` (220), `height` (18), `label` ('LOADING...').
► `_LoadingBar3DState` — `_ctrl` (`AnimationController`), `_fill` (`Animation<double>`).

#1 (B): Database & Backend Connections
► None — pure presentational widget, already confirmed used in `splash_screen.dart` and `login_screen.dart`.

#1 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Reusable loading-bar widget — outer metallic-gold frame, dark inner channel, animated gold-gradient fill, top sheen, bottom shadow, glowing tip tracking the fill's leading edge.
► **Non-Coder Explanation:** The fancy gold progress bar shown while loading or signing in.

#1 (D): Game Functionality Structure
► **Widget Parameters.** #B **Animation Setup** — 2200ms controller, `.forward()`. #C **Layered Visual Composition.** #D **Cleanup.**

#1 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** **[Confirmed]** The widget's own doc comment claims the fill "loops continuously," but `_ctrl.forward()` runs once and never repeats — the bar sits fully filled indefinitely once its 2.2s animation completes. Misleading during a longer real wait (e.g., a slow login taking more than 2.2s shows "SIGNING IN..." next to a bar that already reads as 100% done).
► 🗑️ **Unused / Dead Code:** None found.
► ⚔️ **Functionality Conflicts:** None found.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

---

#2 (A) : `lib/widgets/controls/right_panel.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `RightControlPanel` — composes `_PanelHeader, _StatsPanel, _HistoryGrid, _ControlArea`.
► `_VerticalChips, _ActionColumn, _ActionBtn, _CountdownBox/_CountdownBoxState`.

#2 (B): Database & Backend Connections
► No direct calls — consumes `GameProvider`/`AuthProvider` via `Consumer`/`Consumer2`, dispatches to their already-audited methods.
► Uses `InfoDialog.show(context)` for the INFO button.

#2 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** The right-hand control panel — flashing status header, compact stats readout, 10-column recent-results digit grid, vertical chip tray, four action buttons, pulsing countdown box. Interaction uniformly gated by `game.countdown <= 5 || game.isSpinning`.
► **Non-Coder Explanation:** The right-side control strip — stakes/wins, last 10 results, chip tray, action buttons, and the big countdown number.

#2 (D): Game Functionality Structure
► **Panel Header** — flashes "No More Play" in the last 5s of betting; close (X) button correctly routes through `game_screen.dart`'s `PopScope` exit-confirmation flow.
► **Stats Panel** — PLAY/WIN/BALANCE, auto-shrinking via `FittedBox`.
► **History Grid** — 10×3 digit grid, newest on the left.
► **Chip Tray** — locked during the last 5s or while spinning.
► **Action Buttons** — INFO/DOUBLE-REBET toggle/CLEAR/REMOVE.
► **Countdown Box** — turns red and pulses once ≤8s remain and a bet is on the board.

#2 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None additional beyond the systemic findings below.
► 🗑️ **Unused / Dead Code:** `_VerticalChips`'s `Opacity(opacity: 1.0, ...)` wrapper is a no-op — chips don't visually dim when locked, unlike action buttons which do dim to 40%.
► ⚔️ **Functionality Conflicts:**
  - **[Significant, systemic]** The countdown number uses `GoogleFonts.oswald(...)` instead of the locally-bundled `'Oswald'` family used elsewhere — redundant (already bundled — including at weight 700, confirmed correct in the `pubspec.yaml` audit) and carries a network-fetch risk on first use with no local-bundling config visible in `pubspec.yaml`. (An earlier version of this finding also claimed a "fake-bold vs. genuine-bold" rendering side effect — that part is retracted, since local Oswald w700 is correctly registered, not synthesized. The redundancy/network-dependency issue itself still stands.)
  - `_ActionBtn` immediately overrides `AppDecorations.actionButton()`'s own border/shadow via `.copyWith` — that function's border/shadow values are unreachable from this call site.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

---

#3 (A) : `lib/widgets/panels/grid_cells.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `NumberCell` — `number, isEven, onTap, fontSize, stakedAmount`.
► `RowArrowButton`, `ColArrowButton`, `RandomShortcutButton`.

#3 (B): Database & Backend Connections
► No direct calls — dispatches to `GameProvider.placeBetOnRow/removeChipFromRow/placeRandomBets`, all previously audited.
► Cell-key generation correctly produces canonical zero-padded strings for both double and triple boards.

#3 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Defines the actual betting-grid cell widget plus row/column/random-bet buttons. `NumberCell` has two visual states: unbet (green/pink) and bet-placed (red gradient + animated gold "dome" showing the staked amount).
► **Non-Coder Explanation:** The actual number tiles players tap to bet — green/pink squares that turn red with a gold coin-bubble once bet.

#3 (D): Game Functionality Structure
► **Number Cell** — responsive sizing via `LayoutBuilder`.
► **Row Arrow Button.**
► **Column Arrow Button.**
► **Random Shortcut Button.**

#3 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None found — sizing, key generation, and animation logic are internally consistent.
► 🗑️ **Unused / Dead Code:** **[Definitively confirmed, highest-value finding among the design-system issues]** `NumberCell` — the widget that actually renders every betting cell — uses a *third*, independent set of green/pink values matching **neither** `app_colors.dart`'s `cellGreenTop/Bot/Border` etc. **nor** `app_decorations.dart`'s `cellGreen`/`cellPink` decorations, and a completely different bet-placed visual (red + animated gold dome) than `app_decorations.dart`'s `cellBetPlaced` (plain amber fill). Conclusively confirms those two files' cell-related constants/decorations are dead code.
► ⚔️ **Functionality Conflicts:** `GoogleFonts.oswald` used 3× in this file (number, staked-amount, random-count text) — further confirms the systemic pattern.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

---

#4 (A) : `lib/widgets/panels/grids.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `GridSingle`, `GridDouble`/`_DoubleBody`, `GridTriple`/`_TripleBody`.
► `math_min` — top-level function, a hand-rolled reimplementation of `dart:math`'s `min`.

#4 (B): Database & Backend Connections
► No direct calls — reads `game.board.*`, `game.activeChip`, `game.triplePage`, dispatches to `GameProvider` methods.

#4 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** The three concrete betting-board layouts, each computing a responsive square cell size via `LayoutBuilder`, laying out a `GridView.builder` alongside arrow/random-shortcut strips.
► **Non-Coder Explanation:** Lays out the three actual betting boards players interact with.

#4 (D): Game Functionality Structure
► **Single Board** — 2×5 grid.
► **Double Board** — 10×10, row/random/column strips.
► **Triple Board** — same layout plus a 10-tab page selector.
► **Custom Min Helper** — see #4B.

#4 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None found — sizing math and page-tab logic correctly cross-referenced against `GameProvider`'s triple-page model.
► 🗑️ **Unused / Dead Code:** `math_min` reimplements functionality already available from `dart:math` (which `game_provider.dart` already imports elsewhere in this same codebase), requiring a `// ignore: non_constant_identifier_names` lint suppression for its non-idiomatic name — unnecessary, avoidable duplication.
► ⚔️ **Functionality Conflicts:** **[Notable performance finding]** `GridDouble`/`GridTriple`/`GridSingle` all wrap their content in `Consumer2<GameProvider, AuthProvider>` at the top level — since `GameProvider`'s countdown fires `notifyListeners()` every second, this triggers a full rebuild of up to 100 animated `NumberCell` widgets every second throughout the entire betting phase, with no `Selector`-style narrowed listening. Further confirms the `GoogleFonts.oswald` pattern (page-tab labels).
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

---

#5 (A) : `lib/widgets/panels/left_tab_strip.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `LeftAccordionPanel` — computes `screenWidth, rightPanelWidth, totalLeftAreaWidth, tabsWidth, doubleTripleGridWidth`.
► `_ModeTab`, `_VerticalInfoBox`.

#5 (B): Database & Backend Connections
► No direct calls — reads `game.mode, isDrawerOpen, winForMode, playForMode, triplePage`, dispatches to `GameProvider.openDrawerWithMode`.

#5 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Accordion-style left panel — three fixed 45px tabs, each expandable via `AnimatedContainer` width animation. Independently computes available grid space assuming a 28%-of-screen right panel and a ~158px tabs allowance.
► **Non-Coder Explanation:** The collapsible left-side tab strip — three number-board tabs, each showing live WIN/PLAY totals, sliding open to reveal its grid.

#5 (D): Game Functionality Structure
► **Layout Math.**
► **Tab + Grid Row.**
► **Mode Tab** — WIN/PLAY values, direction arrow, rotated label.
► **Vertical Info Box** — highlight coloring when value > 0.

#5 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None found beyond the layout-constant issues below.
► 🗑️ **Unused / Dead Code:** None found.
► ⚔️ **Functionality Conflicts:**
  - **[Confirms, with hard evidence]** This file's own formula, `(45.0+5.0)*3+8.0`, evaluates to exactly `158.0` — matching `game_screen.dart`'s hardcoded wheel-position offset today, but with zero enforced connection between the two.
  - **[New, higher-consequence]** `rightPanelWidth = screenWidth * 0.28` is independently hardcoded here *and* in `game_screen.dart` — this one directly feeds a live grid-width computation, so any drift would visibly misalign the DOUBLE/TRIPLE grid against the real right panel.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

---

#6 (A) : `lib/widgets/wheel/wheel_widget.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `WheelWidget`/`_WheelWidgetState` — three ring `AnimationController`s (`_redCtrl/_greenCtrl/_blackCtrl`, 2.5s/5.0s/7.0s), `_idleCtrl`, `_nPulseCtrl`.
► Flag state: `_isActivelySpinning, _isPreSpinning, _spinStarted, _showSmoke, _showN, _showFinalResult, _showRedGlow/_showGreenGlow/_showBlackGlow`.
► `LateDecelerateCurve` — custom `Curve` (linear 85%, quadratic-ease-out braking final 15%), mathematically verified continuous at the phase boundary.

#6 (B): Database & Backend Connections
► None directly — listens to `GameProvider` (`isSpinning, isWaitingForResult, pendingResult, globalHistory`) via manually-added `addListener`/`removeListener`.

#6 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Drives three independently-timed ring animations using the custom deceleration curve. Designed around three states — idle, pre-spin (fast blur "waiting for the API"), actively-spinning — reacting to `GameProvider` state transitions.
► **Non-Coder Explanation:** The actual spinning wheel — three colored rings that spin and stop on the server's chosen digits, with a hub that shows smoke while waiting, then reveals the final result.

#6 (D): Game Functionality Structure
► **Ring Animation Setup.**
► **Ring Completion Sound/Glow.**
► **Idle Controller** — declared, not started; wheel is static when not spinning.
► **Initial History Restore** — statically positions rings on mount if history already has entries.
► **Game State Reaction (`_onGameStateChange`)** — see #4A for a major finding.
► **Pre-Spin (`_startPreSpin`)** — see #4A.
► **Target Angle Calculators.**
► **Spin To Result** — captures the current visual angle if transitioning from pre-spin, runs all three rings concurrently via `Future.wait`.
► **Layered Rendering.**
► **Hub States.**

#6 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** **[Major, confirmed via codebase-wide grep]** The entire "pre-spin" animation phase is dead code — `GameProvider.isWaitingForResult` is **never set `true`** anywhere in the entire codebase (declared, exposed via getter, set `false` twice, never `true`). Since `_onGameStateChange`'s branch is `if (game.isSpinning && game.isWaitingForResult && !_isPreSpinning) { _startPreSpin(); } else if (result != null && !_isActivelySpinning) { _spinToResult(result); }`, `_startPreSpin()` can never execute. The entire "fast blur while waiting for the API" phase — its own state flags, dedicated method, sound cue, comments — is unreachable, orphaned from what looks like an earlier architecture where the result wasn't already known when the spin began.
► 🗑️ **Unused / Dead Code:** `_startPreSpin()` and the entire `_isPreSpinining` code path (same finding as #A). Duplicated ~15-line landed-digit-restoration block, copy-pasted verbatim in `initState` and `_onGameStateChange` rather than factored into a shared method.
► ⚔️ **Functionality Conflicts:** `_showFinalResult`'s displayed result string (`'$_landedRed$_landedGreen$_landedBlack'`) has no digit padding, mirroring the identical risk in `spin_result_model.dart`'s `resultString`. Further confirms the `GoogleFonts.oswald` pattern (final-result number).
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable directly — the dead pre-spin path is an internal architecture consistency issue, likely a leftover artifact of a backend-timing model that predates the current `RoundSyncService` design.

---

#7 (A) : `lib/widgets/wheel/wheel_painter.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `WheelPainter extends CustomPainter` — `redAngle, greenAngle, blackAngle, showRedGlow, showGreenGlow, showBlackGlow`.
► Methods: `paint, _drawRing, _drawNumber, _drawSeparators, shouldRepaint`.

#7 (B): Database & Backend Connections
► None — pure canvas-drawing logic.

#7 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Draws three concentric rings of 10 numbered segments, each independently rotated, detecting the "landed" (top) segment via angle-difference geometry and highlighting it blue/white once `hasGlow` is set.
► **Non-Coder Explanation:** The code that actually draws the three spinning rings pixel-by-pixel.

#7 (D): Game Functionality Structure
► **Ring Composition.**
► **Single Ring Rendering** — segment-at-top detection.
► **Number Label Rendering** — see #4B for a dead-code branch.
► **Boundary Separators** — geometrically matched to the hub's radius fraction in `wheel_widget.dart`.
► **Repaint Optimization.**

#7 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None found — rotation/segment-detection geometry is internally consistent and correctly bounded.
► 🗑️ **Unused / Dead Code:** `_drawNumber`'s `isGlow` parameter and its entire associated branch are dead — always called with `isGlow: false` at its one call site (`_drawRing`, explicitly commented "Selected number does not glow").
► ⚔️ **Functionality Conflicts:** This file uses the locally-bundled `'Oswald'` font directly (not `GoogleFonts`), inconsistent with `wheel_widget.dart`'s `GoogleFonts.oswald`-based center-hub text within the same composite widget. (Lower risk than other instances — the weight actually used here, w600, is correctly registered.)
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable. Positive: the black ring's `innerFrac=0.22` is deliberately (and correctly) matched to `wheel_widget.dart`'s hub-size fraction — confirmed consistent between two independently-maintained files.

---

#8 (A) : `lib/widgets/wheel/hub_smoke.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `HubSmokeAnimation`/`_HubSmokeAnimationState` — a self-contained particle "eruption" effect.
► `_Particle`, `_SmokeSystem`, `_SmokePainter`.

#8 (B): Database & Backend Connections
► None — entirely local/visual simulation.

#8 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Custom particle system simulating an eruption of smoke/glow puffs from the wheel hub. A 60s looping `AnimationController` drives a fixed `dt=0.016` simulation step per frame.
► **Non-Coder Explanation:** The puff-of-smoke effect bursting from the wheel's center while spinning.

#8 (D): Game Functionality Structure
► **Ticker Setup** — fresh `_SmokeSystem` per mount.
► **Particle Physics.**
► **Spawning** — rate-limited (max 4/tick), weighted color palette.
► **System Tick.**
► **Rendering** — unconditional repaint every frame (appropriate here).

#8 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** Fixed simulation time-step (`dt=0.016`) doesn't account for actual elapsed frame time — a hardcoded 60fps assumption. On a device under load (plausible here, given four other simultaneous animations during a spin), the simulation could visibly drift relative to real elapsed time.
► 🗑️ **Unused / Dead Code:** None found.
► ⚔️ **Functionality Conflicts:** None found — self-contained, doesn't duplicate state from elsewhere.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

---

#9 (A) : `lib/widgets/wheel/result_lens.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `ResultLens` — `StatelessWidget`; private helper `_slot`.

#9 (B): Database & Backend Connections
► Reads `game.lastResult` via `Consumer`.

#9 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** A small, self-contained widget rendering a vertical "lens" of the three result digits, em-dash placeholder for `null`.
► **Non-Coder Explanation:** A small blue capsule meant to display the three winning digits — but it turns out this piece isn't actually used anywhere.

#9 (D): Game Functionality Structure
► **Result Lens Display.**
► **Digit Slot.**

#9 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** None — the widget's own logic is correct and simple.
► 🗑️ **Unused / Dead Code:** **[Confirmed via codebase-wide search]** `ResultLens` is entirely unused — never referenced anywhere else. This also resolves the open question from `app_colors.dart` #4B: `AppColors.blueLens`/`blueLensDark` are used exclusively by this dead widget, and are therefore also effectively dead.
► ⚔️ **Functionality Conflicts:** None found.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable — the widget is unreachable regardless.

---

#10 (A) : `lib/widgets/overlays/result_overlay.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `ResultOverlay`/`_ResultOverlayState` — `_confetti` (`ConfettiController`).
► Methods: `_buildCard(result)` (untyped parameter — see #4C), `_breakdownText`.

#10 (B): Database & Backend Connections
► Reads `game.lastResult` from `GameProvider`, purely presentational.

#10 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Win-celebration overlay — blurred backdrop, confetti burst (fired once on mount, only if the triggering result was a win), animated result card with total win amount and per-board breakdown.
► **Non-Coder Explanation:** The "You Won!" popup — blurred backdrop, confetti, and a card showing exactly how much was won, broken down by board.

#10 (D): Game Functionality Structure
► **Confetti Setup.**
► **Overlay Composition.**
► **Result Card** — win-title image, win-amount badge, breakdown row.
► **Breakdown Text** — always shown for all three boards, even at 0.

#10 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **[Confirmed, narrower than first stated]** The main win-amount text and breakdown amounts use `FontWeight.w800` for local `'Oswald'`. `pubspec.yaml` registers Oswald only up to weight 700 (Bold) — there's no ExtraBold/Black Oswald asset at all — so this specific text (the win-amount popup, only) still synthesizes bold. This is the one surviving instance of the font-weight-gap family of findings; the broader claim that `AppTextStyles.number/countdown/balance` were also affected was a research error and has been retracted.
  - Confetti's configured 3s duration outlasts the overlay's actual ~2.5s visible lifetime (per `GameProvider.onGlobalResult`'s win-display window) — cut short by ~0.5s.
► 🗑️ **Unused / Dead Code:** None found.
► ⚔️ **Functionality Conflicts:** `_buildCard(result)`'s parameter has no type annotation (implicit `dynamic`) — currently harmless (always passed a valid `SpinResult`), but forgoes compile-time checking. Uses local `'Oswald'` directly (not `GoogleFonts`), consistent with `wheel_painter.dart` but inconsistent with several other widget files.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable.

---

#11 (A) : `lib/widgets/overlays/info_dialog.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `InfoDialog`/`_InfoDialogState` — tabs `['HISTORY', 'PAYOUT', 'RULES']`.
► `_CloseButton, _HistoryTab, _HistoryRow, _HeaderCell, _BodyCell, _EmptyState, _shortenId`.
► `_HistoryDetailDialog, _DetailRow`.
► `_PayoutTab, _SectionTitle, _PayoutCard, _LimitTable, _LimitHeader, _LimitRow`.
► `_RulesTab, _WheelImage, _RuleCard`.

#11 (B): Database & Backend Connections
► No direct calls — triggers `HistoryProvider.loadFirstPage(since: auth.sessionStartAt)` on open.
► Reads live `GameProvider.playLimits` for the limits table.
► Displays `SpinResult` fields from `history.records` or, as a fallback, `game.spinHistory`.

#11 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** A three-tab modal — session history (paginated table + per-round detail popup), payout reference (fixed multiplier cards + a live-updating limits table, explicitly fixed as documented bug "F-15"), and static rules.
► **Non-Coder Explanation:** The in-game "info" popup — HISTORY, PAYOUT, and RULES tabs.

#11 (D): Game Functionality Structure
► **Dialog Entry / Tab Switching.**
► **Session History Table** — login-gated, loading/error/empty states, running session-total footer.
► **History Row** — press-animated, win/loss color-coded.
► **History Detail Dialog** — full round breakdown.
► **Payout Tab** — see #4A for its hardcoded-multiplier finding.
► **Live Limits Table ("F-15" fix)** — reads `GameProvider.playLimits` live, explicitly because hardcoded limit strings once went stale against server changes.
► **Rules Tab.**

#11 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - **[High-value finding, direct parallel to the file's own "F-15" fix]** `_PayoutTab`'s multiplier figures (`'90'`/`'900'`/`'9000'`) are hardcoded `const` values, never sourced from the server — the exact same structural risk `_LimitTable` right next to it was specifically rewritten to avoid. Currently mathematically correct (matches `game_provider.dart`'s ×9/×90/×900), but no live-sync mechanism exists if rates ever change, and there's no evidence of a server endpoint exposing payout multipliers the way one exists for play limits.
  - **[Confirms and extends an earlier finding]** `_HistoryTab`'s `game.spinHistory` fallback is degraded by the confirmed `clearSpinHistory()`-on-dispose bug from `game_screen.dart` — only reliable during a player's very first game-screen visit per session.
► 🗑️ **Unused / Dead Code:** **[Self-acknowledged by the code]** `app_text_styles.dart` is imported but never used — the file carries its own `// ignore: unused_import` suppression rather than removing it.
► ⚔️ **Functionality Conflicts:** By far the heaviest user of `google_fonts` in the app — `GoogleFonts.oswald` *and* `GoogleFonts.dmSans`, alongside raw `fontFamily` literals *and* the (unused) `AppTextStyles` import — all three font-loading approaches coexist in one file. Result-digit display format diverges a third time (`'${record.red} . ${record.green} . ${record.black}'`) from the two other formatting conventions found elsewhere. `_DetailRow`'s formatting branches on exact string-match against `label` — fragile, though correct today.
► 🔗 **Database & Web Dashboard Misalignment:** The F-15 fix stands as this codebase's clearest positive example of correctly closing a client/server drift gap — and, by direct contrast, highlights that the structurally identical payout-multiplier hardcoding sitting right next to it has not received the same treatment.

### `widgets/` — Folder Completion Summary
1. **Architecture & Overview:** Ten files across five subfolders implementing every visual surface of the gameplay screen — loading bar, right control panel, betting grids/cells, left accordion strip, the wheel (widget + painter + smoke + an orphaned result lens), and two overlay dialogs.
2. **Interdependencies:** `left_tab_strip.dart` → `grids.dart` → `grid_cells.dart` is a clean three-layer hierarchy. `wheel_widget.dart` composes `wheel_painter.dart` and `hub_smoke.dart`; `result_lens.dart` is entirely orphaned from this hierarchy and the rest of the app. `game_screen.dart` positions `left_tab_strip.dart`/`right_panel.dart` using two independently hardcoded constants (`158.0`, `0.28`) that `left_tab_strip.dart` recomputes separately.
3. **Bug & Conflict Summary:** The dead pre-spin animation (highest-confidence finding of the whole audit, verified by codebase-wide grep); the conclusively-confirmed three-way cell-color fragmentation; a payout-multiplier hardcoding parallel to the app's own documented, already-fixed limits bug; a real grid-rebuild performance concern; widespread, inconsistent `google_fonts` usage; two independently-duplicated critical layout constants (`158.0` and, more consequentially, `0.28`); `ResultLens` and its two color constants confirmed fully dead; several smaller dead-code/no-op findings.

---

<a name="test"></a>
# 1.8 : `test/`

#1 (A) : `test/widget_test.dart` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► Single test: `'BSG App Smoke Test'`.

#1 (B): Database & Backend Connections
► None directly, but the widget it pumps (`BsgApp`) transitively depends on Supabase being initialized, which this test never does.

#1 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** A single, minimal `testWidgets` smoke test that pumps `BsgApp` directly — bypassing `main()` entirely, including `Supabase.initialize()` — and asserts only that a `MaterialApp` exists somewhere in the tree.
► **Non-Coder Explanation:** The app's only automated test, and it's extremely basic — it just checks the app "boots" far enough to produce a standard Flutter app shell.

#1 (D): Game Functionality Structure
► **Smoke Test** — pumps `BsgApp`, asserts exactly one `MaterialApp` is found.

#1 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:**
  - The test never calls `Supabase.initialize()`, unlike the real entry point. Tracing through the already-audited defensive try/catch blocks in `RoundApiService.getPlayLimits()` and `GameProvider._loadDrawnNumbersHistory()`, both failures are silently swallowed, so the test likely still "passes" without exercising realistic app behavior — a false sense of coverage.
  - The test never advances the fake clock, so `SplashScreen`'s 2400ms delayed navigation never fires — the assertion only ever observes the very first frame.
► 🗑️ **Unused / Dead Code:** Not applicable in the traditional sense, but functionally this test exercises almost none of the actual application logic audited throughout this report.
► ⚔️ **Functionality Conflicts:** None — a single-assertion test can't conflict with anything.
► 🔗 **Database & Web Dashboard Misalignment:** Not applicable directly, though the complete absence of Supabase initialization means this test provides no protection against any of the client/server contract issues identified throughout this audit.

### `test/` — Folder Completion Summary
1. **Architecture & Overview:** A single file containing the unmodified (aside from renaming) default Flutter project template smoke test.
2. **Interdependencies:** Depends on `main.dart`'s `BsgApp`, but bypasses its `main()` function's setup entirely.
3. **Bug & Conflict Summary:** For a real-money gambling application with the volume and severity of logic found throughout this audit — balance/ledger versioning, bet submission idempotency, round-result delivery guarantees, session security, and dozens of documented past production bugs (F-2 through F-15, M-3, M-5, Bug #6/#7/#8, C-3, BUG-03, Q6, S-1) — there is exactly one trivial test, and it doesn't exercise any of that logic.

---

<a name="config"></a>
# 1.9 : Project Configuration

*(Audited after the main `lib:`/`test:` pass, in response to a follow-up question about whether any other files were worth covering. This is also where the Oswald weight-700 correction was discovered and made.)*

#1 (A) : `pubspec.yaml` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `name: best_smart_game`, `version: 2.0.8+43`, SDK constraint `>=3.0.0 <4.0.0`.
► Dependencies: `http, supabase_flutter, provider, shared_preferences, google_fonts, vibration, wakelock_plus, audioplayers, confetti, flutter_animate, shimmer`.
► Dev dependencies: `flutter_test, flutter_lints, flutter_launcher_icons, flutter_native_splash`.

#1 (B): Database & Backend Connections
► Assets registered: `assets/images/`, `assets/sounds/`, `assets/fonts/`.
► Fonts registered: **DMSans** (400/500/600/700/800/900 — all 6 weights), **Oswald** (400/500/600/700 — 4 weights, confirmed by a direct read of the full file after an earlier truncated-grep error).

#1 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** Standard Flutter manifest — dependency versions, font/asset registration, launcher-icon and splash-screen generation config.
► **Non-Coder Explanation:** The app's parts list — every external library it's allowed to use, and every font/image/sound file it can load.

#1 (D): Game Functionality Structure
► **Package Metadata/Versioning.**
► **Runtime Dependencies.**
► **Dev-Only Tooling Dependencies.**
► **Launcher Icon Config.**
► **Native Splash Config.**
► **Asset Folder Registration.**
► **Font Family/Weight Registration.**

#1 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** Oswald weight 800 is not registered (no ExtraBold/Black Oswald asset exists) — `widgets/overlays/result_overlay.dart`'s win-amount/breakdown text still synthesizes bold for that one specific screen. (This is the corrected, narrowed version of a font-weight finding that earlier — incorrectly — also implicated weight 700; weight 700 is confirmed fine.)
► 🗑️ **Unused / Dead Code:**
  - **[Confirmed via grep]** `http`, `vibration`, and `shimmer` are declared but never imported anywhere in `lib/`. Haptic feedback in the actual code goes through Flutter's built-in `HapticFeedback` (not the `vibration` package); no shimmer/skeleton effect appears anywhere in `widgets/`; no direct HTTP calls exist (everything routes through the Supabase client).
  - `assets/fonts/Oswald-Light.ttf` (present on disk, per the earlier `widgets/` folder listing) is unregistered here and never requested at weight 300 anywhere in code.
► ⚔️ **Functionality Conflicts:** None found beyond the items above.
► 🔗 **Database & Web Dashboard Misalignment:** Dependency version currency/vulnerabilities could not be verified — that requires live pub.dev/vulnerability-database access, unavailable for this audit. Flagged as unverified rather than guessed.

---

#2 (A) : `analysis_options.yaml` file audit

#A Functionality & Database/API Map
**Exact Identifiers**
► `include: package:flutter_lints/flutter.yaml`.
► A `linter: rules:` block present but entirely commented out. No `analyzer:` section at all.

#2 (B): Database & Backend Connections
► Not applicable — this file configures static analysis, not runtime behavior.

#2 (C): Technical Overview & Non-Coder Explanation
► **Technical Overview:** The stock, unmodified `flutter create` template — inherits `flutter_lints`' recommended rules with zero project-specific customization.
► **Non-Coder Explanation:** The app's code-quality checklist, left at factory-default settings.

#2 (D): Game Functionality Structure
► **Include the Standard Flutter Lint Rule Set.**
► **(Commented-Out, Unused) Rule Customization Block.**

#2 (E): Deep-Dive Issue & Conflict Audit
► 🐛 **Bugs & Edge Cases:** Not applicable — a config file, no executable logic.
► 🗑️ **Unused / Dead Code:** The commented-out `rules:` examples (`avoid_print`, `prefer_single_quotes`) are inert placeholders, never activated.
► ⚔️ **Functionality Conflicts:** No project-specific rules enabled beyond the `flutter_lints` baseline, despite the codebase showing patterns (inconsistent `const` usage, untyped parameters) that stricter analysis would catch automatically.
► 🔗 **Database & Web Dashboard Misalignment:** This file directly explains two patterns found earlier in the audit:
  - The `// ignore: unused_import` in `info_dialog.dart` shows the default linter **did** catch that unused import — a developer explicitly suppressed the warning rather than removing it.
  - The untyped `_buildCard(result)` parameter in `result_overlay.dart` is **not** caught by the default rule set — flagging implicit `dynamic` requires an `analyzer:` section with `strict-raw-types`/`strict-inference`/`implicit-dynamic: false`, none of which is configured here.

### Project Configuration — Completion Summary
1. **Architecture & Overview:** Two files — the dependency/asset/font manifest and the static-analysis config — governing what the app can use and what the linter checks for.
2. **Interdependencies:** `pubspec.yaml`'s font registration directly determines whether `theme/app_text_styles.dart` and several `widgets/` files render genuine or synthesized bold text. `analysis_options.yaml`'s lack of strict-mode settings directly explains why certain patterns found in `widgets/` (untyped parameters) went uncaught.
3. **Bug & Conflict Summary:** Three unused dependencies; one genuine (narrow) font-weight gap at Oswald 800; one dead font asset (Oswald-Light); an unmodified default lint config that explains, rather than causes, two findings from the main audit; unverifiable dependency-version currency.

---

<a name="consolidated"></a>
# 1.10 : Consolidated Cross-Codebase Findings (severity-ranked)

## 🔴 Highest-severity, concrete
► **#1** Dead pre-spin animation (`wheel_widget.dart`) — `GameProvider.isWaitingForResult` never set `true` anywhere; verified by codebase-wide search.
► **#2** Mid-round exit leaves the bet board uncleared (`game_provider.dart` + `game_screen.dart`, cross-file confirmed).
► **#3** `mapError`'s catch-all still defaults to `BetError.offline` — undermines the app's own documented "honest error reporting" fix.
► **#4** Payout multipliers hardcoded in `info_dialog.dart`, unlike play limits — direct parallel to the app's own documented "F-15" bug, unfixed for this value.
► **#5** Three-way cell-color design-system fragmentation — `app_colors.dart`, `app_decorations.dart`, and the actual live `NumberCell` widget all disagree; the first two are dead code.
► **#6** `GameProvider.clearSpinHistory()` on game-screen exit permanently empties in-app spin history for the rest of the session; confirmed to also degrade `info_dialog.dart`'s history fallback.

## 🟠 Real risks, narrower scope
► **#A** Staff-account login rejection doesn't release the claimed single-device session (`api_service.dart`).
► **#B** `changePassword` may silently rotate the session token without refreshing `AuthProvider`'s cached copy.
► **#C** `applyOptimisticBalance`'s single-slot-claim contract is fragile by design (self-documented).
► **#D** Login-screen shake animation likely non-functional (`TweenAnimationBuilder` misuse).
► **#E** `LoadingBar3D`'s fill animation doesn't loop, contradicting its own doc comment.
► **#F** `LobbyScreen`'s "contact your agent to activate this slot" implies a non-existent per-account entitlement system.
► **#G** Oswald weight 800 is unregistered in `pubspec.yaml` (no ExtraBold/Black asset exists), affecting `result_overlay.dart`'s win-amount text specifically — the narrower, corrected version of the font-weight finding (weight 700 is confirmed fine).

## 🟡 Systemic patterns (individually low-severity, high-frequency)
► **#A** No single source of truth for repeated constants: SharedPreferences drawn-numbers key, play-limit fallback values, the 103-second countdown formula, the `158.0` layout constant, and — most consequentially — the `0.28` right-panel-width fraction (duplicated between `game_screen.dart` and `left_tab_strip.dart`, directly feeding a live width computation).
► **#B** `google_fonts` used inconsistently alongside locally-bundled fonts across at least six widget files, with `info_dialog.dart` as the worst offender (using both Google Fonts variants *and* an unused local-style import simultaneously).
► **#C** Documentation/comment drift, safely distinct from the code itself: `submit_round_bet` vs. actual `place_bet`; `P0007` vs. actual `ErrCode.belowMin = P0123`; a comment referencing a nonexistent method name (`RoundApiService._mapSubmitError` vs. actual public `mapError`).
► **#D** Inconsistent error-handling posture — most services `debugPrint` caught exceptions; `sound_service.dart` and `HistoryProvider._loadSessionTotals` swallow silently with no logging.
► **#E** Three declared dependencies (`http`, `vibration`, `shimmer`) are never imported anywhere in `lib/` (confirmed via grep).
► **#F** `analysis_options.yaml` is the unmodified `flutter_lints` default, with no `analyzer:` strict-mode section.

## 🟢 Confirmed non-issues
Concerns raised early in the audit and **resolved** by later evidence — recorded here so they aren't re-flagged:
► **#A** `ApiService.login()`/`heartbeat()` are fully exception-safe by design.
► **#B** The `_submittedBets`/`_betStatus` dual-tracking is a deliberate, safe design (confirmed via `round_sync_service.dart`).
► **#C** `AuthProvider`'s binary heartbeat-reason check is correctly exhaustive (confirmed via `api_contract.dart`'s `ReasonCode` scoping).
► **#D** The `'bsg_local_game_history'`/`'bsg_drawn_numbers_history'` key mismatch does **not** cause player-to-player history leakage — only `main.dart`'s startup-clear line is dead code; the real session-boundary clearing in `auth_service.dart` is correct.
► **#E** Oswald weight 700 (Bold) **is** correctly registered in `pubspec.yaml` — an earlier pass through this report claimed otherwise, based on a truncated `grep` output. Corrected by a direct read of the full file (Section 9). `AppTextStyles.number()`/`countdown()`/`balance()` are not affected by any font-synthesis issue.

## Test Coverage
`test/widget_test.dart` is the unmodified Flutter template smoke test. None of the findings above would be caught by regression testing today.

---

*Report compiled from a manual, raw-source audit — no `.md`/skill/doc files were used as input for the analysis itself, only for compiling this final report. All findings are traceable to specific files and, where noted, cross-file evidence (including codebase-wide `grep` verification for the highest-confidence findings). One correction is documented transparently rather than silently removed (Oswald weight 700).*
