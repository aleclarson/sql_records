import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:sql_records/sqlite.dart';
import 'package:test/test.dart';

void main() {
  group('SQLite edge behavior', () {
    late sqlite.Database rawDb;
    late SqlRecords db;

    setUp(() {
      rawDb = sqlite.sqlite3.openInMemory();
      rawDb.execute('CREATE TABLE users (id TEXT PRIMARY KEY, name TEXT)');
      db = SqlRecordsSqlite(rawDb);
    });

    tearDown(() {
      rawDb.dispose();
    });

    test('throws when SQL placeholder has no parameter value', () async {
      final missingParam = Command.static(
        'UPDATE users SET name = @name WHERE id = @id',
      );

      await expectLater(
        db.execute(missingParam),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws for query when SQL placeholder has no parameter value',
        () async {
      final missingParamQuery = Query.static<({String id})>(
        'SELECT id FROM users WHERE id = @id',
        schema: {'id': String},
      );

      await expectLater(
        db.getAll(missingParamQuery),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('binds SQL.NULL as a null value for manual Command params', () async {
      await db.execute(Command.static(
        'INSERT INTO users (id, name) VALUES (@id, @name)',
        params: {'id': '1', 'name': SQL.NULL},
      ));

      final row = await db.get(
        Query<({String id}), ({String? name})>(
          'SELECT name FROM users WHERE id = @id',
          params: (p) => {'id': p.id},
          schema: {'name': String},
        ),
        (id: '1'),
      );

      expect(row.getOptional<String>('name'), isNull);
    });
  });
}
