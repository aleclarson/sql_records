import 'package:sql_records/sql_records.dart';
import 'package:test/test.dart';

class TestRow<R extends Record> extends Row<R> {
  final Map<String, Object?> _data;
  TestRow(this._data, super.schema);

  @override
  Object? operator [](String key) => _data[key];
}

void main() {
  group('Row', () {
    test('get<T> returns value and validates schema', () {
      final row = TestRow<({String name, int age})>(
        {'name': 'Alec', 'age': 30},
        {'name': String, 'age': int},
      );

      expect(row.get<String>('name'), equals('Alec'));
      expect(row.get<int>('age'), equals(30));
    });

    test('get<T> throws on missing schema key', () {
      final row = TestRow<({String name})>(
        {'name': 'Alec'},
        {'name': String},
      );

      expect(() => row.get<String>('age'), throwsArgumentError);
    });

    test('get<T> throws on schema type mismatch', () {
      final row = TestRow<({String name})>(
        {'name': 'Alec'},
        {'name': String},
      );

      expect(() => row.get<int>('name'), throwsArgumentError);
    });

    test('get<T> throws on null value for non-optional get', () {
      final row = TestRow<({String? name})>(
        {'name': null},
        {'name': String},
      );

      expect(() => row.get<String>('name'), throwsStateError);
    });

    test('getOptional<T> returns null for null value', () {
      final row = TestRow<({String? name})>(
        {'name': null},
        {'name': String},
      );

      expect(row.getOptional<String>('name'), isNull);
    });

    test('parse<T, DB> parses value', () {
      final row = TestRow<({String name})>(
        {'name': 'ALEC'},
        {'name': String},
      );

      final result = row.parse<String, String>('name', (s) => s.toLowerCase());
      expect(result, equals('alec'));
    });

    test('parseDateTime reads epoch integers from an int schema', () {
      final row = TestRow<({int createdAt})>(
        {'createdAt': 1710000000000},
        {'createdAt': int},
      );

      expect(
        row.parseDateTime('createdAt'),
        equals(DateTime.fromMillisecondsSinceEpoch(1710000000000)),
      );
    });

    test('parseDateTime reads ISO strings from a string schema', () {
      final row = TestRow<({String createdAt})>(
        {'createdAt': '2024-03-09T16:00:00Z'},
        {'createdAt': String},
      );

      expect(
        row.parseDateTime('createdAt'),
        equals(DateTime.parse('2024-03-09T16:00:00Z')),
      );
    });

    test('parseDateTimeOptional returns null for null values', () {
      final row = TestRow<({String? createdAt})>(
        {'createdAt': null},
        {'createdAt': String},
      );

      expect(row.parseDateTimeOptional('createdAt'), isNull);
    });
  });

  group('RowSet', () {
    test('iterates over Row', () {
      final rows = [
        TestRow<({String name})>({'name': 'Alec'}, {'name': String}),
        TestRow<({String name})>({'name': 'Bob'}, {'name': String}),
      ];
      final resultSet = RowSet<({String name})>(rows);

      expect(resultSet.length, equals(2));
      expect(resultSet.first.get<String>('name'), equals('Alec'));
      expect(resultSet.last.get<String>('name'), equals('Bob'));
    });
  });
}
