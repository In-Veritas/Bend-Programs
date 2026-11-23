# Experimental pure-numeric port of the LZ-ANI scoring kernel.
#
# This is deliberately separate from the production clustering score.  It uses
# the default LZ-ANI geometry (11-base anchors, 7-base close seeds, 40-base
# query/reference distance, and 35-base accepted regions), but discovers
# anchors by exhaustive suffix scanning. Gap splitting and rolling-window
# approximate extension follow the numeric upstream rules. That makes this a
# small deterministic oracle for differential validation before the indexed
# parser is ported.
import Base
import ./lz_ani_choice.bend as Choice

type Bases is Data:
  BasesNil{}
  BasesCon{head: U32, tail: Bases}

type Anchor is Data:
  Anchor{position: U32, length: U32, close: Bool}

type Counts is Data:
  Counts{matches: U32, mismatches: U32, components: U32}

type Metrics is Data:
  Metrics{matches: U32, mismatches: U32, components: U32,
    ani: U32, gani: U32, coverage: U32}

type Extension is Data:
  Extension{length: U32, matches: U32, mismatches: U32}

def choose(-A: Type, condition: Bool, branches: Bool -> A) -> A:
  branches(condition)

def apply(-A: Type, -B: Type, body: A -> B, value: A) -> B:
  body(value)

def minimum(+left: U32, +right: U32) -> U32:
  choose(U32, U32.is_lt(left, right), \{True: left; False: right})

def distance(+left: U32, +right: U32) -> U32:
  choose(U32, U32.is_lt(left, right), \{
    True: U32.sub(right, left)
    False: U32.sub(left, right)
  })

def subtract(+left: U32, +right: U32) -> U32:
  choose(U32, U32.is_lt(left, right), \{
    True: 0
    False: U32.sub(left, right)
  })

def base_code(code: U32) -> U32:
  match code:
    case 65: 0
    case 97: 0
    case 67: 1
    case 99: 1
    case 71: 2
    case 103: 2
    case 84: 3
    case 116: 3
    case 85: 3
    case 117: 3
    case _: 4

law from_string:
  for text: String
  Bases

def from_string(text):
  match text:
    case SNil{}:
      BasesNil{}
    case SCon{Chr{code}, tail}:
      BasesCon{base_code(code), from_string(tail)}

law bases_length:
  for bases: Bases
  for +total: U32
  U32

def bases_length(bases, total):
  match bases:
    case BasesNil{}:
      total
    case BasesCon{head, tail}:
      bases_length(tail, U32.add(total, 1))

law bases_drop:
  for fuel: Nat
  for bases: Bases
  Bases

def bases_drop(fuel, bases):
  match fuel bases:
    case Zero{} remaining:
      remaining
    case Succ{rest} BasesNil{}:
      BasesNil{}
    case Succ{rest} BasesCon{head, tail}:
      bases_drop(rest, tail)

law bases_take:
  for fuel: Nat
  for bases: Bases
  Bases

def bases_take(fuel, bases):
  match fuel bases:
    case Zero{} remaining:
      BasesNil{}
    case Succ{rest} BasesNil{}:
      BasesNil{}
    case Succ{rest} BasesCon{head, tail}:
      BasesCon{head, bases_take(rest, tail)}

law bases_sum:
  for bases: Bases
  for +total: U32
  U32

def bases_sum(bases, total):
  match bases:
    case BasesNil{}:
      total
    case BasesCon{head, tail}:
      bases_sum(tail, U32.add(total, head))

law bases_append:
  for left: Bases
  for right: Bases
  Bases

def bases_append(left, right):
  match left:
    case BasesNil{}:
      right
    case BasesCon{head, tail}:
      BasesCon{head, bases_append(tail, right)}

law bases_repeat:
  for fuel: Nat
  for +base: U32
  Bases

def bases_repeat(fuel, base):
  match fuel:
    case Zero{}:
      BasesNil{}
    case Succ{rest}:
      BasesCon{base, bases_repeat(rest, base)}

def complement(base: U32) -> U32:
  match base:
    case 0: 3
    case 1: 2
    case 2: 1
    case 3: 0
    case _: 4

law reverse_complement_loop:
  for bases: Bases
  for result: Bases
  Bases

def reverse_complement_loop(bases, result):
  match bases:
    case BasesNil{}:
      result
    case BasesCon{head, tail}:
      reverse_complement_loop(tail, BasesCon{complement(head), result})

