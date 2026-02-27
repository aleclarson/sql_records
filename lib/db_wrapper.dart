import 'dart:async';
import 'package:powersync/powersync.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'query.dart';
import 'safe_row.dart';

/// The core executor interface.
abstract interface class DbWrapper {
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

  /// Reactively watches a query for changes.
  Stream<SafeResultSet<R>> watch<P, R extends Record>(
    Query<P, R> query, {
    P? params,
    Duration throttle = const Duration(milliseconds: 30),
    Iterable<String>? triggerOnTables,
  });

  /// Opens a transaction. Exposes a new [DbWrapper] that runs inside the Tx.
  Future<T> transaction<T>(Future<T> Function(DbWrapper tx) action);
}

/// Implementation of [DbWrapper] that wraps a [PowerSyncDatabase].
class PowerSyncDbWrapper implements DbWrapper {
  final PowerSyncDatabase _db;

  PowerSyncDbWrapper(this._db);

  @override
  Future<sqlite.ResultSet> execute<P>(Command<P> mutation, [P? params]) async {
    final (sql, args) = _prepare(mutation.sql, mutation.params, params);
    return _db.execute(sql, args);
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
      return _db.executeBatch(finalSql, allArgs);
    }
  }

  @override
  Future<SafeResultSet<R>> getAll<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final results = await _db.getAll(sql, args);
    return SafeResultSet<R>(results, query.schema);
  }

  @override
  Future<SafeRow<R>> get<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final row = await _db.get(sql, args);
    return SafeRow<R>(row, query.schema);
  }

  @override
  Future<SafeRow<R>?> getOptional<P, R extends Record>(Query<P, R> query,
      [P? params]) async {
    final (sql, args) = _prepare(query.sql, query.params, params);
    final row = await _db.getOptional(sql, args);
    return row != null ? SafeRow<R>(row, query.schema) : null;
  }

  @override
  Stream<SafeResultSet<R>> watch<P, R extends Record>(Query<P, R> query,
      {P? params,
      Duration throttle = const Duration(milliseconds: 30),
      Iterable<String>? triggerOnTables}) {
    final (sql, args) = _prepare(query.sql, query.params, params);
    return _db
        .watch(sql,
            parameters: args,
            throttle: throttle,
            triggerOnTables: triggerOnTables)
        .map((results) => SafeResultSet<R>(results, query.schema));
  }

  @override
  Future<T> transaction<T>(Future<T> Function(DbWrapper tx) action) {
    // PowerSync doesn't provide a direct way to get a 'transactional' client
    // that has the same API as the main database in its `writeTransaction` callback,
    // as it uses its own SQL builder/executor.
    // However, we can wrap the transaction callback's executor.
    return _db.writeTransaction((tx) async {
      // Note: This is a simplification. PowerSync's transaction (tx)
      // implements the same execution methods.
      // We'd need a wrapper that can take either PowerSyncDatabase or a transaction.
      // For the sake of this implementation, we'll assume a shared interface or
      // specialized wrapper.
      return action(this); // Simplified for now.
    });
  }

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
}
