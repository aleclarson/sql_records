# Open Questions / Intent Gaps

The following areas are not fully specified by current code/tests and may require product decisions:

1. **Identifier quoting policy**
   - Dynamic commands interpolate table/column identifiers directly.
   - No quoting/escaping policy is defined for reserved words or unusual identifiers.

2. **Schema strictness model evolution**
   - Current type checks require exact `Type` matches from schema declarations.
   - No documented policy for safe coercions (e.g., `int` to `num`).

3. **Batch execution guarantees**
   - Ordering and atomicity are engine-dependent and not explicitly committed as API guarantees.

4. **Transaction isolation semantics**
   - Adapter behavior delegates to underlying engines; isolation level controls are not exposed.

5. **Result field naming in Postgres**
   - Matching is based on returned column names; no normalization policy (case/aliases) is documented.

6. **`SQL(value)` behavior for non-null literal embedding**
   - Current dynamic command implementations treat `SQL(_)` as literal `NULL` only.
   - If arbitrary raw SQL embedding is desired, a new explicit API should be designed.

7. **`R extends Record` ergonomics**
   - `R` is currently a linting/token aid only.
   - Dot-property row access is not provided.
