import 'safe_row.dart';

/// Common parser logic for SQLite values.
abstract final class SqliteParsers {
  /// Logic for [SafeRowConvenience.parseEnumByName].
  static T enumByName<T extends Enum>(String dbVal, Iterable<T> values) {
    return values.byName(dbVal);
  }

  /// Logic for [SafeRowConvenience.parseDateTime].
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

extension SafeRowConvenience on SafeRow {
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
    return parse<DateTime, Object>(key, SqliteParsers.dateTime);
  }

  /// Parses an optional SQLite value (epoch integer or ISO-8601 string) into a Dart DateTime.
  DateTime? parseDateTimeOptional(String key) {
    return parseOptional<DateTime, Object>(key, SqliteParsers.dateTime);
  }
}
