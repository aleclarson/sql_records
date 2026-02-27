import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'query.dart';

/// [R] is the Expected Record type (enables compile-time key validation via custom linters).
class SafeRow<R extends Record> {
  final sqlite.Row _raw;
  final ResultSchema _schema;

  const SafeRow(this._raw, this._schema);

  /// Unsafe, dynamic map access (bypasses schema and type checks).
  dynamic operator [](String key) => _raw[key];

  void _validateAccess<T>(String key) {
    if (!_schema.containsKey(key)) {
      throw ArgumentError(
        'Schema Error: Key "$key" is not defined in the Query schema.',
      );
    }

    // Asserts the caller is using the type they declared in the schema.
    final expectedType = _schema[key];
    if (expectedType != T) {
      throw ArgumentError(
        'Schema Mismatch: Requested <$T> for "$key", but schema declared <$expectedType>.',
      );
    }
  }

  /// Reads a value. Allows the database value to be null.
  /// Throws if the key is missing from the schema or the type mismatches.
  T? read<T>(String key) {
    _validateAccess<T>(key);

    final value = _raw[key];
    if (value != null && value is! T) {
      throw StateError(
        'DB Type Mismatch: Expected $T? for "$key", got ${value.runtimeType}.',
      );
    }
    return value as T?;
  }

  /// Reads a value. Throws if the database value is null.
  /// Throws if the key is missing from the schema or the type mismatches.
  T require<T>(String key) {
    _validateAccess<T>(key);

    final value = _raw[key];
    if (value == null) {
      throw StateError(
          'Null Error: Column "$key" is null in DB, but require<$T> was called.');
    }
    if (value is! T) {
      throw StateError(
        'DB Type Mismatch: Expected $T for "$key", got ${value.runtimeType}.',
      );
    }
    return value;
  }

  /// Reads a primitive database value [DB] and parses it into a custom type [T].
  /// Throws if the column is null, missing from schema, or if parsing fails.
  T parse<T, DB>(String key, T Function(DB dbValue) parser) {
    final dbValue = require<DB>(key);
    return parser(dbValue);
  }

  /// Same as [parse], but allows the database value to be null.
  T? parseOptional<T, DB>(String key, T Function(DB dbValue) parser) {
    final dbValue = read<DB>(key);
    if (dbValue == null) return null;
    return parser(dbValue);
  }
}

class SafeResultSet<R extends Record> extends Iterable<SafeRow<R>> {
  final sqlite.ResultSet _raw;
  final ResultSchema _schema;

  SafeResultSet(this._raw, this._schema);

  @override
  Iterator<SafeRow<R>> get iterator =>
      _raw.map((row) => SafeRow<R>(row, _schema)).iterator;

  /// Returns the number of rows in the result set.
  int get length => _raw.length;
}
