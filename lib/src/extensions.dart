import 'row.dart';

/// Common parser logic for SQLite values.
abstract final class SqliteParsers {
  /// Logic for [RowConvenience.parseEnumByName].
  static T enumByName<T extends Enum>(String dbVal, Iterable<T> values) {
    return values.byName(dbVal);
  }

  /// Logic for [RowConvenience.parseDateTime].
  static DateTime dateTime(Object dbVal) {
    if (dbVal is int) {
      return DateTime.fromMillisecondsSinceEpoch(dbVal);
    }
    if (dbVal is String) {
      return DateTime.parse(dbVal);
    }
    throw ArgumentError(
        'DB Type Mismatch: Expected int or String, got ${dbVal.runtimeType}.');
  }
}

Object _readRequiredDateTimeValue(Row row, String key) {
  try {
    return row.get<int>(key);
  } on ArgumentError {
    try {
      return row.get<String>(key);
    } on ArgumentError {
      throw ArgumentError(
        'Schema Error: parseDateTime() expects "$key" to be declared as int or String in the Query schema.',
      );
    }
  }
}

Object? _readOptionalDateTimeValue(Row row, String key) {
  try {
    return row.getOptional<int>(key);
  } on ArgumentError {
    try {
      return row.getOptional<String>(key);
    } on ArgumentError {
      throw ArgumentError(
        'Schema Error: parseDateTimeOptional() expects "$key" to be declared as int or String in the Query schema.',
      );
    }
  }
}

extension RowConvenience on Row {
  // --- STRING ENUMS ---

  /// Parses a SQLite String into a Dart Enum using its name.
  T parseEnumByName<T extends Enum>(String key, Iterable<T> values) {
    return parse<T, String>(
        key, (dbVal) => SqliteParsers.enumByName(dbVal, values));
  }

  /// Parses an optional SQLite String into a Dart Enum using its name.
  T? parseEnumByNameOptional<T extends Enum>(String key, Iterable<T> values) {
    return parseOptional<T, String>(
        key, (dbVal) => SqliteParsers.enumByName(dbVal, values));
  }

  // --- DATETIME ---

  /// Parses a SQLite value (epoch integer or ISO-8601 string) into a Dart DateTime.
  DateTime parseDateTime(String key) {
    return SqliteParsers.dateTime(_readRequiredDateTimeValue(this, key));
  }

  /// Parses an optional SQLite value (epoch integer or ISO-8601 string) into a Dart DateTime.
  DateTime? parseDateTimeOptional(String key) {
    final dbVal = _readOptionalDateTimeValue(this, key);
    if (dbVal == null) return null;
    return SqliteParsers.dateTime(dbVal);
  }
}
