import 'package:postgres/postgres.dart' as pg;
import 'package:meta/meta.dart';
import 'core.dart';

export 'core.dart';

/// Creates a [SqlRecords] instance from a Postgres [pg.Session].
SqlRecords SqlRecordsPostgres(pg.Session session) =>
    PostgresWriteContext(session);

@internal
class PostgresRow<R extends Record> extends Row<R> {
  final pg.ResultRow _row;
  PostgresRow(this._row, super.schema);

  @override
  Object? operator [](String key) {
    for (final (i, col) in _row.schema.columns.indexed) {
      if (col.columnName case final String columnName) {
        if (columnName == key) return _row[i];
      }
    }
    return null;
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
  Future<RowSet<R>> getAll<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, map) = query.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    return RowSet<R>(result.map((row) => PostgresRow<R>(row, query.schema)));
  }

  @override
  Future<Row<R>> get<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, map) = query.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    if (result.isEmpty) {
      throw StateError('Query returned no rows');
    }
    return PostgresRow<R>(result.first, query.schema);
  }

  @override
  Future<Row<R>?> getOptional<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, map) = query.apply(params);
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    if (result.isEmpty) return null;
    return PostgresRow<R>(result.first, query.schema);
  }
}

@internal
class PostgresWriteContext extends PostgresReadContext implements SqlRecords {
  PostgresWriteContext(pg.Session session) : super(session);

  @override
  Future<MutationResult> execute<P>(Command<P> mutation, [P? params]) async {
    final (sql, map) = mutation.apply(params);
    if (sql == NoOpCommand) return const NoOpMutationResult();
    final result = await _session.execute(pg.Sql.named(sql), parameters: map);
    return PostgresMutationResult(result);
  }

  @override
  Future<void> executeBatch<P>(Command<P> mutation, List<P> paramsList) async {
    for (final p in paramsList) {
      final (sql, map) = mutation.apply(p);
      if (sql == NoOpCommand) continue;
      await _session.execute(pg.Sql.named(sql), parameters: map);
    }
  }

  @override
  Stream<RowSet<R>> watch<P, R extends Record>(Query<P, R> query,
      {P? params,
      Duration throttle = const Duration(milliseconds: 30),
      Iterable<String>? triggerOnTables}) {
    throw UnsupportedError('watch() is only supported for PowerSync.');
  }

  @override
  Future<T> readTransaction<T>(
      Future<T> Function(SqlRecordsReadonly tx) action) async {
    return (_session as pg.SessionExecutor).runTx(
      (tx) => action(PostgresReadContext(tx)),
      settings: pg.TransactionSettings(accessMode: pg.AccessMode.readOnly),
    );
  }

  @override
  Future<T> writeTransaction<T>(Future<T> Function(SqlRecords tx) action) {
    return (_session as pg.SessionExecutor)
        .runTx((tx) => action(PostgresWriteContext(tx)));
  }
}
