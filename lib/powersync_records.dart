part of 'db_wrapper.dart';

/// Implementation for read-only contexts (transactions).
class _PowerSyncReadContext implements SqliteRecordsReadonly {
  final SqliteReadContext _readCtx;

  _PowerSyncReadContext(this._readCtx);

  /// Translates named parameters (@name) into positional ones (?) for PowerSync.
  (String, List<Object?>) _prepare<P>(
      String sql, ParamMapper<P>? mapper, P? params) {
    final map = _resolveParams(mapper, params);
    if (map == null) return (sql, const []);
    return _translateSql(sql, map);
  }

  Map<String, Object?>? _resolveParams<P>(ParamMapper<P>? mapper, P? params) {
    if (mapper == null || params == null) return null;
    return mapper(params);
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

  @override
  Future<SafeResultSet<R>> getAll<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final results = await _readCtx.getAll(sql, args);
    return SafeResultSet<R>(results, query.schema);
  }

  @override
  Future<SafeRow<R>> get<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final row = await _readCtx.get(sql, args);
    return SafeRow<R>(row, query.schema);
  }

  @override
  Future<SafeRow<R>?> getOptional<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final row = await _readCtx.getOptional(sql, args);
    return row != null ? SafeRow<R>(row, query.schema) : null;
  }
}

/// Implementation for read-write contexts and main DB connection.
class _PowerSyncWriteContext extends _PowerSyncReadContext
    implements SqliteRecords {
  final SqliteWriteContext _writeCtx;

  _PowerSyncWriteContext(this._writeCtx) : super(_writeCtx);

  @override
  Future<sqlite.ResultSet> execute<P>(Command<P> mutation, [P? params]) async {
    final (sql, map) = mutation.apply(params);
    final (_, args) = _translateSql(sql, map);
    return _writeCtx.execute(sql, args);
  }

  @override
  Future<void> executeBatch<P>(Command<P> mutation, List<P> paramsList) async {
    // Grouping by SQL to allow batching of identical statements.
    // For UpdateCommand/InsertCommand, different params can result in different SQL.
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
      final (sql, args) = _prepare(query.sql, query.params, params);
      return ctx
          .watch(sql,
              parameters: args,
              throttle: throttle,
              triggerOnTables: triggerOnTables)
          .map((results) => SafeResultSet<R>(results, query.schema));
    }
    throw UnsupportedError(
        'watch() is only supported on the main database connection.');
  }

  @override
  Future<T> readTransaction<T>(
      Future<T> Function(SqliteRecordsReadonly tx) action) {
    final ctx = _writeCtx;
    if (ctx is SqliteConnection) {
      return ctx.readTransaction((tx) => action(_PowerSyncReadContext(tx)));
    }
    throw UnsupportedError(
        'readTransaction() can only be started from the main database connection.');
  }

  @override
  Future<T> writeTransaction<T>(Future<T> Function(SqliteRecords tx) action) {
    return _writeCtx
        .writeTransaction((tx) => action(_PowerSyncWriteContext(tx)));
  }
}
