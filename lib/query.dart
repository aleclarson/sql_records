/// Maps a Record/Class to a SQLite named parameter map.
typedef ParamMapper<P> = Map<String, Object?> Function(P params);

/// Best-effort schema definition using Dart's Type objects (e.g., int, String).
typedef ResultSchema = Map<String, Type>;

/// [P] defines the input Parameter type.
/// [R] defines the expected output Record type (serves as a token for custom linting).
class Query<P, R extends Record> {
  final String sql;
  final ResultSchema schema;
  final ParamMapper<P>? params;

  const Query(
    this.sql, {
    required this.schema,
    this.params,
  });

  /// Factory for parameterless queries.
  static Query<void, R> empty<R extends Record>(
    String sql, {
    required ResultSchema schema,
  }) {
    return Query<void, R>(sql, schema: schema);
  }
}

/// A command that mutates data (INSERT, UPDATE, DELETE).
class Command<P> {
  final String sql;
  final ParamMapper<P>? params;

  const Command(this.sql, {this.params});

  /// Factory for parameterless mutations.
  static Command<void> empty(String sql) => Command<void>(sql);
}
