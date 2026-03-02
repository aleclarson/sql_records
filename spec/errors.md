# Error Semantics Specification

This package intentionally throws early for misuse and drift.

## Argument errors (caller contract violations)

Dynamic commands validate identifiers and throw on invalid values. For manually authored SQL strings, interpolation safety is caller responsibility.

Examples:

- Accessing a row key not declared in schema.
- Accessing with generic type not matching declared schema type.
- Invalid `params` shape (not map/function/null).
- Missing bound placeholder during SQL translation.
- Dynamic commands with missing primary-key configuration.

## State errors (runtime data contract violations)

Examples:

- `Row.get<T>` called when DB value is null.
- DB returns runtime type incompatible with declared schema type.
- Invoking dynamic-only/static-only paths incorrectly (e.g., static SQL missing on base `Command`).

## Unsupported errors (engine capability mismatch)

Examples:

- `watch()` on SQLite/Postgres.
- PowerSync watch/read transaction attempted from non-main contexts where adapter cannot support it.

## No-op command semantics

No-op updates are not errors.

They are represented by `NoOpCommand`, skipped during execution, and reported as `NoOpMutationResult`.
