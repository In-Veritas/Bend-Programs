# Belote: Bend3 behavior notes

Retested with upstream Bend3 revision
`1ebc1acc739b565ddbf4dd243edf57ef10b65ebb` on 2026-08-17.

No compiler or runtime source was changed for Belote. The standalone program,
the hub-private generated module, and the unified BendJogos entry all pass the
current checker and native compiler. The pure deal/ranking probe returns `1`,
the browser regression test passes, and the HTTP test completes a full hand.

## Completed-hand state after the HTTP smoke test

The first full-hand regression client originally left the shared in-memory
table at phase 3. Opening Belote immediately afterward therefore displayed the
correct but confusing “Hand complete / Contract failed” result from the test
hand. This was a test-harness state leak, not an automatic deal failure. The
client now calls `/new` after its assertions, and the page has an
always-available **New random match** control. `/new` obtains its seed from
Bend3 `IO.rand_word`; two native-server resets produced distinct seeds and both
stopped at a playable human bidding decision.

The original action handlers also reduced every AI turn in the same HTTP
request. That was correct state evolution but made opponents appear to play
instantaneously and erased a completed trick before the browser could display
its intermediate cards. AI bidding and play now use a one-transition `/auto`
route; the browser requests it at 650 ms intervals. A native HTTP smoke test
completed all eight tricks with this stepwise protocol and reset the table
afterward.

## Numeric Boolean patterns

Conditions represented as `U32` must be matched with numeric patterns such as
`case 0:` and `case _:`. Constructor-looking patterns such as `case False:`
are not interchangeable with `U32` zero. This surfaced while writing the legal
card and automatic-turn state machines; it was an authoring mistake, not a
compiler defect.

## Generated module layout sensitivity

`generate_modules.mjs` prefixes every Belote declaration to prevent collisions
inside BendJogos's merged declaration book. The longer generated constructor
names exposed the parser's indentation/layout sensitivity in several dense
`match` rows: continuations that were visually adequate in the standalone
source could be interpreted differently after prefixing. The generator now
preserves deliberately wide continuation indentation, and both standalone and
generated forms are checked. Treat this as a source-layout hazard; no compiler
or runtime patch was made.
