# Vclust em Bend

Porte nativo das três etapas do Vclust 1.3.1: pré-filtro Kmer-db 2.3.1,
alinhamento LZ-ANI 1.2.3 e seis algoritmos do Clusty 1.2.2. O cálculo das
etapas está em Bend; Python compila, limita memória, executa e verifica a
saída de clustering. Este pacote é separado do frontend antigo `../run.py`.

## Executar

Requisitos: Linux com systemd de usuário, Python 3.11+, compilador Bend
2.0.40 e compilador C disponíveis. Revisão testada do checkout fonte:
`6b806192284fc9c64404d9b0b59c937f568d87ec`. Não é necessário usar o antigo
scratchpad `/tmp` para executar o pipeline. Na máquina desta retomada:

```bash
cd /home/veritas/Bend-Programs/Clustering/vclust_bend
export BEND_REPO='/home/veritas/Bioinformatique/Higher Order Company/Bend'
mkdir -p results
python3 run.py prefilter -i ../datasets/public_viromes/original/vclust_example.fasta -o results/filter.txt -t 12
python3 run.py align -i ../datasets/public_viromes/original/vclust_example.fasta --filter results/filter.txt -o results/ani.tsv -t 12
python3 run.py cluster -i results/ani.tsv --ids results/ani.ids.tsv -o results/clusters.tsv --algorithm leiden --metric ani --ani 0.95 -t 1
```

`align` também escreve `ani.ids.tsv`. `cluster` publica o TSV depois de
validar seu contrato semântico e grava `clusters.tsv.certificate.json`, com
hashes dos inputs/saída, parâmetros e testemunha de conectividade. O par de
arquivos não constitui uma transação única; compare o hash de saída do
certificado ao TSV ao consumi-los. Identificadores duplicados são recusados
pelo verificador por tornarem o mapeamento ambíguo.

O launcher usa cache em `.work/bin/` com hash dos fontes e compilador.
Uma trava serializa builds concorrentes e o executável só entra no cache
depois de terminar a compilação.
`--build-only` imprime o executável. `--compiler CAMINHO` substitui
`BEND_REPO`. `-t N` controla os workers Bend por `+RTS --threads N -RTS`;
passar `-t` diretamente ao binário não configura o runtime.

Os processos ficam em `bendwork.slice` (limite agregado 10 GiB, pressão a
9 GiB, sem swap); compilação até 8 GiB, execução até 3 GiB por padrão.
`--memory 4G` altera o limite do processo, mantendo o teto agregado. O
sandbox do Codex precisa autorizar o acesso ao systemd de usuário. Evitar
compilações e benchmarks simultâneos.

## O que as provas garantem

| Evidência | Contrato e limite |
| --- | --- |
| `partition_certificate.bend`, BendTT `--verdict` | Para qualquer lista aceita, há exatamente uma atribuição por posição ativa e todo rótulo é menor que o limite. O certificado é conferido antes de renderizar a saída nativa. Não exige que todos os rótulos possíveis sejam usados. |
| `clique_certificate.bend`, BendTT `--verdict` | Aceitar implica que cada par distinto com mesmo rótulo tem aresta no grafo fornecido. O modo `complete` usa uma cópia do grafo filtrado anterior ao agrupamento. |
| `proofs/Forest.lean`, Lean 4.34.0 | Arestas de pais, raiz preservada e rank estritamente decrescente implicam caminhos à raiz. Com fechamento das arestas, igualdade de raízes equivale a pertencer ao mesmo componente conexo. |
| `tests/verify_clusters.py`, a cada execução do launcher | Confere todos os identificadores exatamente uma vez, constrói/confere uma floresta; exige componentes exatos em `single`, clique em `complete`, centro adjacente a todos em `uclust`/`cd-hit`/`set-cover`, e conectividade em `leiden`. |
| Comparação byte a byte | Exercita a compatibilidade com Vclust nos casos registrados; não é prova universal de equivalência. |

O parser e o verificador Python permanecem na base de confiança: o teorema
Lean prova a implicação matemática a partir das hipóteses verificadas, não
a implementação de Python. Extração dos arrays, IO, renderização, compilador
e runtime também não foram provados de ponta a ponta. Os contratos referem-se
ao **grafo filtrado recebido**, não demonstram ausência de falsos negativos
no pré-filtro, validade biológica do limiar ANI, equivalência numérica
universal do alinhador nem ótimo global de Leiden. `--check-only` verifica
tipos/terminação; o veredicto matemático é `--verdict`.

## Validar e comparar

