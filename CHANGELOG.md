## 0.6.0

- **BREAKING**: Replaced `SQL(value)` with constant `SQL.NULL`.
- **BREAKING**: Dynamic commands now validate identifiers and throw `ArgumentError` when names do not match `[A-Za-z_][A-Za-z0-9_]*`.
- `Command.returning(...)` now validates RETURNING identifiers with the same rule.
- Clarified docs/specs/tests around identifier safety boundaries: dynamic command identifier handling is guarded; manual SQL string interpolation remains caller responsibility.

## 0.5.0

- **BREAKING**: Renamed `SafeRow` to `Row` and `SafeResultSet` to `RowSet`.
- **BREAKING**: Removed `RowData` internal interface; dialects now extend `Row` directly.
- Added support for `RETURNING` clauses in `InsertCommand`, `UpdateCommand`, and `DeleteCommand`.
- Added `command.returning(schema)` method to `Command`, converting a mutation into a `Query` (columns are automatically inferred from the schema).
- Added `DeleteCommand` for dynamic deletes by primary key.
- Improved `UpdateCommand` to return `NoOpCommand` when no fields are provided, skipping DB execution.
- `InsertCommand` now uses `INSERT INTO table DEFAULT VALUES` when all provided columns are null.
- Updated `UpdateCommand` and `InsertCommand` to hard-code `NULL` when using the `SQL` wrapper to improve SQL readability and minimize parameter bindings.

## 0.4.0

- Renamed package to `sql_records`.
- Fixed PostgreSQL transaction implementation to correctly use `runTx`.
- Renamed PowerSync internal classes to avoid confusion with generic SQLite implementations.
- Removed deprecated `SqliteRecords` and `SqliteRecordsReadonly` type aliases.
- Cleaned up unused imports and internal fields across the package.
- Improved type safety for PostgreSQL session execution by using `SessionExecutor`.
- Added support for PostgreSQL via the `postgres` package.
- Added support for synchronous SQLite via the `sqlite3` package.
- Restructured package with engine-specific entry points:
  - `package:sql_records/powersync.dart`
  - `package:sql_records/sqlite.dart`
  - `package:sql_records/postgres.dart`
- Generalized `SqliteRecords` to `SqlRecords` to support multiple database engines.
- `SqliteRecords` and `SqliteRecordsReadonly` are now type aliases for backward compatibility.
- Introduced `MutationResult` to provide a unified result for `execute` across engines.
- Internal refactoring of `SafeRow` and `SafeResultSet` to be database-agnostic.
- Improved internal structure to avoid leaking private helpers into the public API.

## 0.3.1

- Updated `parseDateTime` to support both ISO-8601 strings and epoch integers.
- Added documentation for the "Inline Definition" pattern in the README.

## 0.3.0

- Added support for map literal parameters in `Query` and `Command` to simplify inline definitions.
- Renamed `.empty` factory to `.static` in `Query` and `Command` to better describe static SQL usage.
- Refined README and documentation with more examples for patching and dynamic commands.

## 0.2.0

- Added `UpdateCommand` for dynamic "patch" updates that skip null parameters.
- Added `InsertCommand` for dynamic inserts that only include non-null parameters.
- Added `SQL` wrapper to distinguish between skipping a field and explicitly setting it to `NULL`.
- Optimized `executeBatch` to support dynamic SQL generation.
- Improved documentation with `llms.txt` and more comprehensive README examples.
- Refactored `Query` constructor to ensure consistency (schema now follows params).

## 0.1.0

- Initial release.
- Type-safe parameters using Dart 3 records.
- Schema-aware results with `SafeRow` and `SafeResultSet`.
- Reactive query support with `watch`.
- Read-only and read-write transaction support.
- Convenient parsing for enums and DateTime.
