# sql_records Roadmap

Status: Proposed implementation roadmap derived from current specs and code (`v0.7.0`).

Prioritization principle used here:

- Highest user safety/clarity impact first
- Prefer low-effort, high-confidence changes early
- Defer larger API or architectural work until behavior is well-documented and tested

---

## P0 — High impact / low effort (do first)

## 1) Tighten docs around identifier safety and naming behavior

**Why**
- Specs now explicitly state no identifier quoting/interpolation support and exact Postgres field-name matching.
- These are easy-to-miss footguns.

**Work**
- Add explicit “unsafe if user input is used for identifiers” warning in README dynamic-command sections.
- Add short examples of safe aliasing for Postgres (`SELECT created_at AS createdAt ...`).

**Effort**: Low  
**Risk**: Low  
**Value**: High

## 2) Add focused tests for documented edge behavior

**Why**
- Some behavior is specified but under-tested.

**Work**
- Add tests for Postgres row key case-sensitivity assumptions (adapter-level unit tests if feasible).
- Add tests for missing named parameters in SQL translation (`translateSql`).
- Add tests ensuring `SQL.NULL` is treated as null binding where relevant and as literal `NULL` in dynamic commands.

**Effort**: Low–Medium  
**Risk**: Low  
**Value**: High

## 3) Clarify transaction caveats by engine in public docs

**Why**
- `readTransaction` semantics differ across engines (especially sqlite3).

**Work**
- Add a small matrix in README: write/read transaction behavior for PowerSync, sqlite3, Postgres.

**Effort**: Low  
**Risk**: Low  
**Value**: Medium–High

---

## P1 — Medium impact / low-medium effort

## 4) Add optional lightweight runtime guard for dynamic identifiers

**Why**
- While identifier interpolation remains unsupported, accidental invalid identifiers are possible.

**Work**
- Add optional assert/validation path for `table`, `primaryKeys`, and mapped keys (e.g., regex-based identifier sanity check).
- Keep default behavior backward-compatible in release mode.

**Effort**: Medium  
**Risk**: Low–Medium  
**Value**: Medium

## 5) Strengthen error message consistency

**Why**
- Current errors are informative but not standardized across all paths.

**Work**
- Normalize error prefixes/category language (`Schema Error`, `DB Type Mismatch`, etc.).
- Ensure all command/query param-shape failures provide remediation hints.

**Effort**: Medium  
**Risk**: Low  
**Value**: Medium

## 6) Add dialect behavior conformance tests

**Why**
- Core contract is cross-engine consistency with explicit exceptions.

**Work**
- Create a shared contract-style test suite for:
  - `get/getAll/getOptional`
  - `execute/executeBatch`
  - no-op command behavior
  - `returning` SQL generation
- Run against sqlite adapter directly; mock/targeted tests for others where infra is hard.

**Effort**: Medium  
**Risk**: Medium  
**Value**: High

---

## P2 — Medium-high impact / medium effort

## 7) Revisit `ResultSchema` strictness ergonomics

**Why**
- Exact type matching is safe but can be rigid (`int` vs `num`, driver-specific representations).

**Work**
- Explore opt-in relaxed mode or helper APIs without weakening default strict mode.
- If introduced, keep strict mode default and document tradeoffs.

**Effort**: Medium  
**Risk**: Medium  
**Value**: Medium–High

## 8) Improve Postgres column lookup performance path (if needed)

**Why**
- Current lookup iterates columns for each key access.

**Work**
- Cache name→index mapping per `PostgresRow` instance.
- Benchmark before/after to confirm value.

**Effort**: Medium  
**Risk**: Low  
**Value**: Medium (workload-dependent)

---

## P3 — Strategic / larger scope (defer)

## 9) Expose explicit transaction options (if demanded)

**Why**
- Isolation level controls are currently out of scope by spec.

**Work**
- Design cross-engine API for transaction options with graceful no-op/unsupported behavior.
- Requires deliberate API design and docs.

**Effort**: High  
**Risk**: Medium–High  
**Value**: Scenario-dependent

## 10) Revisit `R extends Record` ergonomics

**Why**
- `R` remains primarily token/linting guidance.

**Work**
- Investigate tooling/lints or generated helpers for stronger typed access without runtime reflection complexity.

**Effort**: High  
**Risk**: Medium  
**Value**: Medium

---

## Suggested execution order (next 3 PRs)

1. **Docs hardening PR**: identifier safety + engine transaction matrix + Postgres key casing notes.
2. **Edge behavior tests PR**: missing params, `SQL.NULL`, no-op, key casing assumptions.
3. **Error consistency PR**: standardize messages and update tests accordingly.
