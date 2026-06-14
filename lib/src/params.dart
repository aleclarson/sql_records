/// Maps a Record/Class to a named parameter map.
typedef ParamMapper<P> = Map<String, Object?> Function(P params);

Map<String, Object?>? resolveOptionalParams<P>(dynamic params, P? p) {
  if (params == null) return null;
  if (params is Map<String, Object?>) return params;
  if (params is Function) return (params as ParamMapper<P>)(p as P);
  throw ArgumentError(
    'Parameter Error: params must be a Map<String, Object?> or a ParamMapper<P>.',
  );
}
