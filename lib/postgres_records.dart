part of 'db_wrapper.dart';

class _PostgresRowData implements RowData {
  final pg.ResultRow _row;
  _PostgresRowData(this._row);

  @override
  Object? operator [](String key) {
    // ResultRow.toColumnMap() returns a map of column names to values.
    // This is the easiest way to support name-based access.
    return _row.toColumnMap()[key];
  }
}

class _PostgresMutationResult implements MutationResult {
  final pg.Result _result;
  _PostgresMutationResult(this._result);

  @override
  int get affectedRows => _result.affectedRows;

  @override
  Object? get lastInsertId => null; // Postgres requires RETURNING clause
}

class _PostgresReadContext implements SqlRecordsReadonly {
  final pg.Session _session;

  _PostgresReadContext(this._session);

  @override
  Future<SafeResultSet<R>> getAll<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, map) = query.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    return SafeResultSet<R>(
        result.map((row) => _PostgresRowData(row)), query.schema);
  }

  @override
  Future<SafeRow<R>> get<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, map) = query.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    if (result.isEmpty) {
      throw StateError('Query returned no rows');
    }
    return SafeRow<R>(_PostgresRowData(result.first), query.schema);
  }

  @override
  Future<SafeRow<R>?> getOptional<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, map) = query.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    if (result.isEmpty) return null;
    return SafeRow<R>(_PostgresRowData(result.first), query.schema);
  }
}

class _PostgresWriteContext extends _PostgresReadContext implements SqlRecords {
  _PostgresWriteContext(pg.Session session) : super(session);

  @override
  Future<MutationResult> execute<P>(Command<P> mutation, [P? params]) async {
    final (sql, map) = mutation.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    return _PostgresMutationResult(result);
  }

  @override
  Future<void> executeBatch<P>(Command<P> mutation, List<P> paramsList) async {
    // Postgres package doesn't have a native batch execute in pg.Session.
    // We execute them sequentially within the current session.
    for (final p in paramsList) {
      final (sql, map) = mutation.apply(p);
      await _session.execute(pg.Sql.named(sql), parameters: map);
    }
  }

  @override
  Stream<SafeResultSet<R>> watch<P, R extends Record>(Query<P, R> query,
      {P? params,
      Duration throttle = const Duration(milliseconds: 30),
      Iterable<String>? triggerOnTables}) {
    throw UnsupportedError('watch() is not supported for Postgres.');
  }

  @override
  Future<T> readTransaction<T>(
      Future<T> Function(SqlRecordsReadonly tx) action) async {
    // Postgres transactions can be read-only.
    return _session.runTx((tx) => action(_PostgresReadContext(tx)));
  }

  @override
  Future<T> writeTransaction<T>(Future<T> Function(SqlRecords tx) action) {
    return _session.runTx((tx) => action(_PostgresWriteContext(tx)));
  }
}
