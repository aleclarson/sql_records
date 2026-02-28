/// Maps a Record/Class to a SQLite named parameter map.
typedef ParamMapper<P> = Map<String, Object?> Function(P params);

/// Wrapper for a value to be used in a SQL statement.
///
/// Primarily used with [UpdateCommand] or [InsertCommand] to distinguish between
/// "omit this field" (plain `null`) and "set this field to NULL" (`SQL(null)`).
class SQL {
  final Object? value;
  const SQL(this.value);

  @override
  String toString() => 'SQL($value)';
}

/// Best-effort schema definition using Dart's Type objects (e.g., int, String).
typedef ResultSchema = Map<String, Type>;

/// [P] defines the input Parameter type.
/// [R] defines the expected output Record type (serves as a token for custom linting).
class Query<P, R extends Record> {
  final String sql;
  final ResultSchema schema;
  final dynamic params;

  const Query(
    this.sql, {
    this.params,
    required this.schema,
  });

  /// Factory for static queries.
  static Query<void, R> static<R extends Record>(
    String sql, {
    required ResultSchema schema,
  }) {
    return Query<void, R>(sql, schema: schema);
  }

  /// Returns the SQL string and the mapped parameters for this command.
  (String, Map<String, Object?>) apply(P? p) {
    final map = _resolveParams<P>(params, p);
    return (sql, map);
  }
}

/// A command that mutates data (INSERT, UPDATE, DELETE).
class Command<P> {
  final String? _sql;
  final dynamic params;

  const Command(String sql, {this.params}) : _sql = sql;

  /// Internal constructor for subclasses that generate SQL dynamically.
  const Command._dynamic({this.params}) : _sql = null;

  /// Returns the SQL string for this command.
  /// Subclasses can override this to generate SQL based on the parameters [p].
  String getSql(P? p) => apply(p).$1;

  /// Returns the SQL string and the mapped parameters for this command.
  (String, Map<String, Object?>) apply(P? p) {
    if (_sql == null) {
      throw StateError('Command does not have a static SQL string.');
    }
    final map = _resolveParams<P>(params, p);
    return (_sql!, map);
  }

  /// Factory for static mutations.
  static Command<void> static(String sql) => Command<void>(sql);
}

Map<String, Object?> _resolveParams<P>(dynamic params, P? p) {
  if (params == null) return const {};
  if (params is Map<String, Object?>) return params;
  if (params is Function) return (params as ParamMapper<P>)(p as P);
  throw ArgumentError('params must be a Map<String, Object?> or a ParamMapper');
}

/// Sentinel value for a command that does nothing (e.g., no fields to update).
const String NoOpCommand = 'NOOP';

/// A specialized [Command] for "patch" updates.
///
/// It dynamically generates an UPDATE statement based on the non-null values
/// provided in the [params] record. Keys specified in [primaryKeys] are used
/// in the WHERE clause and are expected to be non-null.
class UpdateCommand<P> extends Command<P> {
  final String table;
  final List<String> primaryKeys;
  final List<String>? returning;

  const UpdateCommand({
    required this.table,
    required this.primaryKeys,
    required dynamic params,
    this.returning,
  }) : super._dynamic(params: params);

  @override
  (String, Map<String, Object?>) apply(P? p) {
    final rawMap = _resolveParams<P>(params, p);
    final finalMap = <String, Object?>{};
    final updates = <String>[];
    final where = <String>[];

    for (final key in rawMap.keys) {
      final value = rawMap[key];

      if (primaryKeys.contains(key)) {
        where.add('$key = @$key');
        finalMap[key] = value;
        continue;
      }

      if (value is SQL) {
        updates.add('$key = NULL');
        continue;
      }

      // Skip plain nulls for patching
      if (value != null) {
        updates.add('$key = @$key');
        finalMap[key] = value;
      }
    }

    if (updates.isEmpty) {
      // Return a no-op SQL if no fields were provided for update.
      return (NoOpCommand, const {});
    }

    if (where.isEmpty) {
      throw ArgumentError('UpdateCommand requires at least one primary key.');
    }

    final sqlBase =
        'UPDATE $table SET ${updates.join(', ')} WHERE ${where.join(' AND ')}';
    final sql = returning != null && returning!.isNotEmpty
        ? '$sqlBase RETURNING ${returning!.join(', ')}'
        : sqlBase;
    return (sql, finalMap);
  }
}

/// A specialized [Command] for dynamic inserts.
///
/// It dynamically generates an INSERT statement using only the non-null values
/// provided in the [params] record, allowing the database to apply default values
/// for omitted columns.
class InsertCommand<P> extends Command<P> {
  final String table;
  final List<String>? returning;

  const InsertCommand({
    required this.table,
    required dynamic params,
    this.returning,
  }) : super._dynamic(params: params);

  @override
  (String, Map<String, Object?>) apply(P? p) {
    final rawMap = _resolveParams<P>(params, p);
    final finalMap = <String, Object?>{};
    final cols = <String>[];
    final vals = <String>[];

    for (final entry in rawMap.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is SQL) {
        cols.add(key);
        vals.add('NULL');
        continue;
      }

      // Skip plain nulls
      if (value != null) {
        cols.add(key);
        vals.add('@$key');
        finalMap[key] = value;
      }
    }

    if (cols.isEmpty) {
      final sqlBase = 'INSERT INTO $table DEFAULT VALUES';
      final sql = returning != null && returning!.isNotEmpty
          ? '$sqlBase RETURNING ${returning!.join(', ')}'
          : sqlBase;
      return (sql, const {});
    }

    final sqlBase =
        'INSERT INTO $table (${cols.join(', ')}) VALUES (${vals.join(', ')})';
    final sql = returning != null && returning!.isNotEmpty
        ? '$sqlBase RETURNING ${returning!.join(', ')}'
        : sqlBase;
    return (sql, finalMap);
  }
}

/// A specialized [Command] for dynamic deletes by primary key.
class DeleteCommand<P> extends Command<P> {
  final String table;
  final List<String> primaryKeys;
  final List<String>? returning;

  const DeleteCommand({
    required this.table,
    required this.primaryKeys,
    required dynamic params,
    this.returning,
  }) : super._dynamic(params: params);

  @override
  (String, Map<String, Object?>) apply(P? p) {
    final rawMap = _resolveParams<P>(params, p);
    final finalMap = <String, Object?>{};
    final where = <String>[];

    for (final key in rawMap.keys) {
      if (primaryKeys.contains(key)) {
        where.add('$key = @$key');
        finalMap[key] = rawMap[key];
      }
    }

    if (where.isEmpty) {
      throw ArgumentError('DeleteCommand requires at least one primary key.');
    }

    final sqlBase = 'DELETE FROM $table WHERE ${where.join(' AND ')}';
    final sql = returning != null && returning!.isNotEmpty
        ? '$sqlBase RETURNING ${returning!.join(', ')}'
        : sqlBase;
    return (sql, finalMap);
  }
}
