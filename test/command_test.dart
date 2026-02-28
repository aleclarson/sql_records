import 'package:sql_records/powersync.dart';
import 'package:test/test.dart';

void main() {
  group('UpdateCommand', () {
    final patchUser = UpdateCommand<({String id, String? name, int? age})>(
      table: 'users',
      primaryKeys: ['id'],
      params: (p) => {
        'id': p.id,
        'name': p.name,
        'age': p.age,
      },
    );

    test('generates SQL for full update', () {
      final sql = patchUser.getSql((id: '1', name: 'Alec', age: 30));
      expect(sql,
          equals('UPDATE users SET name = @name, age = @age WHERE id = @id'));
    });

    test('generates SQL for partial update (patching)', () {
      final sql = patchUser.getSql((id: '1', name: 'Alec', age: null));
      expect(sql, equals('UPDATE users SET name = @name WHERE id = @id'));
    });

    test('generates no-op SQL when no fields are updated', () {
      final sql = patchUser.getSql((id: '1', name: null, age: null));
      expect(sql, equals('SELECT 1 WHERE 0'));
    });

    test('throws if primary key is missing', () {
      final invalidPatch = UpdateCommand<({String? name})>(
        table: 'users',
        primaryKeys: [],
        params: (p) => {'name': p.name},
      );
      expect(() => invalidPatch.getSql((name: 'Alec')), throwsArgumentError);
    });

    test('generates SQL for explicit null update (SQL wrapper)', () {
      final patchDynamic =
          UpdateCommand<({String id, dynamic name, dynamic age})>(
        table: 'users',
        primaryKeys: ['id'],
        params: (p) => {
          'id': p.id,
          'name': p.name,
          'age': p.age,
        },
      );
      final sql =
          patchDynamic.getSql((id: '1', name: const SQL(null), age: null));
      expect(sql, equals('UPDATE users SET name = @name WHERE id = @id'));
    });
  });

  group('InsertCommand', () {
    final insertUser = InsertCommand<({String id, String? name, int? age})>(
      table: 'users',
      params: (p) => {
        'id': p.id,
        'name': p.name,
        'age': p.age,
      },
    );

    test('generates SQL for full insert', () {
      final sql = insertUser.getSql((id: '1', name: 'Alec', age: 30));
      expect(
          sql,
          equals(
              'INSERT INTO users (id, name, age) VALUES (@id, @name, @age)'));
    });

    test('generates SQL for partial insert', () {
      final sql = insertUser.getSql((id: '1', name: 'Alec', age: null));
      expect(sql, equals('INSERT INTO users (id, name) VALUES (@id, @name)'));
    });

    test('generates SQL for explicit null insert (SQL wrapper)', () {
      final insertDynamic =
          InsertCommand<({String id, dynamic name, dynamic age})>(
        table: 'users',
        params: (p) => {
          'id': p.id,
          'name': p.name,
          'age': p.age,
        },
      );
      final sql =
          insertDynamic.getSql((id: '1', name: const SQL(null), age: null));
      expect(sql, equals('INSERT INTO users (id, name) VALUES (@id, @name)'));
    });

    test('throws if no values are provided', () {
      final sqlThrows = InsertCommand<({String? id})>(
        table: 'users',
        params: (p) => {'id': p.id},
      );
      expect(() => sqlThrows.getSql((id: null)), throwsArgumentError);
    });
  });

  group('Command (Legacy/Static)', () {
    test('works with static SQL', () {
      final cmd = Command<({String id})>(
        'DELETE FROM users WHERE id = @id',
        params: (p) => {'id': p.id},
      );
      expect(cmd.getSql((id: '1')), equals('DELETE FROM users WHERE id = @id'));
    });

    test('works with Command.static', () {
      final cmd = Command.static('SELECT 1');
      expect(cmd.getSql(null), equals('SELECT 1'));
    });

    test('works with map literal params', () {
      final cmd = Command<void>(
        'UPDATE users SET name = @name',
        params: {'name': 'Alec'},
      );
      final (sql, map) = cmd.apply(null);
      expect(sql, equals('UPDATE users SET name = @name'));
      expect(map, equals({'name': 'Alec'}));
    });
  });

  group('Query', () {
    test('works with map literal params', () {
      final query = Query<void, Record>(
        'SELECT * FROM users WHERE id = @id',
        params: {'id': '123'},
        schema: {},
      );
      final (sql, map) = query.apply(null);
      expect(sql, equals('SELECT * FROM users WHERE id = @id'));
      expect(map, equals({'id': '123'}));
    });
  });
}
