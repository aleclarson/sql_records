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
      final (sql, _) = patchUser.apply((id: '1', name: null, age: null));
      expect(sql, equals(NoOpCommand));
    });

    test('throws if primary key is missing', () {
      final invalidPatch = UpdateCommand<({String? name})>(
        table: 'users',
        primaryKeys: [],
        params: (p) => {'name': p.name},
      );
      expect(() => invalidPatch.getSql((name: 'Alec')), throwsArgumentError);
    });

    test('throws on invalid identifier', () {
      final invalidPatch = UpdateCommand<({String id, String? name})>(
        table: 'users;drop',
        primaryKeys: ['id'],
        params: (p) => {'id': p.id, 'name': p.name},
      );

      expect(
        () => invalidPatch.getSql((id: '1', name: 'Alec')),
        throwsArgumentError,
      );
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
      final (sql, map) =
          patchDynamic.apply((id: '1', name: SQL.NULL, age: null));
      expect(sql, equals('UPDATE users SET name = NULL WHERE id = @id'));
      expect(map, equals({'id': '1'}));
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
      final (sql, map) =
          insertDynamic.apply((id: '1', name: SQL.NULL, age: null));
      expect(sql, equals('INSERT INTO users (id, name) VALUES (@id, NULL)'));
      expect(map, equals({'id': '1'}));
    });

    test('generates DEFAULT VALUES SQL when no values are provided', () {
      final insertOptional = InsertCommand<({String? id, String? name})>(
        table: 'users',
        params: (p) => {'id': p.id, 'name': p.name},
      );
      final (sql, _) = insertOptional.apply((id: null, name: null));
      expect(sql, equals('INSERT INTO users DEFAULT VALUES'));
    });

    test('generates SQL with RETURNING clause', () {
      final insertReturning = InsertCommand<({String id, String name})>(
        table: 'users',
        params: (p) => {'id': p.id, 'name': p.name},
      ).returning({'id': String, 'created_at': int});

      final (sql, _) = insertReturning.apply((id: '1', name: 'Alec'));
      expect(
          sql,
          equals(
              'INSERT INTO users (id, name) VALUES (@id, @name) RETURNING id, created_at'));
    });
  });

  group('DeleteCommand', () {
    final deleteUser = DeleteCommand<({String id})>(
      table: 'users',
      primaryKeys: ['id'],
      params: (p) => {'id': p.id},
    );

    test('generates SQL for delete', () {
      final sql = deleteUser.getSql((id: '1'));
      expect(sql, equals('DELETE FROM users WHERE id = @id'));
    });

    test('generates SQL with RETURNING clause', () {
      final deleteReturning = DeleteCommand<({String id})>(
        table: 'users',
        primaryKeys: ['id'],
        params: (p) => {'id': p.id},
      ).returning({'id': String});

      final (sql, _) = deleteReturning.apply((id: '1'));
      expect(sql, equals('DELETE FROM users WHERE id = @id RETURNING id'));
    });
  });

  group('UpdateCommand RETURNING', () {
    test('generates SQL with RETURNING clause', () {
      final patchReturning = UpdateCommand<({String id, String? name})>(
        table: 'users',
        primaryKeys: ['id'],
        params: (p) => {'id': p.id, 'name': p.name},
      ).returning({'id': String, 'name': String});

      final (sql, _) = patchReturning.apply((id: '1', name: 'Alec'));
      expect(
          sql,
          equals(
              'UPDATE users SET name = @name WHERE id = @id RETURNING id, name'));
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

    test('infers RETURNING columns from schema when using .returning()', () {
      final insertReturning = InsertCommand<({String id, String name})>(
        table: 'users',
        params: (p) => {'id': p.id, 'name': p.name},
      ).returning({'id': String, 'name': String});

      final (sql, _) = insertReturning.apply((id: '1', name: 'Alec'));
      expect(
          sql,
          equals(
              'INSERT INTO users (id, name) VALUES (@id, @name) RETURNING id, name'));
    });

    test('throws for invalid RETURNING identifier', () {
      final insertReturning = InsertCommand<({String id})>(
        table: 'users',
        params: (p) => {'id': p.id},
      ).returning({'bad-column': String});

      expect(
        () => insertReturning.apply((id: '1')),
        throwsArgumentError,
      );
    });
  });
}
