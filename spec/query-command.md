# Query & Command Specification

## Core types

### `Query<P, R extends Record>`

A read operation definition with:

- `sql: String`
- `params: ParamMapper<P> | Map<String, Object?> | null`
- `schema: ResultSchema` (`Map<String, Type>`)

`R` is a record-shaped type token for developer intent and potential linting/tooling.

### `Command<P>`

A mutation definition with:

- static SQL via `Command(sql, params: ...)`
- or dynamic SQL via subclasses (`UpdateCommand`, `InsertCommand`, `DeleteCommand`)

## Parameter resolution contract

For both queries and commands:

1. If `params == null`, resolved params are `{}`.
2. If `params` is `Map<String, Object?>`, use as-is.
3. If `params` is a mapper function, evaluate mapper with provided runtime params.
4. Other types are invalid and raise `ArgumentError`.

## Static factories

- `Query.static(sql, schema: ...)` is equivalent to a parameterless query (`P = void`).
- `Command.static(sql)` is equivalent to a parameterless command (`P = void`).

## RETURNING contract

`Command.returning<R>(schema, {columns})` produces a query wrapper that:

1. Runs the underlying command SQL generation.
2. If command SQL is `NoOpCommand`, preserves no-op behavior.
3. Otherwise appends `RETURNING ...` with:
   - `columns` argument if provided, else
   - `schema.keys` in key iteration order.

## Dynamic mutation helpers

### `UpdateCommand<P>`

Inputs:

- `table`
- `primaryKeys`
- `params`

Generation rules:

- Primary key fields always contribute `WHERE key = @key` and are bound.
- Non-primary key values:
  - `SQL(_)` => emit `key = NULL` (literal), not a bound arg.
  - `null` => omitted (patch semantics).
  - non-null => emit `key = @key` and bind.
- If no updatable fields remain, emit `NoOpCommand`.
- If no `WHERE` terms exist, throw `ArgumentError`.

### `InsertCommand<P>`

Inputs:

- `table`
- `params`

Generation rules:

- For each field:
  - `SQL(_)` => include column with literal `NULL`.
  - `null` => omit field.
  - non-null => include `@key` bind.
- If no columns remain, emit `INSERT INTO <table> DEFAULT VALUES`.

### `DeleteCommand<P>`

Inputs:

- `table`
- `primaryKeys`
- `params`

Generation rules:

- Include only primary-key entries in `WHERE` with bound parameters.
- If no `WHERE` terms exist, throw `ArgumentError`.

## Sentinel no-op behavior

`NoOpCommand = 'NOOP'` is a sentinel SQL value used internally.

Executors must skip database execution and return `NoOpMutationResult` when this sentinel appears.
