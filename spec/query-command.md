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
3. Otherwise appends `RETURNING ...` with quoted/escaped identifiers using:
   - `columns` argument if provided, else
   - `schema.keys` in key iteration order.

## Dynamic mutation helpers

### `UpdateCommand<P>`

Inputs:

- `table`
- `primaryKeys`
- `params`

Generation rules:

- Table and column identifiers are always quoted/escaped as SQL identifiers.
- Primary key fields always contribute `WHERE <quotedKey> = @<generatedParam>` and are bound.
- Non-primary key values:
  - `SQL.NULL` => emit `<quotedKey> = NULL` (literal), not a bound arg.
  - `null` => omitted (patch semantics).
  - non-null => emit `<quotedKey> = @<generatedParam>` and bind.
- Generated parameter names are internal (`p0`, `p1`, ...), independent of source key names.
- If no updatable fields remain, emit `NoOpCommand`.
- If no `WHERE` terms exist, throw `ArgumentError`.

### `InsertCommand<P>`

Inputs:

- `table`
- `params`

Generation rules:

- Table and column identifiers are always quoted/escaped as SQL identifiers.
- For each field:
  - `SQL.NULL` => include quoted column with literal `NULL`.
  - `null` => omit field.
  - non-null => include generated bind name (`@pN`).
- If no columns remain, emit `INSERT INTO <quotedTable> DEFAULT VALUES`.

### `DeleteCommand<P>`

Inputs:

- `table`
- `primaryKeys`
- `params`

Generation rules:

- Table and column identifiers are always quoted/escaped as SQL identifiers.
- Include only primary-key entries in `WHERE` with generated bound parameters.
- If no `WHERE` terms exist, throw `ArgumentError`.

## Identifier safety

Dynamic commands (`UpdateCommand`, `InsertCommand`, `DeleteCommand`) quote/escape table and column identifiers.

- This protects dynamic-command identifier inputs from SQL injection via identifier text.
- Manual SQL authored via `Query` / `Command` remains caller-authored SQL; any manual string interpolation is the caller's responsibility.

## Sentinel no-op behavior

`NoOpCommand = 'NOOP'` is a sentinel SQL value used internally.

Executors must skip database execution and return `NoOpMutationResult` when this sentinel appears.
