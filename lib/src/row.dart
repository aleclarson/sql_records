import 'query.dart';

/// [R] is the Expected Record type (enables compile-time key validation via custom linters).
abstract class Row<R extends Record> {
  final ResultSchema _schema;

  const Row(this._schema);

  /// Unsafe, dynamic map access (bypasses schema and type checks).
  Object? operator [](String key);

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
        'Schema Error: Requested <$T> for "$key", but schema declared <$expectedType>.',
      );
    }
  }

  /// Reads a value. Allows the database value to be null.
  /// Throws if the key is missing from the schema or the type mismatches.
  T? getOptional<T>(String key) {
    _validateAccess<T>(key);

    final value = this[key];
    if (value != null && value is! T) {
      throw StateError(
        'DB Type Mismatch: Expected $T? for "$key", got ${value.runtimeType}.',
      );
    }
    return value as T?;
  }

  /// Reads a value. Throws if the database value is null.
  /// Throws if the key is missing from the schema or the type mismatches.
  T get<T>(String key) {
    _validateAccess<T>(key);

    final value = this[key];
    if (value == null) {
      throw StateError(
          'Null Error: Column "$key" is null in DB, but get<$T> was called.');
    }
    if (value is! T) {
      throw StateError(
        'DB Type Mismatch: Expected $T for "$key", got ${value.runtimeType}.',
      );
    }
    return value as T;
  }

  /// Reads a primitive database value [DB] and parses it into a custom type [T].
  /// Throws if the column is null, missing from schema, or if parsing fails.
  T parse<T, DB>(String key, T Function(DB dbValue) parser) {
    final dbValue = get<DB>(key);
    return parser(dbValue);
  }

  /// Same as [parse], but allows the database value to be null.
  T? parseOptional<T, DB>(String key, T Function(DB dbValue) parser) {
    final dbValue = getOptional<DB>(key);
    if (dbValue == null) return null;
    return parser(dbValue);
  }
}

class RowSet<R extends Record> extends Iterable<Row<R>> {
  final Iterable<Row<R>> _rows;

  RowSet(this._rows);

  @override
  Iterator<Row<R>> get iterator => _rows.iterator;

  /// Returns the number of rows in the result set.
  @override
  int get length => _rows.length;
}