O Vclust de referência está em `../.tools/vclust-1.3.1/bin/vclust`.
Dados ficam em `../datasets/`. As referências usadas foram copiadas para
`.work/references/`, com hashes em `evidence/reference-inputs.json`.
Os testes regeneram referências ausentes com Vclust; não dependem da
sobrevivência do antigo `/tmp`. Executar sequencialmente:

```bash
python3 tools/validate.py check
python3 tools/validate.py proofs
python3 tools/validate.py guards
python3 tools/validate.py cli-tests
python3 tools/validate.py prefilter-tests --full
python3 tools/validate.py align-tests --full --threads 12
python3 tools/validate.py cluster-tests --full
python3 tools/validate.py semantics
python3 tools/validate.py benchmark --threads 1
python3 tools/validate.py benchmark --full --threads 12
python3 tools/validate.py certified-timings
```

`proofs` precisa de Lean 4.34.0 em PATH ou na instalação local registrada
no script. `guards` injeta atribuições/cliques inválidos na função de produção
e testa TSVs adversariais. Os JSONs em `evidence/` registram as execuções
concluídas; `.work/` contém executáveis, saídas e logs intermediários.
O benchmark faz uma amostra sequencial por ferramenta/configuração, com
1 e 12 workers na amostra de 1000 genomas e 12 no conjunto completo,
com comparação das quatro saídas. Os comandos acima geram JSONs separados. Exclui
compilação, launcher Bend e verificador Python das medidas; inclui os guardas
nativos. O tempo Vclust inclui seu CLI Python oficial. `certified-timings`
mede separadamente o comando de cluster com toda a verificação adicional.
Não interpretar uma amostra em desktop como resultado estatístico.

## Escopo e limitações operacionais

- Algoritmos: `single`, `complete`, `uclust`, `cd-hit`, `set-cover`, `leiden`.
  Leiden reproduz PCG32, ordem de somas binary64, desempates, refinamento,
  agregação e projeção do igraph usado pelo Clusty. Não usa Python para calcular
  os grupos. `tests/clusty_model.py` é referência de testes e parser numérico.
- LZ-ANI aceita `1 <= mal <= 16`, `1 <= msl <= 12`, `1 <= aw <= 32`.
  Há validação explícita dos parâmetros suportados; não prometer todos os
  recursos/formats do CLI Vclust (por exemplo diretórios/gzip).
- O leitor de métricas aceita decimais não negativos com limites declarados
  de tamanho; notação exponencial não é suportada. O formato emitido pelo
  alinhador testado está dentro desse domínio.
- Leiden: beta positivo; no máximo 1000 iterações positivas; iterações negativas
  preservam a semântica da versão de igraph empacotada com teto de segurança.
  Limites internos de fila/sorteio/níveis recusam saída ao esgotar o orçamento.
- A checagem nativa de clique é quadrática em pares de vértices, além da busca
  de vizinhança. É um custo de certificação de `complete`, não uma otimização.
- O caso `prefilter -k 30 --min-ident 0.9` não entra no total aprovado:
  Kmer-db de referência travou no exemplo e foi interrompido após 30 s.
  `tests/test_prefilter.py --include-slow-reference` permite tentar novamente
  com timeout; não foi atribuído como bug do Bend.

## Continuidade

Leia `../CLAUDE_HANDOFF.md` e `CLAUDE_HANDOFF.md` antes de retomar.
A fonte herdada está preservada em `../handoff/`; fontes e evidências da
apresentação estão em `../presentation/`. Nada foi commitado ou publicado
por esta retomada.

## Stage align (LZ-ANI 1.2.3 as driven by `vclust align`)

Sources: `align.bend` (CLI, FASTA/filter streaming, ordering, pairs, work
units, fork-join, output), `align_lz.bend` (CParser port), `align_io.bend`
(byte-level FASTA and Kmer-db filter parsers), `align_num.bend` (exact
numerics). `python3 run.py align -i X -o ani.tsv --filter fltr.txt -t N ...`;
flags as in `vclust align`: `--filter-threshold`, `--outfmt lite|standard|complete`,
`--out-ani/--out-tani/--out-gani/--out-qcov/--out-rcov`, `--mal --msl --mrd --mqd
--reg --aw --am --ar`. Without `--filter` every pair is aligned (as Vclust).

What is reproduced (sources read: LZ-ANI v1.2.3 `src/`, vclust v1.3.1):

