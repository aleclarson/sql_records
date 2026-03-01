import 'package:sql_records/powersync.dart';
import 'package:test/test.dart';

void main() {
  group('README Examples', () {
    test('Standard Queries (READ) - Query.static', () {
      // Parameterless queries
      final allUsersQuery = Query<void, ({String name, int age})>.static(
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
      expect(sql, equals('DELETE FROM users WHERE id = @id'));
      expect(params, equals({'id': '123'}));
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

      final (sql, params) = insertAndReturn.apply((id: '123', name: 'New User'));
      expect(
          sql,
          equals(
              'INSERT INTO users (id, name) VALUES (@id, @name) RETURNING id, name'));
      expect(params, equals({'id': '123', 'name': 'New User'}));
    });

    test('Static commands for parameterless SQL', () {
      final deleteAll = Command.static('DELETE FROM users');
      final (sql, params) = deleteAll.apply(null);
      expect(sql, equals('DELETE FROM users'));
      expect(params, isEmpty);
    });
  });
}
