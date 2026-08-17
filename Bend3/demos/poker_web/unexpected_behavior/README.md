# Poker: Bend3 behavior notes

- The Bend parser requires explicit parentheses for mixed/chained binary
  expressions. The evaluator uses named intermediate values instead of relying
  on precedence.
- Polymorphic list helpers require their type argument at calls where inference
  cannot recover it, for example `List.concat(U32, hole, board)`.
- A constructor assigned to a local and immediately passed to another function
  sometimes needs an explicit `: Game` annotation.
- Browser invite tokens are numeric because URL routing and equality stay much
  simpler and more predictable in Bend than arbitrary String-token handling.
- Side pots are not implemented. Short all-in calls work and stay eligible at
  showdown, but an unequal multi-way all-in is resolved as a single pot. This
  is a documented game limitation, not a compiler defect.
- Hub-private namespacing lengthens declaration and call names. The generated
  form therefore needs deliberately wide continuation indentation for an
  inline `match` in `game_new`; otherwise its case rows are no longer deeper
  than the rewritten match expression. Standalone and generated forms are both
  checked. No compiler/runtime change was made.