- Input: `load_multifasta` (name up to the first space, `\r\n`, empty lines,
  empty headers dropped, non-ACGT = N, an unterminated last line is ignored
  like refresh `getline`). Sorting `reorder_items` (length - 2 as uint32
  descending, then name). Filter: `CFilter::load_filter` (rows = lines longer
  than 2 bytes, `j:value` entries, `value >= threshold`, both directions,
  names must equal the FASTA names).
- Parse: `prepare_reference` (forward, 2*mrd N, reverse complement, mrd N),
  `prepare_data`, the long-anchor table (all positions with the same 11-mer,
  longest wins, first position on ties; anchor at position 0 ignored), the
  close-seed table with `lower_bound` and the nearest-position tie rule,
  `compare_ranges`, `compare_ranges_both_ways` (including its data-position
  quirk when merging), forward/backward approximate extension, region removal,
  `calc_stats`. Factors live on an array stack exactly as `v_parsing`.
- The close/distant choice `ipow(1 - 4^-len, n)` is evaluated with an exact
  software binary64 multiply (`Dbl`, round-half-even on 53-bit mantissas), not
  F32: anchor probabilities are tabulated per work unit, close probabilities
  once per run. Checked against Python floats on 400 random (len, n) cases.
- Output: same row order (pairs a < b in sorted order; row (q=b, r=a) then
  (q=a, r=b)), header per `--outfmt`, `ani.ids.tsv` path rule. Ratios are
  printed from the exact rational a/b with the result of
  `refresh::real_to_pchar(double(a)/b, 6)` (dragonbox shortest + round half up
  to 6 significant digits, `1.00000`, `e-05` forms; 4 digits for len_ratio).
  This equals the binary64 path whenever the denominator is < 4.29e8 (proof
  sketch in `align_num.bend`; 3000 random ratios checked against Python).
  Thresholds are compared exactly as rationals against ceil(t * 10^9), which
  equals the binary64 comparison for thresholds with <= 9 decimals.

Parallelism and memory: one work unit per reference row (LZ-ANI's task:
the reference prepared once, then every partner of its filter row); a
cost-balanced binary fork-join tree over the units runs them (LZ-ANI: an
atomic row counter shared by the worker threads). A unit owns one
`Array<U32>` with every region (reference + both k-mer tables + query +
query k-mers + factor stack); only the references of running units are
resident. Sequences are shared read-only as 2-bit packed Data (`Seq`,
borrowed reads, no `@unsafe`). Two performance lessons: a Data record of 24
U32 fields is passed unboxed (24 words per call); adding one boxed field
(`Ctx.box`) made the parser 1.8x faster. And `when`-style lambda matches on
the per-position path cost a closure apply each; the hot path uses
Bool-parameter helper defs instead.

Not supported (explicit errors or documented differences): directory input
(multi-part genomes, `no_parts > 1`: Bend Base cannot list a directory; every
record is one part), gzip input, `--out-aln`, `mal > 16`, `msl > 12`,
`aw > 32`; binary64 underflow to subnormals in the probability test is not
emulated (needs non-default `msl` below about 13 with negative exponents);
upstream reads before the reference start when a final unaligned tail follows
a match ending within the first `msl` reference symbols (undefined behaviour
in C++; not reproduced).

Equivalence (byte-identical `ani.tsv` and `ani.ids.tsv`, so every column's
max |diff| is 0): see `tests/test_align.py` (launcher-based suite, JSON in
`evidence/align-equivalence-15.json`, includes full EarlyVir) and
`tests/test_align_report.py` (option variants, per-column max |diff| on any
mismatch, `--timing` under the bench lock).

## Stage prefilter (Kmer-db 2.3.1 as driven by `vclust prefilter`)

This branch (`vclust-faithful`) ports Kmer-db's own method: the same
database, the same pattern bookkeeping, the same sparse all-to-all. The
function-by-function map and every remaining difference are in
`DEVIATIONS.md`.

Files: `prefilter.bend` (CLI, output: `kmer-db distance` rows),
`kdb_extract.bend` (KmerHelper::extract, MinHashFilter, sortAndUnique),
`kdb_sort.bend` (the sort of 2-word records), `kdb_hash.bend`
(hash_map_lp), `kdb_db.bend` (PrefixKmerDb::addKmers, pattern_t),
`kdb_build.bend` (`kmer-db build -multisample-fasta`), `kdb_a2a.bend`
(all2all_sp, SparseMatrix, CBubbleHelper, compact2 / add_to_sampler),
`kdb_parts.bend` (all2all-parts, db2db_sp), `pf_fasta.bend` (FASTA reader),
`pf_num.bend` (64-bit and fixed-point arithmetic), `pf_sel.bend` (Sampler,
`-sample-rows`), `kdb_util.bend`.