law reverse_complement:
  for bases: Bases
  Bases

def reverse_complement(bases):
  reverse_complement_loop(bases, BasesNil{})

law bases_reverse_loop:
  for bases: Bases
  for result: Bases
  Bases

def bases_reverse_loop(bases, result):
  match bases:
    case BasesNil{}:
      result
    case BasesCon{head, tail}:
      bases_reverse_loop(tail, BasesCon{head, result})

law bases_reverse:
  for bases: Bases
  Bases

def bases_reverse(bases):
  bases_reverse_loop(bases, BasesNil{})

# The reference layout mirrors LZ-ANI: forward, 80 sentinels, reverse
# complement, then 40 sentinels. Sentinels cannot seed a nucleotide match.
law reference_space:
  for +reference: Bases
  Bases

def reference_space(reference):
  bases_append(reference,
    bases_append(bases_repeat(80n, 4),
      bases_append(reverse_complement(reference), bases_repeat(40n, 4))))

law equal_prefix:
  for left: Bases
  for right: Bases
  for +total: U32
  U32

def equal_prefix(left, right, total):
  match left right:
    case BasesNil{} remaining:
      total
    case BasesCon{head, tail} BasesNil{}:
      total
    case BasesCon{+left_head, left_tail} BasesCon{+right_head, right_tail}:
      choose(U32, U32.is_eq(left_head, right_head) && U32.is_lt(left_head, 4), \{
        True: equal_prefix(left_tail, right_tail, U32.add(total, 1))
        False: total
      })

law count_equal:
  for fuel: Nat
  for left: Bases
  for right: Bases
  for +total: U32
  U32

def count_equal(fuel, left, right, total):
  match fuel left right:
    case Zero{} left_remaining right_remaining:
      total
    case Succ{rest} BasesNil{} right_remaining:
      total
    case Succ{rest} BasesCon{head, tail} BasesNil{}:
      total
    case Succ{rest} BasesCon{+left_head, left_tail} BasesCon{+right_head, right_tail}:
      count_equal(rest, left_tail, right_tail,
        U32.add(total, choose(U32,
          U32.is_eq(left_head, right_head) && U32.is_lt(left_head, 4),
          \{True: 1; False: 0})))

# Score one possible split of the pending query gap. Its left prefix is
# compared immediately after the previous factor; its right suffix is compared
# immediately before the end of the new factor. This mirrors LZ-ANI's
# simplified two-sided indel handling, including possible reuse at a boundary.
law gap_split_matches:
  for +reference: Bases
  for +gap: Bases
  for +predicted: U32
  for +anchor_end: U32
  for +gap_length: U32
  for +split: U32
  U32

def gap_split_matches(reference, gap, predicted, anchor_end, gap_length, split):
  +right_length = {U32.sub(gap_length, split) : U32}
  +left_matches = {count_equal(U32.to_nat(split),
    bases_drop(U32.to_nat(subtract(predicted, gap_length)), reference),
    gap, 0) : U32}
  +right_matches = {count_equal(U32.to_nat(right_length),
    bases_drop(U32.to_nat(subtract(anchor_end, right_length)), reference),
    bases_drop(U32.to_nat(split), gap), 0) : U32}
  U32.add(left_matches, right_matches)

law best_gap_loop:
  for fuel: Nat
  for +reference: Bases
  for +gap: Bases
  for +predicted: U32
  for +anchor_end: U32
  for +gap_length: U32
  for +split: U32
  for +best: U32
  U32

def best_gap_loop(fuel, reference, gap, predicted, anchor_end, gap_length,
                  split, best):
  match fuel:
    case Zero{}:
      best
    case Succ{rest}:
      +candidate = {gap_split_matches(reference, gap, predicted, anchor_end,
        gap_length, split) : U32}
      best_gap_loop(rest, reference, gap, predicted, anchor_end, gap_length,
        U32.add(split, 1),
        choose(U32, U32.is_gt(candidate, best),
          \{True: candidate; False: best}))

law best_gap_matches:
  for reference: Bases
  for gap: Bases
  for +predicted: U32
  for +anchor_end: U32
  for +gap_length: U32
  U32

def best_gap_matches(reference, gap, predicted, anchor_end, gap_length):
  best_gap_loop(Succ{U32.to_nat(gap_length)}, reference, gap, predicted,
    anchor_end, gap_length, 0, 0)

