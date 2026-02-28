import 'package:postgres/postgres.dart' as pg;
import 'package:meta/meta.dart';
import 'core.dart';

export 'core.dart';

/// Creates a [SqlRecords] instance from a Postgres [pg.Session].
SqlRecords SqlRecordsPostgres(pg.Session session) =>
    PostgresWriteContext(session);

@internal
class PostgresRowData implements RowData {
  final pg.ResultRow _row;
  PostgresRowData(this._row);

  @override
  Object? operator [](String key) {
    return _row.toColumnMap()[key];
  }
}

@internal
class PostgresMutationResult implements MutationResult {
  final pg.Result _result;
  PostgresMutationResult(this._result);

  @override
  int? get affectedRows => _result.affectedRows;

  @override
  Object? get lastInsertId => null;
}

@internal
class PostgresReadContext implements SqlRecordsReadonly {
  final pg.Session _session;

  PostgresReadContext(this._session);

  @override
  Future<SafeResultSet<R>> getAll<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, map) = query.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    return SafeResultSet<R>(
        result.map((row) => PostgresRowData(row)), query.schema);
  }

  @override
  Future<SafeRow<R>> get<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, map) = query.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    if (result.isEmpty) {
      throw StateError('Query returned no rows');
    }
    return SafeRow<R>(PostgresRowData(result.first), query.schema);
  }

  @override
  Future<SafeRow<R>?> getOptional<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, map) = query.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    if (result.isEmpty) return null;
    return SafeRow<R>(PostgresRowData(result.first), query.schema);
  }
}

@internal
class PostgresWriteContext extends PostgresReadContext implements SqlRecords {
  PostgresWriteContext(pg.Session session) : super(session);

  @override
  Future<MutationResult> execute<P>(Command<P> mutation, [P? params]) async {
    final (sql, map) = mutation.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    return PostgresMutationResult(result);
  }

  @override
  Future<void> executeBatch<P>(Command<P> mutation, List<P> paramsList) async {
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
    throw UnsupportedError('watch() is only supported for PowerSync.');
  }

  @override
  Future<T> readTransaction<T>(
      Future<T> Function(SqlRecordsReadonly tx) action) async {
    return _session.runTx((tx) => action(PostgresReadContext(tx)));
  }

  @override
  Future<T> writeTransaction<T>(Future<T> Function(SqlRecords tx) action) {
    return _session.runTx((tx) => action(PostgresWriteContext(tx)));
  }
}
