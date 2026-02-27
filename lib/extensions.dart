import 'safe_row.dart';

extension SafeRowConvenience on SafeRow {
  // --- STRING ENUMS ---

  /// Parses a SQLite String into a Dart Enum using its name.
  T requireEnumByName<T extends Enum>(String key, Iterable<T> values) {
    return parse<T, String>(key, (dbVal) => values.byName(dbVal));
  }

  T? readEnumByName<T extends Enum>(String key, Iterable<T> values) {
    return parseOptional<T, String>(key, (dbVal) => values.byName(dbVal));
  }

  // --- INT ENUMS ---

  /// Parses a SQLite integer into a Dart Enum using its index declaration.
  T requireEnumByIndex<T extends Enum>(String key, List<T> values) {
    return parse<T, int>(key, (index) => values[index]);
  }

  T? readEnumByIndex<T extends Enum>(String key, List<T> values) {
    return parseOptional<T, int>(key, (index) => values[index]);
  }

  // --- DATETIME (Example assuming Milliseconds Since Epoch) ---

  /// Parses a SQLite integer (epoch) into a Dart DateTime.
  DateTime requireDateTime(String key) {
    return parse<DateTime, int>(key, DateTime.fromMillisecondsSinceEpoch);
  }

  DateTime? readDateTime(String key) {
    return parseOptional<DateTime, int>(
        key, DateTime.fromMillisecondsSinceEpoch);
  }
}
