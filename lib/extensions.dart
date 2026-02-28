import 'safe_row.dart';

extension SafeRowConvenience on SafeRow {
  // --- STRING ENUMS ---

  /// Parses a SQLite String into a Dart Enum using its name.
  T parseEnumByName<T extends Enum>(String key, Iterable<T> values) {
    return parse<T, String>(key, (dbVal) => values.byName(dbVal));
  }

  /// Parses an optional SQLite String into a Dart Enum using its name.
  T? parseEnumByNameOptional<T extends Enum>(String key, Iterable<T> values) {
    return parseOptional<T, String>(key, (dbVal) => values.byName(dbVal));
  }

  // --- DATETIME ---

  /// Parses a SQLite value (epoch integer or ISO-8601 string) into a Dart DateTime.
  DateTime parseDateTime(String key) {
    return parse<DateTime, Object>(key, (dbVal) {
      if (dbVal is int) {
        return DateTime.fromMillisecondsSinceEpoch(dbVal);
      }
      if (dbVal is String) {
        return DateTime.parse(dbVal);
      }
      throw StateError(
          'DB Type Mismatch: Expected int or String for "$key", got ${dbVal.runtimeType}.');
    });
  }

  /// Parses an optional SQLite value (epoch integer or ISO-8601 string) into a Dart DateTime.
  DateTime? parseDateTimeOptional(String key) {
    return parseOptional<DateTime, Object>(key, (dbVal) {
      if (dbVal is int) {
        return DateTime.fromMillisecondsSinceEpoch(dbVal);
      }
      if (dbVal is String) {
        return DateTime.parse(dbVal);
      }
      throw StateError(
          'DB Type Mismatch: Expected int or String for "$key", got ${dbVal.runtimeType}.');
    });
  }
}