# LZ-ANI extends each exact factor in lockstep while a rolling 15-base window
# contains at most seven mismatches. Only the prefix ending in a run of at
# least three matches is committed. The list-based window is intentionally an
# oracle implementation; the indexed production port can replace it later.
law extension_loop:
  for fuel: Nat
  for reference: Bases
  for query: Bases
  for window: Bases
  for +length: U32
  for +run: U32
  for +matches: U32
  for +mismatches: U32
  for +good_length: U32
  for +good_matches: U32
  for +good_mismatches: U32
  Extension

def extension_loop(fuel, reference, query, window, length, run, matches,
                   mismatches, good_length, good_matches, good_mismatches):
  match fuel reference query:
    case Zero{} reference_remaining query_remaining:
      Extension{good_length, good_matches, good_mismatches}
    case Succ{rest} BasesNil{} query_remaining:
      Extension{good_length, good_matches, good_mismatches}
    case Succ{rest} BasesCon{ref_head, ref_tail} BasesNil{}:
      Extension{good_length, good_matches, good_mismatches}
    case Succ{rest} BasesCon{+ref_head, ref_tail} BasesCon{+query_head, query_tail}:
      +is_match = {U32.is_eq(ref_head, query_head) && U32.is_lt(ref_head, 4) : Bool}
      +flag = {choose(U32, is_match, \{True: 0; False: 1}) : U32}
      +next_window = {bases_take(15n, BasesCon{flag, window}) : Bases}
      +next_length = {U32.add(length, 1) : U32}
      +next_run = {choose(U32, is_match,
        \{True: U32.add(run, 1); False: 0}) : U32}
      +next_matches = {U32.add(matches,
        choose(U32, is_match, \{True: 1; False: 0})) : U32}
      +next_mismatches = {U32.add(mismatches, flag) : U32}
      choose(Extension, U32.is_gt(bases_sum(next_window, 0), 7), \{
        True: Extension{good_length, good_matches, good_mismatches}
        False: choose(Extension, U32.is_ge(next_run, 3), \{
          True: extension_loop(rest, ref_tail, query_tail, next_window,
            next_length, next_run, next_matches, next_mismatches,
            next_length, next_matches, next_mismatches)
          False: extension_loop(rest, ref_tail, query_tail, next_window,
            next_length, next_run, next_matches, next_mismatches,
            good_length, good_matches, good_mismatches)
        })
      })

law approximate_extension:
  for reference: Bases
  for +query: Bases
  Extension

def approximate_extension(reference, query):
  extension_loop(U32.to_nat(bases_length(query, 0)), reference, query,
    BasesNil{}, 0, 3, 0, 0, 0, 0, 0)

def longer_anchor(candidate: Anchor, best: Anchor) -> Anchor:
  match candidate best:
    case Anchor{candidate_position, +candidate_length, candidate_close} Anchor{best_position, +best_length, best_close}:
      choose(Anchor, U32.is_gt(candidate_length, best_length), \{
        True: Anchor{candidate_position, candidate_length, candidate_close}
        False: Anchor{best_position, best_length, best_close}
      })

law longest_anchor_loop:
  for +reference: Bases
  for +query: Bases
  for +position: U32
  for best: Anchor
  Anchor

def longest_anchor_loop(reference, query, position, best):
  match reference:
    case BasesNil{}:
      best
    case BasesCon{+head, +tail}:
      +length = {equal_prefix(BasesCon{head, tail}, query, 0) : U32}
      next = longer_anchor(Anchor{position, length, False{}}, best)
      longest_anchor_loop(tail, query, U32.add(position, 1), next)

law longest_anchor:
  for reference: Bases
  for query: Bases
  Anchor

def longest_anchor(reference, query):
  longest_anchor_loop(reference, query, 0, Anchor{0, 0, False{}})

def better_close(candidate: Anchor, best: Anchor, +predicted: U32) -> Anchor:
  match candidate best:
    case Anchor{+candidate_position, +candidate_length, candidate_close} Anchor{+best_position, +best_length, best_close}:
      +candidate_distance = {distance(candidate_position, predicted) : U32}
      +best_distance = {distance(best_position, predicted) : U32}
      choose(Anchor,
        U32.is_gt(candidate_length, best_length)
          || (U32.is_eq(candidate_length, best_length)
            && U32.is_lt(candidate_distance, best_distance)), \{
          True: Anchor{candidate_position, candidate_length, True{}}
          False: Anchor{best_position, best_length, best_close}
        })

