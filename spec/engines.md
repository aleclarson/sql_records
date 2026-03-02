# Engine Behavior Specification

This document defines behavior by adapter.

## Supported adapters

- `SqlRecordsPowerSync(PowerSyncDatabase)`
- `SqlRecordsSqlite(sqlite3.Database)`
- `SqlRecordsPostgres(postgres.Session)`

All adapters implement shared interfaces:

- `SqlRecordsReadonly`
- `SqlRecords`

## Result field naming (PostgreSQL)

PostgreSQL row lookup is by exact column name as returned by the driver.

- Casing is not normalized.
- Use SQL aliases when exact access keys are required.

## Parameter transport semantics

### SQLite / PowerSync

- Author SQL with named `@param` placeholders.
- Runtime translates to positional `?` SQL with args list in encounter order.
- Missing placeholder bindings raise `ArgumentError`.

### PostgreSQL

- Uses `postgres` named execution (`Sql.named(sql)`) with parameter map.
- No translation to positional placeholders.

## Mutation result semantics

### SQLite

- `affectedRows`: populated from `updatedRows`.
- `lastInsertId`: populated from `lastInsertRowId`.

### PowerSync

- `affectedRows`: `null` (not exposed by current result type).
- `lastInsertId`: `null`.

### PostgreSQL

- `affectedRows`: populated from driver result.
- `lastInsertId`: `null` (use `RETURNING` pattern).

### No-op commands

For all adapters:

- If command resolves to `NoOpCommand`, skip execution and return `NoOpMutationResult` (`affectedRows = 0`, `lastInsertId = null`).

## Batch semantics

- SQLite/Postgres: execute per item sequentially.
- PowerSync: groups statements by generated SQL text and uses `executeBatch` per SQL group.

## Watch support

- PowerSync: supported on main `PowerSyncDatabase` context.
- SQLite/Postgres: unsupported and must throw `UnsupportedError`.
