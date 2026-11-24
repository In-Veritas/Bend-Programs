# GPU entry of the align stage: identical to align.bend except that the
# fork-join tree over the work units is a `!` call (run_tree!), so its
# parallel calls are dealt to the GPU (`+RTS --gpu off` runs them on the CPU
# pool instead). Build: bend align_gpu.bend -o align_gpu (writes align_gpu.gpu).
import Base
import ./align_num.bend as N
import ./align_lz.bend as L
import ./align_io.bend as R
import ./align.bend as A

# Work units are sized for 1024 "threads" instead of the CPU count: on the
# GPU each unit runs on one lane, so more (smaller) units keep more lanes busy.
# Measured on stratified1000: 12-way split 103 s, 1024-way 17.9 s, 16384-way
# 17.6 s; dropping the per-reference unit floor runs the device heap out of
# memory (every lane owns a multi-MB working array).
def gpu_split(+t: U32) -> U32:
  (t * 0 + 1024 : U32)

def when(-A0: Type, c: Bool, k: Bool -> A0) -> A0:
  k(c)

def plan.e(+n: U32, names: Array<List<&2, U32>>, lens: Array<U32>, +pk: List<&2, A.PK>, +k: U32,
           +p: L.Prm, +ct: List<&2, U32>, +t: A.WT) -> A.Plan:
  A.Plan{A.OS{A.write_out(A.run_tree!(t, p, ct), Array.new(U32, N.depth((k * 6 + 6 : U32)), 0)), names, lens},
    A.pk_rev(pk, Nil{}), k, n, ""}

def plan.d(+n: U32, names: Array<List<&2, U32>>, lens: Array<U32>, +pk: List<&2, A.PK>, +k: U32,
           +p: L.Prm, +ct: List<&2, U32>, s: A.UB) -> A.Plan:
  match s:
    case A.UB{jobs, seqs, +us}:
      plan.e(n, names, lens, pk, k, p, ct, A.build(48n, A.split(us, A.un_total(us, 0))))

def plan.c(names: Array<List<&2, U32>>, lens: Array<U32>, +n: U32, +threads: U32, +p: L.Prm,
           +ct: List<&2, U32>, r: Array<List<&2, U32>> & A.JS) -> A.Plan:
  (adj, s) = r
  match s:
    case A.JS{jobs, seqs, +k, +pk, +total}:
      +thr = N.u32_max(U32.div(total, (16 * N.u32_max(threads, 1) : U32)), 1)
      plan.d(n, names, lens, pk, k, p, ct, A.ub.go(U32.to_nat(n), A.UB{jobs, seqs, Nil{}}, thr, 0))

def plan.b(+n: U32, +d: Nat, +threads: U32, +p: L.Prm, +ct: List<&2, U32>, seqs: Array<L.Seq>,
           names: Array<List<&2, U32>>, lens: Array<U32>, adj: Array<List<&2, U32>>) -> A.Plan:
  plan.c(names, lens, n, threads, p, ct, A.js.go(U32.to_nat(n),
    (adj, A.JS{Array.new(List<&2, L.Job>, d, Nil{}), seqs, 0, Nil{}, 0}), 0))

def plan.a2(+n: U32, +d: Nat, +threads: U32, +p: L.Prm, +ct: List<&2, U32>, seqs: Array<L.Seq>,
            names: Array<List<&2, U32>>, lens: Array<U32>, s: A.AJ) -> A.Plan:
  match s:
    case A.AJ{ord, adj}:
      plan.b(n, d, threads, p, ct, seqs, names, lens, adj)

def plan.a(+hasf: Bool, +ps: List<&2, R.P2>, +n: U32, +d: Nat, +threads: U32, +p: L.Prm,
           +ct: List<&2, U32>, t: A.Tabs) -> A.Plan:
  match hasf t:
    case True{} A.Tabs{ord, seqs, names, lens}:
      plan.a2(n, d, threads, p, ct, seqs, names, lens,
        A.aj.go(ps, n, A.AJ{ord, Array.new(List<&2, U32>, d, Nil{})}))
    case False{} A.Tabs{ord, seqs, names, lens}:
      plan.b(n, d, threads, p, ct, seqs, names, lens,
        A.all_pairs(U32.to_nat(n), 0, n, Array.new(List<&2, U32>, d, Nil{})))

def plan(+c: A.Cfg, +recs: List<&2, R.Rec>, +hasf: Bool, +fl: R.FL, +threads: U32) -> A.Plan:
  match fl:
    case R.FL{h, +nf, cur, +names, r, ll, fi, co, iv, idd, ids, vb, thr, +ps}:
      +n = A.recs_count(recs, 0)
      +d = N.depth(N.u32_max(n, 1))
      +bad = hasf && (U32.is_le(nf, 2) || Bool.not(A.nl_eq(R.nl_rev(names, R.NLNil{}), A.rec_names(recs))))
      A.when(A.Plan, bad, \{
        True: A.plan_err(A.when(String, U32.is_le(nf, 2), \{
          True: "Incorrect kmer-db filter file"
          False: "Input sequences and filter sequences are different!"
        }))
        False: (
          +p = A.cfg_prm(c)
          plan.a(hasf, ps, n, d, threads, p, L.close_table(L.prm_msl(p), L.prm_mqd(p), L.prm_mrd(p)),
            A.tabs_fill(List.sort(~A.SR, ~A.sr_le, A.mk_srs(recs, 0)), 0, A.tabs_new(d))))
      })

def run.b(+c: A.Cfg, +recs: List<&2, R.Rec>, +hasf: Bool, fl: R.FL) -> IO(Unit):
  do IO<Unit>:
    t : U32 <- IO.thread_count()
    A.finish(c, plan(c, recs, hasf, fl, gpu_split(t)))

def run.a(+c: A.Cfg, recs: List<&2, R.Rec>) -> IO(Unit):
  match c:
    case A.Cfg{inp, out, +flt, +fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}:
      A.when(IO(Unit), String.is_empty(flt), \{
        True: run.b(c, recs, False{}, R.fl_new(0))
        False: do IO<Unit>:
          fl : R.FL <- A.read_filter(flt, fthr)
          run.b(c, recs, True{}, fl)
      })

def run(+c: A.Cfg) -> IO(Unit):
  match c:
    case A.Cfg{+inp, out, flt, fthr, fmt, tt, tg, ta, tq, tr, mal, msl, mrd, mqd, reg, aw, am, ar, err}:
      +msg = A.cfg_check(c)
      A.when(IO(Unit), String.is_empty(msg), \{
        True: do IO<Unit>:
          recs : List<&2, R.Rec> <- A.read_fasta(inp)
          run.a(c, recs)
        False: IO.die(Unit, 1, msg)
      })

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run(A.parse_args(A.args_tail(args), A.cfg_new()))
