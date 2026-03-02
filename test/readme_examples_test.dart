import 'package:sql_records/powersync.dart';
import 'package:test/test.dart';

void main() {
  group('README Examples', () {
    test('Standard Queries (READ) - Query.static', () {
      // Parameterless queries
      final allUsersQuery = Query.static<({String name, int age})>(
        'SELECT name, age FROM users',
        schema: {'name': String, 'age': int},
      );

      final (sql, params) = allUsersQuery.apply(null);
      expect(sql, equals('SELECT name, age FROM users'));
      expect(params, isEmpty);
    });

    test('Dynamic Commands - DeleteCommand', () {
      // DeleteCommand dynamically builds a WHERE clause by primary key.
      final deleteUser = DeleteCommand<({String id})>(
        table: 'users',
        primaryKeys: ['id'],
        params: (p) => {'id': p.id},
      );

      final (sql, params) = deleteUser.apply((id: '123'));
      expect(sql, equals('DELETE FROM "users" WHERE "id" = @p0'));
      expect(params, equals({'p0': '123'}));
    });

    test('RETURNING Clauses', () {
      final insertUser = InsertCommand<({String id, String? name})>(
        table: 'users',
        params: (p) => {'id': p.id, 'name': p.name},
      );

      final insertAndReturn = insertUser.returning<({int id, String name})>({
        'id': int,
        'name': String,
      });

      final (sql, params) =
          insertAndReturn.apply((id: '123', name: 'New User'));
      expect(
        sql,
        equals(
            'INSERT INTO "users" ("id", "name") VALUES (@p0, @p1) RETURNING "id", "name"'),
      );
      expect(params, equals({'p0': '123', 'p1': 'New User'}));
    });

    test('Static commands for parameterless SQL', () {
      final deleteAll = Command.static('DELETE FROM users');
      final (sql, params) = deleteAll.apply(null);
      expect(sql, equals('DELETE FROM users'));
      expect(params, isEmpty);
    });

    test('Map Literal Parameters (Inline)', () {
      // Inline Query
      final query = Query(
        'SELECT name FROM users WHERE id = @id',
        params: {'id': '123'},
        schema: {'name': String},
      );
      final (qSql, qParams) = query.apply(null);
      expect(qSql, equals('SELECT name FROM users WHERE id = @id'));
      expect(qParams, equals({'id': '123'}));

      // Inline Command
      final command = Command(
        'UPDATE users SET status = @status WHERE id = @id',
        params: {'id': '123', 'status': 'active'},
      );
      final (cSql, cParams) = command.apply(null);
      expect(cSql, equals('UPDATE users SET status = @status WHERE id = @id'));
      expect(cParams, equals({'id': '123', 'status': 'active'}));

      // Inline RETURNING Query
      final returning = Command(
        'UPDATE users SET status = @status WHERE id = @id',
        params: {'id': '123', 'status': 'active'},
      ).returning<({String status})>({'status': String});
      final (rSql, rParams) = returning.apply(null);
      expect(
        rSql,
        equals(
            'UPDATE users SET status = @status WHERE id = @id RETURNING "status"'),
      );
      expect(rParams, equals({'id': '123', 'status': 'active'}));
    });
  });
}