```bash
prefilter -i in.fasta -o fltr.txt [-k 25] [--min-kmers 20] [--min-ident 0.7] \
  [--batch-size 0] [--kmers-fraction 1] [--max-seqs 0] [-t 12] [--bubble-size 8000] \
  +RTS --threads 12 -RTS
```

`-t` is Kmer-db's thread count as far as it shapes the method (all2all-sp
workers own the rows with row_id mod 2t in {t', 2t-1-t'}); the machine
threads are the runtime's `+RTS --threads`. `--bubble-size` is Kmer-db's
`-bubble-size` (Vclust keeps the default 8000; the tests lower it to force
the bubble path).

### Method (Kmer-db 2.3.1, vclust.py 1.3.1)

`vclust prefilter` runs `kmer-db build -multisample-fasta -k K -f F`, then
`kmer-db all2all-sp -sparse -min num-kmers:N -min ani-shorter:T
[-sample-rows ani-shorter:M]` (with `--batch-size B < n`: `mfasta-tool
split` into parts of B records, one `build` per part and `all2all-parts`),
then `kmer-db distance ani-shorter -sparse -min T`.

1. **Load and extract** (loader_ex, kmer_extract.h, filter.h): every record
   is a sample; its canonical k-mers (widened to an 8-bit prefix when
   2k - 32 < 8), filtered by the MinHash hash when F < 1, sorted and
   deduplicated. Samples are extracted in parallel chunks while the
   previous chunk is added to the database (the loader threads feeding the
   build loop).
2. **Build** (PrefixKmerDb::addKmers, one sample after the other): the
   database is one `hash_map_lp<suffix, pattern_id>` per k-mer prefix
   (k-mer >> 32). For each prefix run of the sample: `reserve_for_additional`,
   `find_item` per k-mer (new k-mers enter with pattern 0), samplePatterns =
   (pattern id, slot). samplePatterns sorted by pattern id; for each run of
   pattern p with c k-mers: if p is not a parent and holds exactly c
   k-mers, p is extended with the sample; else a new pattern (parent p,
   local sample s, c k-mers) is created, p loses c k-mers, and the run's
   table entries get the new id.
3. **all2all-sp**: patterns are decoded in id order through their parent
   chains into 8 MB buffers (patterns of at least 8000 samples become
   bubbles); while the next buffer is decoded, the workers process the
   current one: worker t owns the rows with row_id mod 2T in {t, 2T-1-t}
   and adds the pattern's k-mer count to `matrix[pat[j]][pat[k]]` for every
   owned position j and k < j (rows are `hash_map_lp<uint32, uint32>`).
   Then per row: bubble adders, the entries passing num-kmers >= N and
   ani-shorter >= T, sorted by column.
4. **all2all-parts** (--batch-size): every part has its own database; row
   part i gets db2db_sp(i, j) for j < i (merge of the two prefix-sorted k-mer
   lists into pattern-id pairs, sorted and counted, then the same decoded
   buffer / worker scheme with pattern pairs) and all2all_sp(i).
5. **Sampler** (`-sample-rows`, --max-seqs) and **distance**: the kept pairs
   go to both rows' top-M (Sampler, strategy best); `distance` prints
   `a+1:ani-shorter` with 6 decimals for the entries with a nonzero count.

Arithmetic (unchanged from the previous prefilter): ani-shorter =
1 + ln(2c / (c + m)) / k (m = the smaller k-mer count) is computed with a
64-bit fixed-point atanh series (error < 1e-17) instead of binary64 `log`;
the printed value can differ from Kmer-db's only if the exact value is within
~1e-10 of a rounding boundary of the 6th decimal (none in any test). The
min-ident comparison uses floor(T * 2^64); the MinHash threshold and hash are
exact 64-bit integer arithmetic; the `%g` header value is exact.

### Why the output is the same

The database and the patterns are built by the same procedure, so the
pattern of every k-mer (the set of samples holding it) and the k-mer count of
every pattern are the same as Kmer-db's (the number of patterns matches
Kmer-db's `Number of patterns` exactly, e.g. 7,841 on strat1000). all2all-sp
sums, for each sample pair, the k-mer counts of the patterns containing both,
which is the number of shared k-mers whatever the summation order, worker
partition, buffer size or bubble split (a bubble's count is added to the same
cells at the end). Row entries are sorted by column; filtering, sampling and
formatting are per entry. all2all-parts computes the same counts cell by cell
(a k-mer shared by a row-part sample and a column-part sample is in both
part databases, matched once by the merge). Pattern ids differ from
upstream's (they are assigned by a parallel atomic counter there) but no
output depends on them.