law close_anchor_loop:
  for +reference: Bases
  for +query: Bases
  for +position: U32
  for +predicted: U32
  for +literal_run: U32
  for best: Anchor
  Anchor

def close_anchor_loop(reference, query, position, predicted, literal_run, best):
  match reference:
    case BasesNil{}:
      best
    case BasesCon{+head, +tail}:
      +length = {equal_prefix(BasesCon{head, tail}, query, 0) : U32}
      +eligible = {U32.is_ge(position, subtract(predicted, literal_run))
        && U32.is_lt(position, U32.add(predicted, 40))
        && U32.is_ge(length, 7) : Bool}
      next = choose(Anchor, eligible, \{
        True: better_close(Anchor{position, length, True{}}, best, predicted)
        False: best
      })
      close_anchor_loop(tail, query, U32.add(position, 1), predicted,
        literal_run, next)

law close_anchor:
  for reference: Bases
  for query: Bases
  for +predicted: U32
  for +literal_run: U32
  Anchor

def close_anchor(reference, query, predicted, literal_run):
  close_anchor_loop(reference, query, 0, predicted, literal_run,
    Anchor{0, 0, True{}})

# LZ-ANI compares an arbitrary >=11 anchor with a >=7 seed near the predicted
# reference position using the chance-probability comparison shared with the
# indexed implementation.
def select_predicted(long: Anchor, close: Anchor, +reference_length: U32,
                     +literal_run: U32) -> Anchor:
  match long close:
    case Anchor{+long_position, +long_length, long_close}
         Anchor{close_position, +close_length, close_flag}:
      +has_long = {U32.is_ne(long_position, 0)
        && U32.is_ge(long_length, 11) : Bool}
      +has_close = {U32.is_ge(close_length, 7) : Bool}
      choose(Anchor, has_long, \{
        False: choose(Anchor, has_close, \{
          True: Anchor{close_position, close_length, True{}}
          False: Anchor{0, 0, False{}}
        })
        True: choose(Anchor, has_close, \{
          False: Anchor{long_position, long_length, False{}}
          True: choose(Anchor, Choice.anchor_preferred(long_length,
            close_length, reference_length, literal_run), \{
              True: Anchor{long_position, long_length, False{}}
              False: Anchor{close_position, close_length, True{}}
            })
        })
      })

def select_unpredicted(anchor: Anchor) -> Anchor:
  match anchor:
    case Anchor{position, +length, close}:
      choose(Anchor, U32.is_ge(length, 11), \{
        True: Anchor{position, length, False{}}
        False: Anchor{0, 0, False{}}
      })

law select_anchor:
  for +reference: Bases
  for +query: Bases
  for +has_prediction: Bool
  for +predicted: U32
  for +literal_run: U32
  for +reference_length: U32
  Anchor

def select_anchor(reference, query, has_prediction, predicted, literal_run,
                  reference_length):
  match has_prediction:
    case False{}:
      select_unpredicted(longest_anchor(reference, query))
    case True{}:
      select_predicted(longest_anchor(reference, query),
        close_anchor(reference, query, predicted, literal_run),
        reference_length, literal_run)

def finish_region(+region_matches: U32, +region_mismatches: U32,
                  counts: Counts) -> Counts:
  match counts:
    case Counts{matches, mismatches, components}:
      choose(Counts,
        U32.is_ge(U32.add(region_matches, region_mismatches), 35), \{
          True: Counts{U32.add(matches, region_matches),
            U32.add(mismatches, region_mismatches),
            U32.add(components, 1)}
          False: Counts{matches, mismatches, components}
        })

law parse_loop:
  for fuel: Nat
  for +reference: Bases
  for +query: Bases
  for +has_prediction: Bool
  for +predicted: U32
  for +literal_run: U32
  for +reference_length: U32
  for literals: Bases
  for +region_matches: U32
  for +region_mismatches: U32
  for counts: Counts
  Counts

