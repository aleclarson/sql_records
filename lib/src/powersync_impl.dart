import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:meta/meta.dart';
import 'core.dart';
import 'utils.dart';

export 'core.dart';

/// Creates a [SqlRecords] instance from a [PowerSyncDatabase].
SqlRecords SqlRecordsPowerSync(PowerSyncDatabase db) =>
    PowerSyncWriteContext(db);

@internal
class PowerSyncRowData implements RowData {
  final sqlite.Row _row;
  PowerSyncRowData(this._row);

  @override
  Object? operator [](String key) => _row[key];
}

@internal
class PowerSyncMutationResult implements MutationResult {
  PowerSyncMutationResult(sqlite.ResultSet _);

  @override
  int? get affectedRows => null; // Not directly available on sqlite3.ResultSet

  @override
  Object? get lastInsertId =>
      null; // Not directly available on sqlite3.ResultSet
}

/// Implementation for read-only contexts (transactions).
@internal
class PowerSyncReadContext implements SqlRecordsReadonly {
  final SqliteReadContext _readCtx;

  PowerSyncReadContext(this._readCtx);

  @override
  Future<SafeResultSet<R>> getAll<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = prepareSql(query.sql, query.params, params);
    final results = await _readCtx.getAll(sql, args);
    return SafeResultSet<R>(
        results.map((row) => PowerSyncRowData(row)), query.schema);
  }

  @override
  Future<SafeRow<R>> get<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = prepareSql(query.sql, query.params, params);
    final row = await _readCtx.get(sql, args);
    return SafeRow<R>(PowerSyncRowData(row), query.schema);
  }

  @override
  Future<SafeRow<R>?> getOptional<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = prepareSql(query.sql, query.params, params);
    final row = await _readCtx.getOptional(sql, args);
    return row != null ? SafeRow<R>(PowerSyncRowData(row), query.schema) : null;
  }
}

/// Implementation for read-write contexts and main DB connection.
@internal
class PowerSyncWriteContext extends PowerSyncReadContext implements SqlRecords {
  final SqliteWriteContext _writeCtx;

  PowerSyncWriteContext(this._writeCtx) : super(_writeCtx);

  @override
  Future<MutationResult> execute<P>(Command<P> mutation, [P? params]) async {
    final (sql, map) = mutation.apply(params);
    final (_, args) = translateSql(sql, map);
    final result = await _writeCtx.execute(sql, args);
    return PowerSyncMutationResult(result);
  }

  @override
  Future<void> executeBatch<P>(Command<P> mutation, List<P> paramsList) async {
    // Grouping by SQL to allow batching of identical statements.
    final Map<String, List<List<Object?>>> batches = {};

    for (final p in paramsList) {
      final (sql, map) = mutation.apply(p);
      final (_, args) = translateSql(sql, map);
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
      final (_, args) = translateSql(sql, map);
      return ctx
          .watch(sql,
              parameters: args,
              throttle: throttle,
              triggerOnTables: triggerOnTables)
          .map((results) => SafeResultSet<R>(
              results.map((row) => PowerSyncRowData(row)), query.schema));
    }
    throw UnsupportedError(
        'watch() is only supported on the main database connection.');
  }

  @override
  Future<T> readTransaction<T>(
      Future<T> Function(SqlRecordsReadonly tx) action) {
    final ctx = _writeCtx;
    if (ctx is SqliteConnection) {
      return ctx.readTransaction((tx) => action(PowerSyncReadContext(tx)));
    }
    throw UnsupportedError(
        'readTransaction() can only be started from the main database connection.');
  }

  @override
  Future<T> writeTransaction<T>(Future<T> Function(SqlRecords tx) action) {
    return _writeCtx
        .writeTransaction((tx) => action(PowerSyncWriteContext(tx)));
  }
}