### Equivalence

`~/vclust-work/check.sh` (byte comparison with Vclust 1.3.1 on all datasets,
including acc100000 and the full acc323556) and
`tests/test_prefilter.py` (option sets: max-seqs, kmers-fraction, k 15/16/19,
batch-size, min-kmers 0, plus Bend-only `--bubble-size 2/3` and `-t 1/5`
whose output must equal the plain Vclust run). Results: see `DEVIATIONS.md`.

## Stage cluster (Clusty 1.2.2 as driven by `vclust cluster`)

Sources: `cluster.bend` (vclust CLI + validation, ids/table streaming, staged
pipeline, renumbering and output), `cl_load.bend` (Clusty input semantics),
`cl_graph.bend` (rows + single / CD-HIT / set-cover / UCLUST),
`cl_complete.bend` (complete linkage), `cl_leiden.bend` (Leiden),
`f64.bend` (bit-exact software binary64 incl. fma and glibc `exp`).
Certificates (`partition_certificate.bend`, `clique_certificate.bend`, added
in the Codex session) are checked before the output is rendered.
`tests/clusty_model.py` is an executable Python model of the same semantics
(written first, byte-identical to Vclust on every case tried; used only to
pin the semantics and as a debugging oracle).

    cluster -i ani.tsv -o clusters.tsv --ids ani.ids.tsv [-r]
      [--algorithm single|complete|uclust|cd-hit|set-cover|leiden]
      [--metric tani|gani|ani] [--tani --gani --ani --qcov --rcov --len_ratio F]
      [--num_alns N] [--leiden-resolution F --leiden-beta F --leiden-iterations N]
      +RTS --threads N -RTS            (or: python3 run.py cluster ... -t N)

`CLUSTER_TIMING=1` prints per-phase milliseconds to stderr
(parse, build, kernel, certify+render, write).

### What is reproduced (from clusty v1.2.2 `src/`, igraph b1ba354 = 0.10.10-43, vclust.py 1.3.1)

- vclust → Clusty command: `--min <col> <v>` for every threshold > 0 (the
  metric's threshold is required > 0), `--max num_alns N`, distance column =
  metric with `--similarity` (d = 1 − v), `--numeric-ids`, objects = ids file.
- Values are Clusty's own `Conversions::strtod` (r·10 + digit, f·10 + digit,
  mul ·= 0.1 per fraction digit, r + f·mul — not correctly rounded);
  thresholds are correctly rounded (`istringstream`). A field `R.F` with k
  decimals is kept as the integer N = R·10^k + F; for fixed k the double is
  monotone in N, so each filter becomes an integer interval per (column, k),
  found once by binary search in exact soft-double arithmetic.
- Rows: a filter failure rejects the row; self pairs are dropped; local ids
  in first-appearance order of accepted rows (query column first); each row
  of the matrix sorted by (local id, d), duplicates keep the smallest d.
- Objects = ids-file order (vclust sorts by decreasing length).
- single: Clusty's SingleLinkageBFS — for each unassigned object in object
  order, a BFS with a FIFO queue that pushes only unassigned neighbours
  (`cl_graph.flood`). cd-hit: greedy in object order.
  set-cover: same, objects stable-sorted by decreasing degree. UCLUST: the
  first object is a seed; each next object joins the neighbouring seed with the
  strictly smallest distance (ties: lowest local id), else becomes a seed.
