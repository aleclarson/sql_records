# SqliteRecords

A minimal, functional wrapper for SQLite (designed for PowerSync) that prioritizes type safety for parameters, "best-effort" result validation, and a "declare-what-you-use" strategy using Dart 3 Records.

## Features

- **Type-Safe Parameters**: Use Dart Records to define query parameters, ensuring compile-time safety at the call site.
- **Schema-Aware Results**: Define expected result schemas using standard Dart types.
- **SafeRow Access**: Access row data with `read<T>`, `require<T>`, and `parse<T, DB>`, catching schema or type drift immediately.
- **Reactive Queries**: Built-in support for `watch` to receive streams of result sets.
- **Batch Operations**: Efficient `executeBatch` for bulk mutations.
- **Zero Boilerplate**: No code generation required.

## Core Concepts

### 1. Define Queries and Commands
Queries and Commands encapsulate SQL, parameter mapping, and schema tokens.

```dart
// Define the query with typed parameters (P) and a result token (R)
final activeUsersQuery = Query<({String status}), ({String name, int age})>(
  'SELECT name, age FROM users WHERE status = @status',
  schema: {'name': String, 'age': int},
  params: (p) => {'status': p.status},
);
```

### 2. Execute via SqliteRecords
Wrap your `PowerSyncDatabase` and use the typed definitions.

```dart
final db = SqliteRecords.fromPowerSync(powersyncDb);

// Result is a SafeResultSet containing SafeRows
final rows = await db.getAll(activeUsersQuery, (status: 'active'));

for (final row in rows) {
  final name = row.require<String>('name');
  final age = row.read<int>('age');
}
```

### 3. Transactions
Support for both read-only and read-write transactions with dedicated contexts.

```dart
// Read-only transaction
await db.readTransaction((tx) async {
  final user = await tx.get(userQuery, (id: '123'));
  final settings = await tx.getAll(settingsQuery, (userId: '123'));
});

// Read-write transaction
await db.writeTransaction((tx) async {
  await tx.execute(updateUserCommand, (id: '123', name: 'New Name'));
  await tx.execute(logChangeCommand, (userId: '123', action: 'update'));
});
```

### 4. Safe Parsing
Use built-in extensions for common types like Enums and DateTime.

```dart
final status = row.requireEnumByName('status', UserStatus.values);
final createdAt = row.requireDateTime('created_at');
```

## Caveats

- **Named Parameters**: Parameters use `@name` syntax in SQL. The implementation translates these to positional `?` parameters. Ensure every `@name` in the SQL has a corresponding key in the `params` map.
- **Runtime Validation**: While parameters are type-safe at compile-time, result validation (schema and types) happens at runtime during access.
- **Record Tokens**: The `R` record type in `Query<P, R>` is currently a "linting token." It provides context for developers and potential custom linters but does not enable dot-access to fields on the row.

## Recommended Pattern

Organize queries in a private `_Queries` class within your repository files to keep SQL and mapping logic co-located with their usage.
