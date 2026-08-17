# Poker: Bend3 behavior notes

- The Bend parser requires explicit parentheses for mixed/chained binary
  expressions. The evaluator uses named intermediate values instead of relying
  on precedence.
- Polymorphic list helpers require their type argument at calls where inference
  cannot recover it, for example `List.concat(U32, hole, board)`.
- A constructor assigned to a local and immediately passed to another function
  sometimes needs an explicit `: Game` annotation.
- Hub-private namespacing lengthens declaration and call names. The generated
  form therefore needs deliberately wide continuation indentation for an
  inline `match` in `game_new`; otherwise its case rows are no longer deeper
  than the rewritten match expression. Standalone and generated forms are both
  checked. No compiler/runtime change was made.