- complete: a port of `linkage_heaptrix` (`cl_heaptrix.bend`): element pool
  with free stack, binary heap of elements ordered by (d, row, col) with
  heap positions (`make_heap`, `insert`, `remove`, `replace`), one
  `matrix_row_ht` per group (MurMur3 fmix64, linear probing, tombstones);
  each step reads the top, builds the merged row (common neighbours, max
  distance), replaces/removes the old elements and erases them from the
  neighbours' rows, then inserts the remaining new elements. Group ids start
  at n (Clusty: max row + 1; both order-preserving). Clusters = final trees
  numbered by decreasing root id (Clusty's dendrogram walk).
- Leiden: `igraph_community_leiden(g, w = 1 − d, NULL node weights = 1,
  resolution, beta, start = false, iterations)` — CPM; level 0 has two parallel
  igraph edges per pair (Clusty adds (i, j) for every matrix entry), incidence
  lists sorted by other endpoint; PCG32 in its PCG32_INITIALIZER state (never
  reseeded; Lemire bounded draws for the Fisher–Yates shuffles, 52-bit
  uniforms), fast local moving with the empty-cluster stack and queue,
  refinement with exp(diff/β) sampling and binary search, aggregation, the
  level loop (including igraph's quirk of not projecting the last level), and
  the iteration loop (negative = `while !changed`, as written in 0.10.10).
  All arithmetic is IEEE binary64 in the same operation order; `exp` is glibc's
  `__ieee754_exp_fma`, the variant the static Clusty binary selects on FMA CPUs
  (table copied from the binary's `__exp_data`; 500k random f64 ops + 100k exp
  checked bit-exactly by `tests/f64/`). On a CPU without FMA Clusty would use
  the SSE2 variant, whose results can differ in the last bit.
- Output: clusters renumbered by decreasing size (stable), in-matrix objects
  sorted by (cluster, ids position), then objects absent from the graph as
  singletons in ids order; `-r` prints the first (longest) member.

Kernels are O(E) (complete: O(E log E)). The old `benchmark/bend_common_graph`
kernels were 100–200× slower than Clusty for algorithmic reasons: complete
linkage rescanned every row for the best pair at every merge (O(merges·E)),
UCLUST/CD-HIT (`centroid_find`) scanned every representative with a linear
neighbour search and rebuilt the neighbour list per lookup (O(V·clusters·deg)).

Limits: numeric fields must be non-negative decimals with ≤ 9 digits in total
and ≤ 15 decimals, no exponent (vclust align's output); `qidx/ridx` must index
the ids file; at most 32 table columns. The CLI accepts the vclust flags, not
argparse abbreviations or `--opt=value`. `cl_leiden_*.bend` +
`tools/generate_leiden_state.py` are an earlier Leiden from the Codex session,
superseded by `cl_leiden.bend` (same output on all tests, about 3× slower) and
not imported. In this repository the Codex `cl_leiden.bend` (sha256 36d3626a…
in `evidence/codex-source-manifest.json`) was replaced, so that manifest's
entry for it is stale.

### Equivalence (`tests/test_cluster.py`, `tests/f64/`)

`CAP=3G capped python3 tests/test_cluster.py --full` compares with the
installed `vclust cluster` byte for byte: 6 algorithms × 7 threshold/filter
settings (tani/gani/ani metrics; `--qcov --rcov --len_ratio --num_alns`; `-r`)
plus two Leiden parameter sets (resolution 0.2/β 0.05/3 iterations; resolution
1/iterations −1), on the `vclust align` tables of vclust_example,
stratified1000 and the full EarlyVir set (10,021 ids, 570,306 rows), plus 80
random graphs for Leiden with 0/1/2/4 iterations. Result 2026-11-23:
**168/168 identical without --full, 132/132 identical for the matrix with the
full table** (`evidence/cluster-equivalence-matrix.json`). Soft binary64:
`tests/f64/f64_test.bend` + `check_f64.py`, 500,000 add/sub/mul/div/fma/exp
and comparison cases, 0 mismatches against the host's IEEE doubles / exact
rational fma / glibc exp.

### Performance (bench lock, `tools/bench_cluster.py`; load average 23–35 from other jobs during every run)

ANI ≥ 0.95, wall seconds / max RSS (`/usr/bin/time`); "kernel" = Clusty's own
printed clustering time vs Bend's `CLUSTER_TIMING` kernel phase (12 workers
gave the same times: the stage has no parallel section).

| full EarlyVir | vclust CLI | Clusty binary (kernel) | Bend t1 (kernel) | Bend t12 |
| --- | ---: | ---: | ---: | ---: |
| single | 0.55 s / 182 MB | 0.27 s (0.4 ms) | 2.48 s / 32 MB (9 ms) | 2.41 s |
| complete | 0.51 s | 0.28 s (12.8 ms) | 2.69 s / 34 MB (62 ms) | 2.68 s |
| uclust | 0.52 s | 0.33 s (3.0 ms) | 2.74 s (18 ms) | 2.77 s |
| cd-hit | 0.64 s | 0.27 s (0.3 ms) | 2.72 s (3 ms) | 2.63 s |
| set-cover | 0.54 s | 0.30 s (0.6 ms) | 2.67 s (63 ms) | 2.85 s |
| leiden | 0.57 s | 0.31 s (35.6 ms) | 2.86 s / 33 MB (201 ms) | 2.94 s |

stratified1000 (445 KB table): vclust 0.76–0.87 s / 135 MB, Clusty binary
0.33–0.41 s / 135 MB, **Bend 0.08–0.20 s / 14 MB** (t1 and t12 alike).

Where Bend's time goes on the full table: ~90 % is parsing 48 MB
(2.3–2.5 s at this load). A probe that only reads the file with
`File.read_bytes` and walks the bytes takes 1.0 s at the same load (0.5 s on
a quiet machine): the bytes arrive as a cons list, one cell per byte, and IO
effects run serially on the event loop, so this floor cannot be parallelised;
the per-byte state machine adds the rest. Kernels vs the old
`benchmark/bend_common_graph` (8.39 s complete, 4.98 s UCLUST, 3.71 s CD-HIT
on this machine at load ≈ 2): 62 ms, 18 ms and 3 ms here, i.e. 135×, 275× and
1200× faster even under 10× the load. Bend's memory is 5–10× lower than
Clusty's (Clusty preallocates 128 MB I/O buffers).

### GPU (`!`) — measured, not adopted (2026-11-23)

The cluster binary contains no `!` call, so it builds no `.gpu` file and there
is no GPU entry point to measure; `+RTS --gpu off` changes nothing.
- Kernels: they take 3–200 ms on the full table and are sequential by
  definition. Leiden's local moves pop a queue whose order, and the order of
  every binary64 sum, decide the result, so a parallel version would not be
  byte-identical. The same holds for complete-linkage merge order and the
  greedy algorithms' object order.
- Input: the only parallel candidate is the byte parse. A probe
  (scratchpad `cw/gpu/par.bend`) read the whole 48 MB table into 731 chunk lists
  of 64 KiB and parsed them with a fork-join tree, run as `go(t)` or `go!(t)`
  (bench lock, load ≈ 8):

  | mode | read + build chunk tree | parallel parse | total | RSS |
  | --- | ---: | ---: | ---: | ---: |
  | CPU, 1 thread | 4.31 s | 0.58 s | 5.27 s | 869 MB |
  | CPU, 12 threads | 2.62 s | 0.34 s | 3.30 s | 869 MB |
  | GPU `!`, Quadro RTX 3000 | 2.27 s | 0.25 s | 2.86 s | 869 MB |

  The GPU parse is the fastest, but parsing needs the whole file materialised
  as cons lists first, which costs more than the entire streaming pipeline
  (≈ 1 s for read+walk alone; see
  `bugs/feature-bulk-file-read-into-array/`) and 25× its memory. The streaming
  sequential parser is therefore kept. A bulk `File` read into an `Array<U32>`
  would make a chunked CPU/GPU parse worthwhile; until then it is not.

### align on the GPU (`align_gpu.bend`)

GPU build: `bend align_gpu.bend -o align_gpu` (CUDA; writes `align_gpu.gpu`,
which must stay beside the binary). Same command-line flags as `align`.
`align_gpu.bend` imports `align.bend` and differs only in the pipeline top:
the fork-join tree over the work units is invoked as `run_tree!(...)`, so
every unit runs on a GPU lane; work units are sized for 1024 lanes. Runtime
options: `+RTS --gpu off -RTS` runs the same `!` call on the CPU pool,
`+RTS --gpu 4GB -RTS` caps the device heap. The CPU build (`align.bend`)
contains no `!` and needs no CUDA.

Sanity timings on stratified1000 (Quadro RTX 3000 6 GB, bench lock, load
about 1-4; outputs byte-identical to Vclust in every run):

| variant | GPU | same binary `--gpu off` (12 CPU threads) |
| --- | ---: | ---: |
| units sized for 12 workers | 103.2 s | 6.7 s |
| units sized for 1024 lanes (shipped) | 17.9 s | 6.4 s |
| units sized for 16384 lanes | 17.6 s | 6.6 s |
| no per-reference unit floor | device out of memory (also with `--gpu 5GB`) | 9.7-10.0 s |
| no pairs (`--filter-threshold 1`): fixed cost | 5.10 s | 3.45 s |

Why the GPU is slower here: the fixed cost (CUDA start, module load,
managed memory) is only about 1.7 s, so the rest is kernel time. Each work
unit is a long serial, branchy loop (hash lookups, variable-length scans,
extensions) over its own multi-MB working array, which is the guide's
"divergent per-lane work" case: one lane is far slower than a CPU core at
serial work, and lanes of a warp diverge. More units help until memory
binds: every live lane owns its working array (reference + k-mer tables +
query + factor stack), so 6 GB caps concurrency at a few thousand lanes,
well under the 16384-lane cube, and finer splitting rebuilds reference
indexes more often. Larger inputs do not amortise this: the fixed cost is
already small, and longer genomes mean bigger per-lane arrays (fewer lanes
fit) and longer serial loops per lane. The CPU build remains the fast path.

## Energy and GPU comparison (Vclust 1.3.1 vs Bend-C vs Bend-CUDA)

Tools (Python stdlib only):

- `tools/energy_bench.py [--cap 3G] [--baseline-seconds S] [--output F]... -- CMD`
  measures one command under the shared bench lock, inside its own `capped`
  scope: wall/user/sys (wait4 + RUSAGE_CHILDREN), cgroup `memory.peak` of the
  scope and largest-process max RSS, NVML board energy (total-energy counter,
  ctypes) with 100 ms samples of device memory, utilisation, power and the GPU
  memory of the run's own processes, every intel-rapl domain (wraparound via
  `max_energy_range_uj`), an idle baseline of S seconds right before the run,
  `uptime`, AC/battery + governor + CPU MHz, foreign GPU compute processes,
  and the sha256 of each output. One JSON line per run.
- `tools/run_energy_matrix.py --datasets stratified1000 [--gpu auto|off]`
  runs dataset x {prefilter, align, cluster, e2e} x {vclust-t12, vclust-t1,
  bendc-t12, bendc-t1, bendgpu-t12, bendgpuoff-t12}; Bend-C is the CPU build
  with `+RTS --gpu off --threads N -RTS`, bendgpu the `<stage>_gpu.bend` build
  (`.gpu` beside it) with the default runtime, bendgpuoff the same GPU binary
  with `--gpu off`. Every cell is diffed byte for byte with Vclust -t 12; a
  mismatch is never timed as a success. Stage cells read Vclust's upstream
  files; e2e chains each tool's own stages. 3 repeats on small sets, 1 on
  `all_clean_contigs`. Output: `evidence/energy/{<dataset>.jsonl,summary.json,RESULTS.md}`;
  `--report-only` regenerates the tables; `--bins`/`--gpu-bin` reuse prebuilt
  binaries. Runs on battery are excluded from the tables (listed separately).

Caveats that shape the numbers: CPU energy is **unavailable** (RAPL
`energy_uj` is root-only here; never estimated). NVML measures the whole
board, which idles at 17-43 W because the terminal (ghostty) renders on it,
so CPU-only cells show only board idle energy (raw, scaling with time) and
GPU net energy is given only for GPU cells. Load average 2-9 from other agents
during the runs. Cluster cells use `--algorithm leiden --metric ani --ani 0.95`.

stratified1000 (1000 genomes; medians of 3; all outputs byte-identical to
Vclust in every cell; full table in `evidence/energy/RESULTS.md`):

| stage | Vclust t12 | Vclust t1 | Bend-C t12 | Bend-C t1 | Bend-CUDA (GPU) | GPU binary, `--gpu off` |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| prefilter | 4.44 s / 709 MiB | 6.28 s / 694 MiB | **1.28 s** / 370 MiB | 3.12 s / 269 MiB | pending (no GPU build) | – |
| align | **3.08 s** / 443 MiB | 7.33 s / 113 MiB | 6.15 s / 278 MiB | 17.3 s / 97 MiB | 18.3 s / 124 MiB, 86 MiB device, +571 J board (0.57 J/genome)* | 9.06 s / 289 MiB* |
| cluster | 0.26 s / 153 MiB | (no thread flag) | **0.03 s** / 23 MiB | 0.03 s / 23 MiB | none by design | – |
| end-to-end | 11.6 s / 710 MiB | 14.9 s / 694 MiB | **7.81 s** / 370 MiB | 21.0 s / 269 MiB | 19.2 s, +666 J board (GPU align)* | 7.70 s (GPU align binary on CPU) |

\* GPU cells were measured while another agent's GPU `prefilter` probes ran
outside the lock: times are plausible (the align author measured 17.9 s), but
the GPU net joules are contaminated and are being re-measured.

Reading: Bend-C beats Vclust on prefilter (3.5x at t12) and cluster (8x),
loses on align (0.5x at t12), and wins end-to-end at 12 threads with half
the peak memory: 1.5x in the run tabled above, 1.1x in the first full matrix
run (Vclust 8.12 s vs Bend 7.32 s; Vclust's e2e varied 8.1-11.6 s between the
two runs under other agents' load, while its stage times did not); at 1 thread Vclust is faster end-to-end. The GPU build
of align is 3x slower than Bend-C and adds ~0.6 kJ on the board for 1000
genomes; nothing is gained on this hardware (divergent per-lane work, see
"align on the GPU"). Energy vs Vclust cannot be compared without RAPL.
