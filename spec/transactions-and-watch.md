# Transactions & Reactivity Specification

## Transactions

## `writeTransaction`

- Accepts callback with `SqlRecords` context.
- Executes callback inside engine transaction boundary where supported.

Behavior by engine:

- SQLite: manual `BEGIN TRANSACTION` / `COMMIT` / `ROLLBACK`.
- PowerSync: delegated to `writeTransaction` on context.
- PostgreSQL: delegated via `SessionExecutor.runTx`.

## `readTransaction`

- Accepts callback with `SqlRecordsReadonly` context.

Behavior by engine:

- PowerSync: true read transaction when started from main connection.
- PostgreSQL: transaction via `runTx`, read context enforced by type.
- SQLite: no distinct read-only mode; callback executes with current context.

## watch

`watch` returns a `Stream<RowSet<R>>`.

Behavior:

- PowerSync: wraps underlying watch stream and maps rows into typed `Row` wrappers.
- If called from non-main PowerSync context, throws `UnsupportedError`.
- SQLite/Postgres: always throw `UnsupportedError`.

Default reactivity controls:

- `throttle`: `30ms`
- `triggerOnTables`: optional table set for PowerSync invalidation hints.
