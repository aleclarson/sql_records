import 'dart:async';
import 'query.dart';
import 'safe_row.dart';

export 'query.dart';
export 'safe_row.dart';
export 'extensions.dart';

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
  /// The number of rows affected by the mutation, if available.
  int? get affectedRows;

  /// The ID of the last inserted row, if available.
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
