part of 'db_wrapper.dart';

class _SqliteRowData implements RowData {
  final sqlite.Row _row;
  _SqliteRowData(this._row);

  @override
  Object? operator [](String key) => _row[key];
}

class _SqliteMutationResult implements MutationResult {
  final sqlite.ResultSet _result;
  _SqliteMutationResult(this._result);

  @override
  int get affectedRows => _result.affectedRows;

  @override
  Object? get lastInsertId => _result.lastInsertRowId;
}

/// Implementation for read-only contexts (transactions).
class _PowerSyncReadContext implements SqlRecordsReadonly {
  final SqliteReadContext _readCtx;

  _PowerSyncReadContext(this._readCtx);

  Map<String, Object?>? _resolveParams<P>(dynamic params, P? p) {
    if (params == null) return null;
    if (params is Map<String, Object?>) return params;
    if (params is Function) return (params as ParamMapper<P>)(p as P);
    return null;
  }

  (String, List<Object?>) _translateSql(String sql, Map<String, Object?> map) {
    final List<Object?> args = [];
    final pattern = RegExp(r'@([a-zA-Z0-9_]+)');

    final translatedSql = sql.replaceAllMapped(pattern, (match) {
      final name = match.group(1)!;
      if (!map.containsKey(name)) {
        throw ArgumentError('Missing parameter: $name');
      }

      final value = map[name];
      args.add(value is SQL ? value.value : value);
      return '?';
    });

    return (translatedSql, args);
  }

  (String, List<Object?>) _prepare<P>(
      String sql, dynamic mapper, P? params) {
    final map = _resolveParams(mapper, params);
    if (map == null) return (sql, const []);
    return _translateSql(sql, map);
  }

  @override
  Future<SafeResultSet<R>> getAll<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final results = await _readCtx.getAll(sql, args);
    return SafeResultSet<R>(
        results.map((row) => _SqliteRowData(row)), query.schema);
  }

  @override
  Future<SafeRow<R>> get<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final row = await _readCtx.get(sql, args);
    return SafeRow<R>(_SqliteRowData(row), query.schema);
  }

  @override
  Future<SafeRow<R>?> getOptional<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final row = await _readCtx.getOptional(sql, args);
    return row != null ? SafeRow<R>(_SqliteRowData(row), query.schema) : null;
  }
}

/// Implementation for read-write contexts and main DB connection.
class _PowerSyncWriteContext extends _PowerSyncReadContext
    implements SqlRecords {
  final SqliteWriteContext _writeCtx;

  _PowerSyncWriteContext(this._writeCtx) : super(_writeCtx);

  @override
  Future<MutationResult> execute<P>(Command<P> mutation, [P? params]) async {
    final (sql, map) = mutation.apply(params);
    final (_, args) = _translateSql(sql, map);
    final result = await _writeCtx.execute(sql, args);
    return _SqliteMutationResult(result);
  }

  @override
  Future<void> executeBatch<P>(Command<P> mutation, List<P> paramsList) async {
    // Grouping by SQL to allow batching of identical statements.
    final Map<String, List<List<Object?>>> batches = {};

    for (final p in paramsList) {
      final (sql, map) = mutation.apply(p);
      final (_, args) = _translateSql(sql, map);
      batches.putIfAbsent(sql, () => []).add(args);
    }

    for (final entry in batches.entries) {
      await _writeCtx.executeBatch(entry.key, entry.value);
    }
  }

  @override
  Stream<SafeResultSet<R>> watch<P, R extends Record>(Query<P, R> query,
      {P? params,
      Duration throttle = const Duration(milliseconds: 30),
      Iterable<String>? triggerOnTables}) {
    final ctx = _writeCtx;
    if (ctx is PowerSyncDatabase) {
      final (sql, map) = query.apply(params);
      final (_, args) = _translateSql(sql, map);
      return ctx
          .watch(sql,
              parameters: args,
              throttle: throttle,
              triggerOnTables: triggerOnTables)
          .map((results) => SafeResultSet<R>(
              results.map((row) => _SqliteRowData(row)), query.schema));
    }
    throw UnsupportedError(
        'watch() is only supported on the main database connection.');
  }

  @override
  Future<T> readTransaction<T>(
      Future<T> Function(SqlRecordsReadonly tx) action) {
    final ctx = _writeCtx;
    if (ctx is SqliteConnection) {
      return ctx.readTransaction((tx) => action(_PowerSyncReadContext(tx)));
    }
    throw UnsupportedError(
        'readTransaction() can only be started from the main database connection.');
  }

  @override
  Future<T> writeTransaction<T>(Future<T> Function(SqlRecords tx) action) {
    return _writeCtx
        .writeTransaction((tx) => action(_PowerSyncWriteContext(tx)));
  }
}
