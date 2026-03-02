# Open Questions / Intent Gaps

Status: decisions recorded. Any item marked with a decision that differs from current implementation is a follow-up implementation task.

1. **Identifier quoting policy**
   - Dynamic commands interpolate table/column identifiers directly.
   - No quoting/escaping policy is defined for reserved words or unusual identifiers.

   DECISION: Identifier interpolation is not supported (for now).

2. **Schema strictness model evolution**
   - Current type checks require exact `Type` matches from schema declarations.
   - No documented policy for safe coercions (e.g., `int` to `num`).

   DECISION: Keep as is for now.

3. **Batch execution guarantees**
   - Ordering and atomicity are engine-dependent and not explicitly committed as API guarantees.

   DECISION: Ordering and atomicity are engine-dependent and not explicitly committed as API guarantees.

4. **Transaction isolation semantics**
   - Adapter behavior delegates to underlying engines; isolation level controls are not exposed.

   DECISION: Transaction isolation is not supported (for now).

5. **Result field naming in Postgres**
   - Matching is based on returned column names; no normalization policy (case/aliases) is documented.

   DECISION: casing is never normalized.

6. **`SQL(value)` behavior for non-null literal embedding**
   - Current dynamic command implementations treat `SQL(_)` as literal `NULL` only.
   - If arbitrary raw SQL embedding is desired, a new explicit API should be designed.

   DECISION: Switch to `SQL.null()` to be more explicit about what is supported.

7. **`R extends Record` ergonomics**
   - `R` is currently a linting/token aid only.
   - Dot-property row access is not provided.

   DECISION: Keep as is for now.
