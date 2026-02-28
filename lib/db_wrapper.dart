import 'dart:async';
import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:postgres/postgres.dart' as pg;
import 'query.dart';
import 'safe_row.dart';

part 'powersync_records.dart';
part 'postgres_records.dart';

/// Context for read-only operations.
abstract interface class SqlRecordsReadonly {
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

/// Information about a mutation (INSERT, UPDATE, DELETE).
abstract interface class MutationResult {
  /// The number of rows affected by the mutation.
  int get affectedRows;

  /// The ID of the last inserted row, if applicable.
  Object? get lastInsertId;
}

/// The core executor interface, supporting mutations and transactions.
abstract interface class SqlRecords implements SqlRecordsReadonly {
  /// Executes a single mutation.
  Future<MutationResult> execute<P>(
    Command<P> mutation, [
    P? params,
  ]);

  /// Executes a mutation multiple times in a single batch operation.
  Future<void> executeBatch<P>(
    Command<P> mutation,
    List<P> paramsList,
  );

  /// Reactively watches a query for changes.
  /// NOTE: This may not be supported by all database engines.
  Stream<SafeResultSet<R>> watch<P, R extends Record>(
    Query<P, R> query, {
    P? params,
    Duration throttle = const Duration(milliseconds: 30),
    Iterable<String>? triggerOnTables,
  });

  /// Opens a read-write transaction.
  Future<T> writeTransaction<T>(Future<T> Function(SqlRecords tx) action);

  /// Opens a read-only transaction.
  Future<T> readTransaction<T>(
      Future<T> Function(SqlRecordsReadonly tx) action);
}

/// Creates a [SqlRecords] instance from a [PowerSyncDatabase].
SqlRecords SqlRecordsPowerSync(PowerSyncDatabase db) =>
    _PowerSyncWriteContext(db);

/// Creates a [SqlRecords] instance from a Postgres [Session].
SqlRecords SqlRecordsPostgres(pg.Session session) =>
    _PostgresWriteContext(session);

/// Alias for [SqlRecords] to maintain backward compatibility.
typedef SqliteRecords = SqlRecords;

/// Alias for [SqlRecordsReadonly] to maintain backward compatibility.
typedef SqliteRecordsReadonly = SqlRecordsReadonly;
