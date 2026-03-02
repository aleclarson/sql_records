# Row & Schema Specification

## Purpose

`Row<R>` provides guarded access to raw database row data using the declared query schema.

## Schema contract

Every row carries the `ResultSchema` from its source query.

When reading by key:

1. The key **must exist** in schema, otherwise `ArgumentError`.
2. The requested generic type **must exactly match** schema type for the key, otherwise `ArgumentError`.

This is a deliberate strictness model to detect drift and caller mistakes early.

## Accessors

### `get<T>(key)`

- Validates schema key and declared type.
- Throws `StateError` if database value is `null`.
- Throws `StateError` if runtime value is not `T`.
- Returns `T`.

### `getOptional<T>(key)`

- Validates schema key and declared type.
- Allows `null` database values.
- Throws `StateError` if non-null runtime value is not `T`.
- Returns `T?`.

### `parse<T, DB>(key, parser)`

- Reads via `get<DB>(key)` and applies parser.

### `parseOptional<T, DB>(key, parser)`

- Reads via `getOptional<DB>(key)` and applies parser if non-null.

## `RowSet<R>`

`RowSet<R>` is an iterable wrapper over `Iterable<Row<R>>` with passthrough iteration and length.

## Convenience parsing extensions

`RowConvenience` defines helpers:

- `parseEnumByName` / `parseEnumByNameOptional`
- `parseDateTime` / `parseDateTimeOptional`

DateTime parser accepts:

- epoch milliseconds (`int`)
- ISO-8601 string (`String`)

Other runtime types are invalid and raise `ArgumentError`.
