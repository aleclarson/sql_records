# sql_records Source Code Report

Generated: 2026-03-17

Scope: source code only under `lib/`. Tests, specs, and README content were not reviewed as primary inputs.

Validation performed:
- `dart analyze lib` -> clean
- Manual runtime probes against the current package code for transaction, parsing, and SQL parameter edge cases

## Executive Summary

The repository is small, readable, and structurally coherent. The split between the core abstractions (`core.dart`, `query.dart`, `row.dart`) and the engine adapters is straightforward, and the public API surface is intentionally compact. The code also benefits from conservative identifier validation in the dynamic command builders and an analyzer-clean baseline.

The main risks are not general code quality issues. They are specific semantic mismatches where the API suggests safer or more uniform behavior than the implementation actually guarantees. One of those issues is critical because it can widen `UPDATE` and `DELETE` statements beyond the intended row set.

## Current State

What is working well:
- The core API is easy to follow and small enough to reason about quickly.
- `Query`, `Command`, `InsertCommand`, `UpdateCommand`, and `DeleteCommand` provide a clear mental model for static and dynamic SQL construction.
- Engine adapters stay thin and mostly avoid leaking backend-specific types into the public API.
- The package currently passes `dart analyze lib` without static errors.

Areas where the implementation is uneven:
- Cross-engine behavior is only partially normalized. Transactions, batching, reactive watching, and mutation metadata vary materially by adapter.
- Some helper APIs are more constrained than their documentation implies.
- SQLite/PowerSync parameter handling relies on a regex-based translation layer in several read paths, which creates avoidable correctness risk.

## Critical Issues

### CRITICAL: Composite primary keys are not enforced in dynamic `UPDATE` and `DELETE` commands

Files:
- `lib/src/query.dart:175`
- `lib/src/query.dart:321`

Details:
- `UpdateCommand.apply` only adds `WHERE` predicates for primary-key fields that are present in the provided params map.
- `DeleteCommand.apply` does the same.
- Neither implementation verifies that all declared `primaryKeys` are present and non-null before generating SQL.

Observed current behavior:

```dart
DeleteCommand.static(
  table: 'widgets',
  primaryKeys: ['tenant_id', 'id'],
  params: {'tenant_id': 42},
).apply(null);
// => DELETE FROM widgets WHERE tenant_id = @tenant_id

UpdateCommand.static(
  table: 'widgets',
  primaryKeys: ['tenant_id', 'id'],
  params: {'tenant_id': 42, 'name': 'renamed'},
).apply(null);
// => UPDATE widgets SET name = @name WHERE tenant_id = @tenant_id
```

Impact:
- A caller can accidentally update or delete many rows when they intended to target one row of a composite key.
- This is a data-safety issue, not just an ergonomics issue.

Recommendation:
- Require every declared primary key to be present.
- Require those key values to be non-null.
- Throw immediately if any primary key is missing or null.

## High Concerns

### HIGH: `parseDateTime` is incompatible with the schema contract in normal usage

Files:
- `lib/src/row.dart:62`
- `lib/src/extensions.dart:41`

Details:
- `Row.parse` calls `get<DB>(key)`.
- `Row._validateAccess` requires the schema type for that key to equal `DB` exactly.
- `parseDateTime` calls `parse<DateTime, Object>`, but real schemas will normally declare `int` or `String`, not `Object`.

Observed current behavior:
- With schema `{'ts': int}`, `row.parseDateTime('ts')` throws:
  `Schema Error: Requested <Object> for "ts", but schema declared <int>.`

Impact:
- The advertised convenience API for SQLite datetime parsing fails for the most common schema declarations.

Recommendation:
- Either relax schema validation for parser-based access, or make datetime parsing operate on the declared concrete DB types (`int` and `String`) without requiring `Object` in the schema.

### HIGH: Regex-based SQL parameter translation rewrites tokens inside string literals

Files:
- `lib/src/utils.dart:13`
- `lib/src/sqlite_impl.dart:40`
- `lib/src/powersync_impl.dart:45`
- `lib/src/powersync_impl.dart:108`

Details:
- `translateSql` replaces every `@name` match with `?` using a plain regex.
- It does not skip SQL string literals or comments.

Observed current behavior:
- Querying with SQL like `select '@literal' as lit, @id as id` and params `{'id': 1}` fails with:
  `Parameter Error: Missing parameter "@literal".`

