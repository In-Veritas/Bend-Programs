# Club Corvid: Bend3 behavior

## Reproduction revisions

- Bend3 package version: `0.1.0`
- Historical compiler/base revision:
  `ffa2411e9e0bd1275150b07f627c3686a145632d`
- Club Corvid feature baseline: `760449bbba9ff8732eefe4e6854646d43075ccae`
- Current retest revision: `1ebc1acc739b565ddbf4dd243edf57ef10b65ebb`

No Bend3 compiler or runtime file was modified for this demo.

## Historical issue: the long-lived server cycle needed whole-book scoping

The HTTP response continuation calls the accept loop declared later in the
file. At the historical baseline, default checking reported that later
`u32_serve` definition as unbound. The unchanged source checked with
`--no-halt`, which enabled whole-book scoping as well as disabling the
termination proof.

The language behavior has one canonical isolated reproduction in
[`mre_mutual_scope.bend`](../../minecraft_web/unexpected_behavior/mre_mutual_scope.bend).
The standalone build records its required checking mode explicitly; no Bend
compiler workaround is embedded in the program.

At current revision `1ebc1acc`, later-definition scoping is fixed. The shared
MRE now records the remaining termination-checking behavior.
