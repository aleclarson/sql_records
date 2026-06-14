import 'package:meta/meta.dart';
import 'query.dart';

@internal
Map<String, Object?>? resolveParams<P>(dynamic params, P? p) {
  if (params == null) return null;
  if (params is Map<String, Object?>) return params;
  if (params is Function) return (params as ParamMapper<P>)(p as P);
  throw ArgumentError(
    'Parameter Error: params must be a Map<String, Object?> or a ParamMapper<P>.',
  );
}

@internal
(String, List<Object?>) translateSql(String sql, Map<String, Object?> map) {
  final List<Object?> args = [];
  final buffer = StringBuffer();
  var index = 0;

  while (index < sql.length) {
    final char = sql[index];

    if (char == "'" || char == '"' || char == '`') {
      index = _copyQuoted(sql, index, buffer, char);
      continue;
    }

    if (char == '[') {
      index = _copyBracketIdentifier(sql, index, buffer);
      continue;
    }

    if (_startsLineComment(sql, index)) {
      index = _copyLineComment(sql, index, buffer);
      continue;
    }

    if (_startsBlockComment(sql, index)) {
      index = _copyBlockComment(sql, index, buffer);
      continue;
    }

    if (char == '@') {
      final start = index + 1;
      var end = start;

      while (end < sql.length && _isParameterChar(sql.codeUnitAt(end))) {
        end++;
      }

      if (end > start) {
        final name = sql.substring(start, end);
        if (!map.containsKey(name)) {
          throw ArgumentError(
            'Parameter Error: Missing parameter "@$name". Ensure it is provided in the params map or mapper.',
          );
        }

        final value = map[name];
        args.add(value is SQL ? null : value);
        buffer.write('?');
        index = end;
        continue;
      }
    }

    buffer.write(char);
    index++;
  }

  return (buffer.toString(), args);
}

@internal
(String, List<Object?>) prepareSql<P>(String sql, dynamic mapper, P? params) {
  final map = resolveParams(mapper, params);
  if (map == null) return (sql, const []);
  return translateSql(sql, map);
}

bool _startsLineComment(String sql, int index) =>
    sql[index] == '-' && index + 1 < sql.length && sql[index + 1] == '-';

bool _startsBlockComment(String sql, int index) =>
    sql[index] == '/' && index + 1 < sql.length && sql[index + 1] == '*';

int _copyQuoted(String sql, int start, StringBuffer buffer, String delimiter) {
  buffer.write(delimiter);
  var index = start + 1;

  while (index < sql.length) {
    final char = sql[index];
    buffer.write(char);
    index++;

    if (char == delimiter) {
      if (index < sql.length && sql[index] == delimiter) {
        buffer.write(sql[index]);
        index++;
        continue;
      }
      break;
    }
  }

  return index;
}

int _copyBracketIdentifier(String sql, int start, StringBuffer buffer) {
  buffer.write('[');
  var index = start + 1;

  while (index < sql.length) {
    final char = sql[index];
    buffer.write(char);
    index++;

    if (char == ']') {
      if (index < sql.length && sql[index] == ']') {
        buffer.write(sql[index]);
        index++;
        continue;
      }
      break;
    }
  }

  return index;
}

int _copyLineComment(String sql, int start, StringBuffer buffer) {
  buffer.write('--');
  var index = start + 2;

  while (index < sql.length) {
    final char = sql[index];
    buffer.write(char);
    index++;
    if (char == '\n') break;
  }

  return index;
}

int _copyBlockComment(String sql, int start, StringBuffer buffer) {
  buffer.write('/*');
  var index = start + 2;

  while (index < sql.length) {
    final char = sql[index];
    buffer.write(char);
    index++;
    if (char == '*' && index < sql.length && sql[index] == '/') {
      buffer.write('/');
      index++;
      break;
    }
  }

  return index;
}

bool _isParameterChar(int charCode) {
  return (charCode >= 48 && charCode <= 57) ||
      (charCode >= 65 && charCode <= 90) ||
      (charCode >= 97 && charCode <= 122) ||
      charCode == 95;
}
