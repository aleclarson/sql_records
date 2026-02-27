import 'dart:async';
import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'query.dart';
import 'safe_row.dart';

/// Context for read-only operations.
abstract interface class SqliteReadRecords {
  /// Fetches all rows matching the query.
  Future<SafeResultSet<R>> getAll<P, R extends Record>(
    Query<P, R> query, [
    P? params,
  ]);

  /// Fetches exactly one row. Throws if no row is found.
  Future<SafeRow<R>> get<P, R extends Record>(
    Query<P, R> query, [
    P? params,
  ]);

  /// Fetches an optional row. Returns null if not found.
  Future<SafeRow<R>?> getOptional<P, R extends Record>(
    Query<P, R> query, [
    P? params,
  ]);
}

/// The core executor interface, supporting mutations and transactions.
abstract interface class SqliteRecords implements SqliteReadRecords {
  /// Creates a [SqliteRecords] instance from a [PowerSyncDatabase].
  factory SqliteRecords.fromPowerSync(PowerSyncDatabase db) =>
      _PowerSyncSqliteRecords(db);

  /// Executes a single mutation.
  Future<sqlite.ResultSet> execute<P>(
    Command<P> mutation, [
    P? params,
  ]);

  /// Executes a mutation multiple times in a single batch operation.
  Future<void> executeBatch<P>(
    Command<P> mutation,
    List<P> paramsList,
  );

  /// Reactively watches a query for changes.
  /// NOTE: This is only supported on the main database connection, not in transactions.
  Stream<SafeResultSet<R>> watch<P, R extends Record>(
    Query<P, R> query, {
    P? params,
    Duration throttle = const Duration(milliseconds: 30),
    Iterable<String>? triggerOnTables,
  });

  /// Opens a read-write transaction.
  Future<T> writeTransaction<T>(Future<T> Function(SqliteRecords tx) action);

  /// Opens a read-only transaction.
  Future<T> readTransaction<T>(Future<T> Function(SqliteReadRecords tx) action);
}

/// Shared logic for preparing and executing queries.
abstract class _SqliteRecordsBase {
  SqliteReadContext get _readCtx;

  /// Translates named parameters (@name) into positional ones (?) for PowerSync.
  (String, List<Object?>) _prepare<P>(
      String sql, ParamMapper<P>? mapper, P? params) {
    if (mapper == null || params == null) {
      return (sql, const []);
    }

    final map = mapper(params);
    final List<Object?> args = [];
    final pattern = RegExp(r'@([a-zA-Z0-9_]+)');

    final translatedSql = sql.replaceAllMapped(pattern, (match) {
      final name = match.group(1)!;
      if (!map.containsKey(name)) {
        throw ArgumentError('Missing parameter: $name');
      }
      args.add(map[name]);
      return '?';
    });

    return (translatedSql, args);
  }

  Future<SafeResultSet<R>> getAll<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final results = await _readCtx.getAll(sql, args);
    return SafeResultSet<R>(results, query.schema);
  }

  Future<SafeRow<R>> get<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final row = await _readCtx.get(sql, args);
    return SafeRow<R>(row, query.schema);
  }

  Future<SafeRow<R>?> getOptional<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final row = await _readCtx.getOptional(sql, args);
    return row != null ? SafeRow<R>(row, query.schema) : null;
  }
}

/// Implementation for read-only contexts (transactions).
class _SqliteReadRecordsImpl extends _SqliteRecordsBase
    implements SqliteReadRecords {
  @override
  final SqliteReadContext _readCtx;

  _SqliteReadRecordsImpl(this._readCtx);
}

/// Implementation for read-write contexts and main DB connection.
class _PowerSyncSqliteRecords extends _SqliteRecordsBase
    implements SqliteRecords {
  final SqliteWriteContext _writeCtx;

  _PowerSyncSqliteRecords(this._writeCtx);

  @override
  SqliteReadContext get _readCtx => _writeCtx;

  @override
  Future<sqlite.ResultSet> execute<P>(Command<P> mutation, [P? params]) async {
    final (sql, args) = _prepare(mutation.sql, mutation.params, params);
    return _writeCtx.execute(sql, args);
  }

  @override
  Future<void> executeBatch<P>(Command<P> mutation, List<P> paramsList) async {
    final List<List<Object?>> allArgs = [];
    String? finalSql;

    for (final p in paramsList) {
      final (sql, args) = _prepare(mutation.sql, mutation.params, p);
      finalSql ??= sql;
      allArgs.add(args);
    }

    if (finalSql != null) {
      return _writeCtx.executeBatch(finalSql, allArgs);
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
      Future<T> Function(SqliteReadRecords tx) action) {
    final ctx = _writeCtx;
    if (ctx is SqliteConnection) {
      return ctx.readTransaction((tx) => action(_SqliteReadRecordsImpl(tx)));
    }
    throw UnsupportedError(
        'readTransaction() can only be started from the main database connection.');
  }

  @override
  Future<T> writeTransaction<T>(Future<T> Function(SqliteRecords tx) action) {
    return _writeCtx
        .writeTransaction((tx) => action(_PowerSyncSqliteRecords(tx)));
  }
}