Impact:
- Valid SQL can be corrupted whenever a literal or comment contains an `@...` sequence.
- This affects SQLite read paths and PowerSync read/watch paths.

Recommendation:
- Prefer native named-parameter execution where the backend supports it.
- If translation is still required, replace the regex with a tokenizer/parser that ignores quoted strings and comments.

## Medium Concerns

### MEDIUM: `executeBatch` is not atomic in the SQLite and Postgres adapters

Files:
- `lib/src/sqlite_impl.dart:79`
- `lib/src/postgres_impl.dart:86`

Details:
- Both implementations execute the batch as a simple loop.
- If one statement in the middle fails, earlier mutations remain committed unless the caller already wrapped the call in `writeTransaction`.

Impact:
- The name `executeBatch` implies stronger semantics than the current implementation provides.

Recommendation:
- Either wrap adapter-level batches in a transaction automatically or document clearly that batch execution is only iterative convenience, not atomicity.

### MEDIUM: SQLite `readTransaction` does not actually start a transaction

File:
- `lib/src/sqlite_impl.dart:97`

Details:
- The method returns `action(this)` directly.
- The interface comment says it "opens a read-only transaction," but SQLite currently gets no transaction boundary at all.

Impact:
- The API contract is stronger than the implementation.

Recommendation:
- Either open an actual transaction/snapshot where feasible, or explicitly document that SQLite only provides scoped read access, not a true read transaction.

### MEDIUM: Nested SQLite write transactions fail immediately

File:
- `lib/src/sqlite_impl.dart:105`

Details:
- `writeTransaction` always issues `BEGIN TRANSACTION`.
- A nested call fails with SQLite error `cannot start a transaction within a transaction`.

Impact:
- Library consumers can trip runtime failures if transaction nesting occurs through shared helper code.

Recommendation:
- Add savepoint-based nesting or explicitly reject nested transactions with a clearer library-level error.

### MEDIUM: Cross-engine semantics are only partially aligned

Files:
- `lib/src/core.dart:37`
- `lib/src/postgres_impl.dart:28`
- `lib/src/powersync_impl.dart:24`

Details:
- `MutationResult` is uniform in shape, but PowerSync always returns `null` for both fields.
- `watch` exists on the main interface but is unsupported for SQLite and Postgres.
- `get` failure behavior is not fully consistent across adapters.

Impact:
- The abstraction is useful, but consumers still need backend-specific expectations.

Recommendation:
- Tighten the contract around optional capabilities, or separate portable operations from backend-specific ones more explicitly.

## Low Concerns

### LOW: Postgres row access is linear per column lookup

File:
- `lib/src/postgres_impl.dart:17`

Details:
- `PostgresRow.operator[]` scans the schema columns every time a field is accessed.

Impact:
- Probably acceptable for small result sets, but it adds avoidable per-access overhead.

Recommendation:
- Cache a column-name-to-index map once per row or once per result schema.

### LOW: Parameter resolution behavior is duplicated and slightly inconsistent

Files:
- `lib/src/query.dart:119`
- `lib/src/utils.dart:5`

Details:
- `_resolveParams` throws on invalid input.
- `resolveParams` returns `null` on invalid input.

Impact:
- The duplication is manageable today, but it is easy for behavior to drift.

Recommendation:
- Consolidate parameter resolution into one path with one failure mode.

## Suggestions

Priority order:
1. Fix composite-key enforcement in `UpdateCommand` and `DeleteCommand`.
2. Fix `parseDateTime` / `parseDateTimeOptional` so they work with real schema declarations.
3. Replace or remove regex-based SQL rewriting in favor of safer parameter handling.
4. Clarify or strengthen transaction and batch semantics, especially for SQLite.

Focused code changes worth making next:
- Add a helper that validates declared primary keys before dynamic mutation SQL is built.
- Introduce regression tests for partial composite-key params, datetime parsing, SQL literals containing `@`, batch partial-failure behavior, and nested SQLite transactions.
- Decide whether the library wants strict cross-engine portability or a portable core plus clearly marked engine-specific capabilities, then shape `SqlRecords` around that decision.

## Bottom Line

The repository is in a good state structurally, but it has a small number of important semantic traps. One of them is critical because it can broaden writes or deletes beyond the intended row. If that is fixed first, the next most valuable work is tightening the row parsing and parameter handling so the API behaves as directly as it reads.
