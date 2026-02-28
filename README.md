# SqliteRecords

A minimal, functional wrapper for SQLite (designed for PowerSync) that prioritizes type safety for parameters, "best-effort" result validation, and a "declare-what-you-use" strategy using Dart 3 Records.

## Features

- **Type-Safe Parameters**: Use Dart Records to define query parameters, ensuring compile-time safety.
- **Dynamic Patching**: Specialized commands for partial updates and inserts without boilerplate SQL.
- **Schema-Aware Results**: Define expected result schemas using standard Dart types.
- **SafeRow Access**: Access row data with `get<T>`, `getOptional<T>`, and `parse<T, DB>`, catching schema or type drift immediately.
- **Reactive Queries**: Built-in support for `watch` to receive streams of result sets.
- **Zero Boilerplate**: No code generation required.

## Core Concepts

### 1. Initialization

Wrap your `PowerSyncDatabase` to start using the library.

```dart
final db = SqliteRecords.fromPowerSync(powersyncDb);
```

### 2. Queries and Commands

Queries (READ) and Commands (WRITE) encapsulate SQL, parameter mapping, and schema tokens.

#### Standard Queries (READ)
```dart
final activeUsersQuery = Query<({String status}), ({String name, int age})>(
  'SELECT name, age FROM users WHERE status = @status',
  params: (p) => {'status': p.status},
  schema: {'name': String, 'age': int},
);

// Execute and access results
final rows = await db.getAll(activeUsersQuery, (status: 'active'));
for (final row in rows) {
  final name = row.get<String>('name');
}
```

#### Dynamic Commands (PATCH / INSERT)
Specialized commands generate SQL dynamically based on provided parameters.

```dart
// UpdateCommand dynamically builds the SET clause, skipping null values.
final patchUser = UpdateCommand<({String id, String? name, int? age})>(
  table: 'users',
  primaryKeys: ['id'],
  params: (p) => {'id': p.id, 'name': p.name, 'age': p.age},
);

// Only 'name' is updated in the database
await db.execute(patchUser, (id: '123', name: 'New Name', age: null));

// InsertCommand dynamically builds COLUMNS/VALUES, allowing for DB defaults.
final insertUser = InsertCommand<({String id, String? name})>(
  table: 'users',
  params: (p) => {'id': p.id, 'name': p.name},
);

await db.execute(insertUser, (id: '456', name: 'Alice'));
```

#### The `SQL` Wrapper
Use `SQL(value)` to distinguish between "omit this field" (plain `null`) and "explicitly set to NULL" (`SQL(null)`).

```dart
// Explicitly set 'age' to NULL while skipping 'name' update
await db.execute(patchUser, (id: '123', name: null, age: const SQL(null)));
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
  await tx.execute(patchUser, (id: '123', name: 'Updated'));
});
```

### 4. Safe Parsing

Use built-in extensions for common types like Enums and DateTime.

```dart
final status = row.parseEnumByName('status', UserStatus.values);
final createdAt = row.parseDateTime('created_at');
```

## Caveats

- **Named Parameters**: Parameters use `@name` syntax in SQL, which are translated to positional `?` parameters.
- **Runtime Validation**: While parameters are checked at compile-time, result validation (schema/types) happens at runtime.
- **Record Tokens**: The `R` record type in `Query<P, R>` is a "linting token" for developer guidance; dot-access on rows (e.g. `row.name`) is not yet supported.

## Recommended Pattern

Organize queries in a private `_Queries` class within your repository files to keep SQL and mapping logic co-located with their usage.

```dart
class UserRepository {
  final SqliteRecords _db;
  UserRepository(this._db);

  Future<void> patch(String id, {String? name}) {
    return _db.execute(_Queries.patchUser, (id: id, name: name));
  }
}

abstract class _Queries {
  static final patchUser = UpdateCommand<({String id, String? name})>(
    table: 'users',
    primaryKeys: ['id'],
    params: (p) => {'id': p.id, 'name': p.name},
  );
}
```
