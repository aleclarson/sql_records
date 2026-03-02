import 'package:meta/meta.dart';
import 'query.dart';

@internal
Map<String, Object?>? resolveParams<P>(dynamic params, P? p) {
  if (params == null) return null;
  if (params is Map<String, Object?>) return params;
  if (params is Function) return (params as ParamMapper<P>)(p as P);
  return null;
}

@internal
(String, List<Object?>) translateSql(String sql, Map<String, Object?> map) {
  final List<Object?> args = [];
  final pattern = RegExp(r'@([a-zA-Z0-9_]+)');

  final translatedSql = sql.replaceAllMapped(pattern, (match) {
    final name = match.group(1)!;
    if (!map.containsKey(name)) {
      throw ArgumentError(
        'Parameter Error: Missing parameter "@$name". Ensure it is provided in the params map or mapper.',
      );
    }

    final value = map[name];
    args.add(value is SQL ? null : value);
    return '?';
  });

  return (translatedSql, args);
}

@internal
(String, List<Object?>) prepareSql<P>(String sql, dynamic mapper, P? params) {
  final map = resolveParams(mapper, params);
  if (map == null) return (sql, const []);
  return translateSql(sql, map);
}
