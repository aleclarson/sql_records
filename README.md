# SqlRecords

A minimal, functional wrapper for SQLite (PowerSync or `sqlite3`) and PostgreSQL that prioritizes type safety for parameters, "best-effort" result validation, and a "declare-what-you-use" strategy using Dart 3 Records.

## Features

- **Multi-Engine Support**: Separate adapters for SQLite (via PowerSync or `sqlite3`) and PostgreSQL.
- **Type-Safe Parameters**: Use Dart Records to define query parameters, ensuring compile-time safety.
- **Map Literal Parameters**: Support for `Map<String, Object?>` for quick, one-off inline queries.
- **Dynamic Patching**: Specialized commands for partial updates and inserts without boilerplate SQL.
- **Schema-Aware Results**: Define expected result schemas using standard Dart types.
- **Row Access**: Access row data with `get<T>`, `getOptional<T>`, and `parse<T, DB>`, catching schema or type drift immediately.
- **Reactive Queries**: Built-in support for `watch` to receive streams of result sets (PowerSync only).
- **Zero Boilerplate**: No code generation required.

## Core Concepts

### 1. Initialization

Import the adapter for your database and wrap your connection.

#### For SQLite / PowerSync
```dart
import 'package:sql_records/powersync.dart';

final db = SqlRecordsPowerSync(powersyncDb);
```

#### For SQLite (`sqlite3` package)
```dart
import 'package:sql_records/sqlite.dart';

final db = SqlRecordsSqlite(sqlite3Database);
```

#### For PostgreSQL
```dart
import 'package:sql_records/postgres.dart';

final db = SqlRecordsPostgres(postgresSession);
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

final activeUsers = await db.getAll(activeUsersQuery, (status: 'active'));

// Parameterless queries
final allUsersQuery = Query.static<({String name, int age})>(
  'SELECT name, age FROM users',
  schema: {'name': String, 'age': int},
);

final allUsers = await db.getAll(allUsersQuery);

// Inline query with map literal params
final row = await db.get(Query(
  'SELECT * FROM users WHERE id = @id',
  params: {'id': '123'},
  schema: {'id': String, 'name': String},
));
```

#### Dynamic Commands (PATCH / INSERT / DELETE)
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

// DeleteCommand dynamically builds a WHERE clause by primary key.
final deleteUser = DeleteCommand<({String id})>(
  table: 'users',
  primaryKeys: ['id'],
  params: (p) => {'id': p.id},
);

await db.execute(deleteUser, (id: '123'));
```

#### RETURNING Clauses
Convert any command into a query to retrieve generated IDs or updated values.

```dart
final insertAndReturn = insertUser.returning<({int id, String name})>({
  'id': int,
  'name': String,
});

final row = await db.get(insertAndReturn, (id: '123', name: 'New User'));
print('Generated ID: ${row.get<int>('id')}');
```

#### The `SQL` Wrapper
Use `SQL.NULL` to distinguish between "omit this field" (plain `null`) and "explicitly set to NULL".

```dart
// Explicitly set 'age' to NULL while skipping 'name' update
await db.execute(patchUser, (id: '123', name: null, age: SQL.NULL));

// Static commands for parameterless SQL
final deleteAll = Command.static('DELETE FROM users');
await db.execute(deleteAll);
```

#### Map Literal Parameters
For simple or one-off queries where Record-based type safety isn't required, you can use map literals directly.

```dart
// Inline Query
final row = await db.get(Query(
  'SELECT name FROM users WHERE id = @id',
  params: {'id': '123'},
  schema: {'name': String},
));

// Inline Command
await db.execute(Command(
  'UPDATE users SET status = @status WHERE id = @id',
  params: {'id': '123', 'status': 'active'},
));

// Inline RETURNING Query
final row = await db.get(Command(
  'UPDATE users SET status = @status WHERE id = @id',
  params: {'id': '123', 'status': 'active'},
).returning<({String status})>({'status': String}));
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

- **Named Parameters**: Parameters use `@name` syntax in SQL. For SQLite, they are translated to positional `?` parameters. For Postgres, they use the native `Sql.named` support.
- **Identifier Safety Boundary**: Dynamic commands (`UpdateCommand`, `InsertCommand`, `DeleteCommand`) quote/escape table and column identifiers. Manually authored SQL in `Query`/`Command` is your SQL; avoid unsafe string interpolation.
- **Runtime Validation**: While parameters are checked at compile-time, result validation (schema/types) happens at runtime.
- **Record Tokens**: The `R` record type in `Query<P, R>` is a "linting token" for developer guidance; dot-access on rows (e.g. `row.name`) is not yet supported.

## Patterns

### 1. Hoisted Definitions (Recommended for Reuse)

Organize queries in a private `_Queries` class within your repository files.

```dart
class UserRepository {
  final SqlRecords _db;
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

### 2. Inline Definitions (Great for Simple Queries)

For simple or one-off queries, define them directly at the call site using map literals for parameters.

```dart
final row = await db.get(Query(
  'SELECT name FROM users WHERE id = @id',
  params: {'id': '123'},
  schema: {'name': String},
));
```
