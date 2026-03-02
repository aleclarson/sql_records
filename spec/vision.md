# sql_records Vision

Status: Drafted from current repository behavior (`README.md`, `CHANGELOG.md`, `lib/`, `test/`) at version `0.5.0`.

## Mission

`sql_records` provides a minimal SQL abstraction for Dart that keeps SQL visible while improving safety at query boundaries.

The package optimizes for:

1. **Type-safe inputs** via Dart records and explicit parameter mappers.
2. **Best-effort runtime output safety** via explicit result schemas and checked row accessors.
3. **Low ceremony** (no codegen, no ORM identity map, no hidden query builder).
4. **Cross-engine consistency** across SQLite (`sqlite3`), PowerSync, and PostgreSQL.

## Architectural stance

- SQL text is authored by the user and remains central.
- The library does not attempt to model relational structure in Dart types beyond parameter and row boundary validation.
- Dynamic command helpers (`UpdateCommand`, `InsertCommand`, `DeleteCommand`) exist to reduce repetitive mutation boilerplate while preserving SQL clarity.
- Engine-specific behavior is surfaced explicitly where parity is not possible (e.g., `watch`).

## Success criteria

A successful `sql_records` workflow should allow developers to:

- Declare queries/commands once and reuse them safely.
- Catch common schema drift quickly (`Row.get<T>`, `Row.getOptional<T>` checks).
- Perform partial updates/inserts without handwritten SQL branching.
- Use `RETURNING` in a uniform way through `command.returning(schema)`.
- Switch or support multiple engines with minimal application-layer churn.

## Non-goals

- Full ORM behavior (relationships, lazy loading, identity map).
- Compile-time validation of SQL column names against DB schema.
- Compile-time enforcement of `R` record field access from row instances.
- Query planning, migrations, or schema management.

## Spec map

- [Domain model and DSL](./query-command.md)
- [Row and schema contract](./row-and-schema.md)
- [Engine behavior matrix](./engines.md)
- [Transactions and reactivity](./transactions-and-watch.md)
- [Error semantics](./errors.md)
- [Open questions](./open-questions.md)
