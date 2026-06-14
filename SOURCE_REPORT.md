# sql_records Source Code Report

Updated: 2026-06-14

Scope: source code only under `lib/`. Tests and specs were used only to verify behavior after changes.

Validation performed:
- `dart analyze`
- Targeted regression tests for row parsing and SQLite parameter binding edge cases

## Executive Summary

The repository remains small, readable, and structurally coherent. The public API is compact, the split between core abstractions and backend adapters is easy to follow, and the analyzer stays clean.

The highest-risk remaining problem is still dynamic mutation safety for composite primary keys. Outside of that, the main gaps are transactional semantics and a few places where the cross-engine abstraction is looser than the interface suggests.

## Current State

What is working well:
- The core API is small enough to reason about quickly.
- `Query`, `Command`, `InsertCommand`, `UpdateCommand`, and `DeleteCommand` form a clear model for static and dynamic SQL.
- Backend adapters are thin and mostly keep engine-specific types out of the public surface.

Current rough edges:
- Transaction and batching semantics still vary materially by adapter.
- Some capability differences are still exposed through a single shared interface.
- The most serious open risk remains accidental widening of dynamic `UPDATE` and `DELETE` statements.

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

## Medium Concerns

### MEDIUM: `executeBatch` is not atomic in the SQLite and Postgres adapters

Files:
- `lib/src/sqlite_impl.dart:79`
- `lib/src/postgres_impl.dart:94`

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
- Either open an actual transaction or snapshot where feasible, or explicitly document that SQLite only provides scoped read access, not a true read transaction.

### MEDIUM: Nested SQLite write transactions fail immediately

File:
- `lib/src/sqlite_impl.dart:105`

Details:
- `writeTransaction` always issues `BEGIN TRANSACTION`.
- A nested call fails with SQLite error `cannot start a transaction within a transaction`.

Impact:
- Library consumers can trip runtime failures if transaction nesting happens through shared helper code.

Recommendation:
- Add savepoint-based nesting or reject nested transactions with a clearer library-level error.

### MEDIUM: Cross-engine semantics are only partially aligned

Files:
- `lib/src/core.dart:30`
- `lib/src/postgres_impl.dart:35`
- `lib/src/powersync_impl.dart:24`

Details:
- `MutationResult` is uniform in shape, but PowerSync still returns `null` for both fields.
- `watch` exists on the main interface but is unsupported for SQLite and Postgres.
- Transaction behavior still differs substantially by adapter.

Impact:
- The abstraction is useful, but consumers still need backend-specific expectations.

Recommendation:
- Tighten the portable contract around optional capabilities, or split engine-specific features from the core interface more explicitly.

## Suggestions

Priority order:
1. Fix composite-key enforcement in `UpdateCommand` and `DeleteCommand`.
2. Clarify or strengthen batch semantics, especially for SQLite and Postgres.
3. Decide whether SQLite transactions should stay lightweight or grow real read/nested transaction behavior.
4. Tighten the contract around backend-specific capabilities.

Focused next changes:
- Add regression coverage for partial composite-key params.
- Decide whether `executeBatch` should be transactional by contract or only by caller convention.
- If nested SQLite transactions are meant to work, implement them with savepoints.

## Bottom Line

The package is in better shape than the original report snapshot, and the remaining issues are more concentrated. The one issue that still stands out as critical is partial composite-key handling in dynamic mutations. After that, the biggest decision is whether transaction semantics should be made stronger or documented more narrowly.
