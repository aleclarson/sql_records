## 0.4.0

- Added support for PostgreSQL via the `postgres` package.
- Generalized `SqliteRecords` to `SqlRecords` to support multiple database engines.
- `SqliteRecords` and `SqliteRecordsReadonly` are now type aliases for backward compatibility.
- Introduced `MutationResult` to provide a unified result for `execute` across engines.
- Internal refactoring of `SafeRow` and `SafeResultSet` to be database-agnostic.

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
