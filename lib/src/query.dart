/// Maps a Record/Class to a SQLite named parameter map.
typedef ParamMapper<P> = Map<String, Object?> Function(P params);

/// Explicit SQL-null marker for dynamic commands.
///
/// Primarily used with [UpdateCommand] and [InsertCommand] to distinguish
/// between "omit this field" (plain `null`) and "set this field to NULL"
/// (`SQL.NULL`).
class SQL {
  static const SQL NULL = SQL._();

  const SQL._();

  @override
  String toString() => 'SQL.NULL';
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

  /// Creates a query from this command with a RETURNING clause.
  Query<P, R> returning<R extends Record>(
    ResultSchema schema, {
    List<String>? columns,
  }) {
    return _ReturningQuery<P, R>(this, schema, columns);
  }

  /// Factory for static mutations.
  static Command<void> static(String sql) => Command<void>(sql);
}

class _ReturningQuery<P, R extends Record> extends Query<P, R> {
  final Command<P> command;
  final List<String>? columns;

  _ReturningQuery(this.command, ResultSchema schema, this.columns)
      : super('', schema: schema, params: command.params);

  @override
  (String, Map<String, Object?>) apply(P? p) {
    var (sql, map) = command.apply(p);
    if (sql == NoOpCommand) return (sql, map);

    final cols = columns ?? schema.keys.toList();
    if (cols.isNotEmpty) {
      sql = '$sql RETURNING ${cols.map(_quoteIdentifier).join(', ')}';
    }
    return (sql, map);
  }
}

Map<String, Object?> _resolveParams<P>(dynamic params, P? p) {
  if (params == null) return const {};
  if (params is Map<String, Object?>) return params;
  if (params is Function) return (params as ParamMapper<P>)(p as P);
  throw ArgumentError('params must be a Map<String, Object?> or a ParamMapper');
}

String _quoteIdentifier(String identifier) {
  final escaped = identifier.replaceAll('"', '""');
  return '"$escaped"';
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

  const UpdateCommand({
    required this.table,
    required this.primaryKeys,
    required dynamic params,
  }) : super._dynamic(params: params);

  @override
  (String, Map<String, Object?>) apply(P? p) {
    final rawMap = _resolveParams<P>(params, p);
    final finalMap = <String, Object?>{};
    final updates = <String>[];
    final where = <String>[];
    var paramIndex = 0;

    for (final key in rawMap.keys) {
      final value = rawMap[key];
      final quotedKey = _quoteIdentifier(key);

      if (primaryKeys.contains(key)) {
        final paramName = 'p${paramIndex++}';
        where.add('$quotedKey = @$paramName');
        finalMap[paramName] = value;
        continue;
      }

      if (value is SQL) {
        updates.add('$quotedKey = NULL');
        continue;
      }

      // Skip plain nulls for patching
      if (value != null) {
        final paramName = 'p${paramIndex++}';
        updates.add('$quotedKey = @$paramName');
        finalMap[paramName] = value;
      }
    }

    if (updates.isEmpty) {
      // Return a no-op SQL if no fields were provided for update.
      return (NoOpCommand, const {});
    }

    if (where.isEmpty) {
      throw ArgumentError('UpdateCommand requires at least one primary key.');
    }

    final sql =
        'UPDATE ${_quoteIdentifier(table)} SET ${updates.join(', ')} WHERE ${where.join(' AND ')}';
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

  const InsertCommand({
    required this.table,
    required dynamic params,
  }) : super._dynamic(params: params);

  @override
  (String, Map<String, Object?>) apply(P? p) {
    final rawMap = _resolveParams<P>(params, p);
    final finalMap = <String, Object?>{};
    final cols = <String>[];
    final vals = <String>[];
    var paramIndex = 0;

    for (final entry in rawMap.entries) {
      final key = entry.key;
      final value = entry.value;
      final quotedKey = _quoteIdentifier(key);

      if (value is SQL) {
        cols.add(quotedKey);
        vals.add('NULL');
        continue;
      }

      // Skip plain nulls
      if (value != null) {
        final paramName = 'p${paramIndex++}';
        cols.add(quotedKey);
        vals.add('@$paramName');
        finalMap[paramName] = value;
      }
    }

    if (cols.isEmpty) {
      return (
        'INSERT INTO ${_quoteIdentifier(table)} DEFAULT VALUES',
        const {}
      );
    }

    final sql =
        'INSERT INTO ${_quoteIdentifier(table)} (${cols.join(', ')}) VALUES (${vals.join(', ')})';
    return (sql, finalMap);
  }
}

/// A specialized [Command] for dynamic deletes by primary key.
class DeleteCommand<P> extends Command<P> {
  final String table;
  final List<String> primaryKeys;

  const DeleteCommand({
    required this.table,
    required this.primaryKeys,
    required dynamic params,
  }) : super._dynamic(params: params);

  @override
  (String, Map<String, Object?>) apply(P? p) {
    final rawMap = _resolveParams<P>(params, p);
    final finalMap = <String, Object?>{};
    final where = <String>[];
    var paramIndex = 0;

    for (final key in rawMap.keys) {
      if (primaryKeys.contains(key)) {
        final paramName = 'p${paramIndex++}';
        where.add('${_quoteIdentifier(key)} = @$paramName');
        finalMap[paramName] = rawMap[key];
      }
    }

    if (where.isEmpty) {
      throw ArgumentError('DeleteCommand requires at least one primary key.');
    }

    final sql =
        'DELETE FROM ${_quoteIdentifier(table)} WHERE ${where.join(' AND ')}';
    return (sql, finalMap);
  }
}