def parse_loop(fuel, reference, query, has_prediction, predicted, literal_run,
               reference_length, literals, region_matches, region_mismatches,
               counts):
  match fuel query:
    case Zero{} remaining:
      finish_region(region_matches, region_mismatches, counts)
    case Succ{rest} BasesNil{}:
      finish_region(region_matches, region_mismatches, counts)
    case Succ{rest} BasesCon{+head, +tail}:
      apply(Anchor, Counts,
        \{Anchor: +position => +length => +close => (
          choose(Counts, U32.is_eq(length, 0), \{
            True: parse_loop(rest, reference, tail,
              has_prediction && U32.is_lt(literal_run, 40),
              U32.add(predicted, 1), U32.add(literal_run, 1),
              reference_length, BasesCon{head, literals}, region_matches,
              region_mismatches, counts)
            False: apply(Extension, Counts,
              \{Extension: +extension_length => +extension_matches => +extension_mismatches => (
                +consumed = {U32.add(length, extension_length) : U32}
                +next_position = {U32.add(U32.add(position, length),
                  extension_length) : U32}
                choose(Counts, close, \{
                  True: (
                    +gap_matches = {best_gap_matches(reference,
                      bases_reverse(literals), predicted,
                      U32.add(position, length), literal_run) : U32}
                    parse_loop(rest, reference,
                      bases_drop(U32.to_nat(consumed), BasesCon{head, tail}),
                      True{}, next_position, 0, reference_length, BasesNil{},
                      U32.add(U32.add(U32.add(region_matches, length),
                        gap_matches), extension_matches),
                      U32.add(U32.add(region_mismatches,
                        U32.sub(literal_run, gap_matches)),
                        extension_mismatches), counts)
                  )
                  False: parse_loop(rest, reference,
                    bases_drop(U32.to_nat(consumed), BasesCon{head, tail}),
                    True{}, next_position, 0, reference_length, BasesNil{},
                    U32.add(length, extension_matches), extension_mismatches,
                    finish_region(region_matches, region_mismatches, counts))
                })
              )},
              approximate_extension(
                bases_drop(U32.to_nat(U32.add(position, length)), reference),
                bases_drop(U32.to_nat(length), BasesCon{head, tail})))
          })
        )},
        select_anchor(reference, BasesCon{head, tail}, has_prediction,
          predicted, literal_run, reference_length))

law parse:
  for +reference: Bases
  for +query: Bases
  Counts

def parse(reference, query):
  +reference_length = {U32.add(U32.mul(bases_length(reference, 0), 2), 120)
    : U32}
  parse_loop(U32.to_nat(bases_length(query, 0)), reference_space(reference),
    query, False{}, 0, 0, reference_length, BasesNil{}, 0, 0,
    Counts{0, 0, 0})

def ratio(+numerator: U32, +denominator: U32) -> U32:
  choose(U32, U32.is_eq(denominator, 0), \{
    True: 0
    False: U32.div(U32.mul(numerator, 10000), denominator)
  })

law metrics_from_counts:
  for counts: Counts
  for +query_length: U32
  Metrics

def metrics_from_counts(counts, query_length):
  match counts:
    case Counts{+matches, +mismatches, +components}:
      Metrics{matches, mismatches, components,
        ratio(matches, U32.add(matches, mismatches)),
        ratio(matches, query_length),
        ratio(U32.add(matches, mismatches), query_length)}

law score:
  for +reference: Bases
  for +query: Bases
  Metrics

def score(reference, query):
  metrics_from_counts(parse(reference, query), bases_length(query, 0))

# Universal proof seam: the public integer ANI is exactly its declarative
# matches/(matches+mismatches) specification, including the empty case.
law ani_spec:
  for +matches: U32
  for +mismatches: U32
  U32

def ani_spec(matches, mismatches):
  ratio(matches, U32.add(matches, mismatches))

law ani_numeric:
  for +matches: U32
  for +mismatches: U32
  U32

def ani_numeric(matches, mismatches):
  ratio(matches, U32.add(matches, mismatches))

law ani_numeric_agrees:
  for +matches: U32
  for +mismatches: U32
  {ani_numeric(matches, mismatches) == ani_spec(matches, mismatches) : U32}

def ani_numeric_agrees(matches, mismatches):
  {==}

law empty_alignment_is_zero:
  {ani_numeric(0, 0) == 0 : U32}

def empty_alignment_is_zero():
  {==}

law empty_gap_is_zero:
  for reference: Bases
  for +predicted: U32
  for +anchor_end: U32
  {best_gap_matches(reference, BasesNil{}, predicted, anchor_end, 0) == 0 : U32}

def empty_gap_is_zero(reference, predicted, anchor_end):
  {==}

law empty_query_has_no_extension:
  for reference: Bases
  {approximate_extension(reference, BasesNil{})
    == Extension{0, 0, 0} : Extension}

def empty_query_has_no_extension(reference):
  {==}
