#!/usr/bin/env python3
"""Executable reference model of `vclust cluster` (Vclust 1.3.1 -> Clusty 1.2.2
-> igraph 0.10.10-43 Leiden), Python stdlib only.

It exists to pin down the exact semantics that the Bend port reproduces
(edge filtering with Clusty's non-correctly-rounded strtod, local-id order,
per-algorithm tie-breaks, cluster renumbering, output order, and igraph's
Leiden with its PCG32 default RNG).  Python floats are IEEE doubles and
math.exp is glibc's exp, so the model is bit-faithful to the C++ binary.

usage: clusty_model.py <vclust cluster args...>   (same flags as vclust)
"""
import math
import struct
import sys

M64 = (1 << 64) - 1


# ----------------------------------------------------------------------------
# Clusty number parsing (conversion.h)
def clusty_strtod(s):
    i, n = 0, len(s)
    neg = False
    if i < n and s[i] == '-':
        neg = True
        i += 1
    r = 0.0
    while i < n and '0' <= s[i] <= '9':
        r = r * 10.0 + (ord(s[i]) - 48)
        i += 1
    if i < n and s[i] == '.':
        i += 1
        f = 0.0
        mul = 1.0
        while i < n and '0' <= s[i] <= '9':
            f = f * 10.0 + (ord(s[i]) - 48)
            mul *= 0.1
            i += 1
        r += f * mul
    if i < n and s[i] in 'eE':
        i += 1
        en = False
        if i < n and s[i] == '-':
            en = True
            i += 1
        e = 0
        while i < n and '0' <= s[i] <= '9':
            e = e * 10 + ord(s[i]) - 48
            i += 1
        r *= 10.0 ** (-e if en else e)  # not bit-exact for exponents; unused
    return -r if neg else r


def clusty_strtol(s):
    i, n = 0, len(s)
    neg = False
    if i < n and s[i] == '-':
        neg = True
        i += 1
    v = 0
    while i < n and '0' <= s[i] <= '9':
        v = v * 10 + ord(s[i]) - 48
        i += 1
    return -v if neg else v


# ----------------------------------------------------------------------------
# PCG32 (igraph default RNG, PCG32_INITIALIZER state, never reseeded)
class PCG32:
    def __init__(self):
        self.state = 0x853c49e6748fea9b
        self.inc = 0xda3e39cb94b95bdb

    def get(self):
        old = self.state
        self.state = (old * 6364136223846793005 + self.inc) & M64
        xs = (((old >> 18) ^ old) >> 27) & 0xFFFFFFFF
        rot = old >> 59
        return ((xs >> rot) | (xs << ((-rot) & 31))) & 0xFFFFFFFF

    def integer(self, lo, hi):  # igraph_rng_get_integer
        if hi == lo:
            return lo
        rng = hi - lo + 1
        t = ((1 << 32) - rng) % rng
        while True:
            x = self.get()
            m = x * rng
            if (m & 0xFFFFFFFF) >= t:
                return lo + (m >> 32)

    def unif01(self):
        a = self.get()
        b = self.get()
        r = ((a << 20) + (b >> 12)) & 0xFFFFFFFFFFFFF
        return struct.unpack('<d', struct.pack('<Q', r | 0x3FF0000000000000))[0] - 1.0

    def unif(self, lo, hi):
        if lo == hi:
            return hi
        while True:
            r = self.unif01() * (hi - lo) + lo
            if r != hi:
                return r


def shuffle(v, rng):
    n = len(v)
    while n > 1:
        k = rng.integer(0, n - 1)
        n -= 1
        v[n], v[k] = v[k], v[n]


# ----------------------------------------------------------------------------
# igraph graph: edges list; inclist(v) = incident edges sorted by other end,
# parallel edges in decreasing edge id (radix sort in igraph_add_edges).
def make_inclist(n, edges):
    lists = [[] for _ in range(n)]
    for eid, (a, b) in enumerate(edges):
        if a == b:
            lists[a].append((a, -eid))
            lists[a].append((a, -eid))
        else:
            lists[a].append((b, -eid))
            lists[b].append((a, -eid))
    out = []
    for v in range(n):
        lst = sorted(lists[v])
        out.append([-e for (_, e) in lst])
    return out


def other(edges, e, v):
    a, b = edges[e]
    return b if a == v else a


def reindex(memb):
    newc = {}
    for c in memb:
        if c not in newc:
            newc[c] = len(newc)
    return [newc[c] for c in memb], len(newc)


def fastmove(n, edges, inc, ew, nw, res, memb, changed, rng):
    order = list(range(n))
    shuffle(order, rng)
    queue = list(order)
    qh = 0
    stable = [False] * n
    cw = [0.0] * n
    nb = [0] * n
    for i in range(n):
        cw[memb[i]] += nw[i]
        nb[memb[i]] += 1
    empty = [c for c in range(n) if nb[c] == 0]
    ewpc = [0.0] * n
    added = [False] * n
    while qh < len(queue):
        v = queue[qh]
        qh += 1
        cur = memb[v]
        cw[cur] -= nw[v]
        nb[cur] -= 1
        if nb[cur] == 0:
            empty.append(cur)
        c = empty[-1]
        neigh = [c]
        added[c] = True
        for e in inc[v]:
            u = other(edges, e, v)
            if u != v:
                c = memb[u]
                if not added[c]:
                    added[c] = True
                    neigh.append(c)
                ewpc[c] += ew[e]
        best = cur
        maxd = ewpc[cur] - nw[v] * cw[cur] * res
        for c in neigh:
            d = ewpc[c] - nw[v] * cw[c] * res
            if d > maxd:
                best = c
                maxd = d
            ewpc[c] = 0.0
            added[c] = False
        cw[best] += nw[v]
        nb[best] += 1
        if best == empty[-1]:
            empty.pop()
        stable[v] = True
        if best != cur:
            changed[0] = True
            memb[v] = best
            for e in inc[v]:
                u = other(edges, e, v)
                if stable[u] and memb[u] != best:
                    queue.append(u)
                    stable[u] = False
    memb[:], k = reindex(memb)
    return k


def mergenodes(edges, inc, ew, nw, subset, memb, csub, res, beta, refined, nbref, rng):
    n = len(subset)
    cw = [0.0] * n
    nbn = [0] * n
    ext = [0.0] * n
    total = 0.0
    for i, v in enumerate(subset):
        refined[v] = i
        cw[i] += nw[v]
        nbn[i] += 1
        total += nw[v]
        for e in inc[v]:
            u = other(edges, e, v)
            if u != v and memb[u] == csub:
                ext[i] += ew[e]
    order = list(subset)
    shuffle(order, rng)
    nonsingle = [False] * n
    ewpc = [0.0] * n
    added = [False] * n
    cum = [0.0] * n
    for v in order:
        cur = refined[v]
        if not nonsingle[cur] and ext[cur] >= cw[cur] * (total - cw[cur]) * res:
            cw[cur] = 0.0
            nbn[cur] = 0
            neigh = [cur]
            added[cur] = True
            for e in inc[v]:
                u = other(edges, e, v)
                if u != v and memb[u] == csub:
                    c = refined[u]
                    if not added[c]:
                        added[c] = True
                        neigh.append(c)
                    ewpc[c] += ew[e]
            best = cur
            maxd = 0.0
            tot = 0.0
            for j, c in enumerate(neigh):
                if ext[c] >= cw[c] * (total - cw[c]) * res:
                    d = ewpc[c] - nw[v] * cw[c] * res
                    if d > maxd:
                        best = c
                        maxd = d
                    if d >= 0:
                        try:
                            tot += math.exp(d / beta)
                        except OverflowError:
                            tot = math.inf
                cum[j] = tot
                ewpc[c] = 0.0
                added[c] = False
            if tot < math.inf:
                r = rng.unif(0.0, tot)
                lo, hi = 0, len(neigh) - 1
                pos = None
                while lo <= hi:
                    mid = lo + ((hi - lo) >> 1)
                    if cum[mid] > r:
                        hi = mid - 1
                    elif cum[mid] < r:
                        lo = mid + 1
                    else:
                        pos = mid
                        break
                if pos is None:
                    pos = lo
                chosen = neigh[pos]
            else:
                chosen = best
            cw[chosen] += nw[v]
            nbn[chosen] += 1
            for e in inc[v]:
                u = other(edges, e, v)
                if memb[u] == csub:
                    if refined[u] == chosen:
                        ext[chosen] -= ew[e]
                    else:
                        ext[chosen] += ew[e]
            if chosen != cur:
                refined[v] = chosen
                nonsingle[chosen] = True
    # clean refined membership
    nbref += 1
    newc = [0] * n
    for v in subset:
        c = refined[v]
        if newc[c] == 0:
            newc[c] = nbref
            nbref += 1
    for v in subset:
        refined[v] = newc[refined[v]] - 1
    return nbref - 1


def aggregate(edges, inc, ew, nw, memb, refined, nref):
    clusters = [[] for _ in range(nref)]
    for i, c in enumerate(refined):
        clusters[c].append(i)
    aedges, aew = [], []
    anw = [0.0] * nref
    amemb = [0] * nref
    ewtc = [0.0] * nref
    added = [False] * nref
    for c in range(nref):
        anw[c] = 0.0
        neigh = []
        v = -1
        for v in clusters[c]:
            for e in inc[v]:
                u = other(edges, e, v)
                c2 = refined[u]
                if c2 > c:
                    if not added[c2]:
                        added[c2] = True
                        neigh.append(c2)
                    ewtc[c2] += ew[e]
            anw[c] += nw[v]
        for c2 in neigh:
            aedges.append((c, c2))
            aew.append(ewtc[c2])
            ewtc[c2] = 0.0
            added[c2] = False
        amemb[c] = memb[v]
    return aedges, aew, anw, amemb


def leiden_once(n0, edges0, ew0, nw0, res, beta, membership, changed, rng):
    n = n0
    aggregate_node = list(range(n))
    g_edges, g_ew, g_nw = edges0, ew0, nw0
    imemb = membership
    imemb[:], nbc = reindex(imemb)
    changed[0] = False
    level = 0
    while True:
        gn = len(g_nw)
        inc = make_inclist(gn, g_edges)
        nbc = fastmove(gn, g_edges, inc, g_ew, g_nw, res, imemb, changed, rng)
        cont = nbc < gn
        if cont:
            if level > 0:
                for i in range(n):
                    membership[i] = imemb[aggregate_node[i]]
            clusters = [[] for _ in range(gn)]
            for i, c in enumerate(imemb):
                clusters[c].append(i)
            refined = [0] * gn
            nref = 0
            for c in range(nbc):
                nref = mergenodes(g_edges, inc, g_ew, g_nw, clusters[c], imemb, c,
                                  res, beta, refined, nref, rng)
            if nref >= gn:
                refined = list(imemb)
                nref = nbc
            for i in range(n):
                aggregate_node[i] = refined[aggregate_node[i]]
            ae, aw, anw, am = aggregate(g_edges, inc, g_ew, g_nw, imemb, refined, nref)
            g_edges, g_ew, g_nw = ae, aw, anw
            if level == 0:
                imemb = am
            else:
                imemb[:] = am
            level += 1
        else:
            break
    return nbc


def leiden(n, edges, ew, res, beta, iters):
    rng = PCG32()
    memb = list(range(n))
    nw = [1.0] * n
    changed = [False]
    nbc = n
    it = 0
    while (it < iters) if iters >= 0 else (not changed[0]):
        nbc = leiden_once(n, edges, ew, nw, res, beta, memb, changed, rng)
        it += 1
    return memb, nbc


# ----------------------------------------------------------------------------
def parse_vclust(argv):
    o = dict(i=None, o=None, ids=None, r=False, algorithm='single', metric='tani',
             tani=0.0, gani=0.0, ani=0.0, qcov=0.0, rcov=0.0, len_ratio=0.0,
             num_alns=0, res=0.7, beta=0.01, iters=2)
    k = 0
    while k < len(argv):
        a = argv[k]
        if a in ('-r', '--out-repr'):
            o['r'] = True
            k += 1
            continue
        v = argv[k + 1]
        key = {'-i': 'i', '--in': 'i', '-o': 'o', '--out': 'o', '--ids': 'ids',
               '--algorithm': 'algorithm', '--metric': 'metric', '--tani': 'tani',
               '--gani': 'gani', '--ani': 'ani', '--qcov': 'qcov', '--rcov': 'rcov',
               '--len_ratio': 'len_ratio', '--num_alns': 'num_alns',
               '--leiden-resolution': 'res', '--leiden-beta': 'beta',
               '--leiden-iterations': 'iters', '-v': None}[a]
        if key in ('i', 'o', 'ids', 'algorithm', 'metric'):
            o[key] = v
        elif key in ('num_alns', 'iters'):
            o[key] = int(v)
        elif key is not None:
            o[key] = float(v)
        k += 2
    return o


def run(o):
    names = []
    with open(o['ids'], 'rb') as f:
        data = f.read().decode('latin-1')
    lines = data.replace('\r', '\n').split('\n')[1:]
    for ln in lines:
        if not ln:
            continue
        fld = ln
        for sep in ',\t':
            fld = fld.split(sep)[0]
        if fld:
            names.append(fld)
    with open(o['i'], 'rb') as f:
        text = f.read().decode('latin-1')
    rows = text.split('\n')
    header = rows[0].replace(',', ' ').split()
    filters = {}
    for name in ('tani', 'gani', 'ani', 'qcov', 'rcov', 'len_ratio'):
        if o[name] > 0:
            filters[header.index(name)] = (o[name], sys.float_info.max)
    if o['num_alns'] > 0:
        filters[header.index('num_alns')] = (-sys.float_info.max, float(o['num_alns']))
    qc, rc = header.index('qidx'), header.index('ridx')
    dc = header.index(o['metric'])
    g2l = {}
    l2g = []
    accepted = []
    for row in rows[1:]:
        row = row.rstrip('\r')
        if not row:
            continue
        flds = row.replace(',', '\t').split('\t')
        ok = True
        d = None
        for c, (lo, hi) in filters.items():
            v = clusty_strtod(flds[c])
            if v < lo or v > hi:
                ok = False
                break
        if not ok:
            continue
        d = 1.0 - clusty_strtod(flds[dc])
        a, b = clusty_strtol(flds[qc]), clusty_strtol(flds[rc])
        if a == b:
            continue
        accepted.append((a, b, d))
    for a, b, d in accepted:
        for x in (a, b):
            if x not in g2l:
                g2l[x] = len(l2g)
                l2g.append(x)
    n = len(l2g)
    rowsm = [dict() for _ in range(n)]
    for a, b, d in accepted:
        la, lb = g2l[a], g2l[b]
        for x, y in ((la, lb), (lb, la)):
            if y not in rowsm[x] or d < rowsm[x][y]:
                rowsm[x][y] = d
    adj = [sorted(r.items()) for r in rowsm]
    n_edges = sum(len(r) for r in adj)
    objects = [g2l[g] for g in range(len(names)) if g in g2l]
    algo = o['algorithm']
    assign = []
    if n_edges > 0:
        assign = [-1] * n
        if algo == 'single':
            cid = 0
            for obj in objects:
                if assign[obj] == -1:
                    q = [obj]
                    h = 0
                    while h < len(q):
                        x = q[h]
                        h += 1
                        if assign[x] == -1:
                            assign[x] = cid
                            for y, _ in adj[x]:
                                if assign[y] == -1:
                                    q.append(y)
                    cid += 1
        elif algo in ('cd-hit', 'set-cover'):
            order = objects
            if algo == 'set-cover':
                order = sorted(objects, key=lambda x: -len(adj[x]))
            cid = 0
            for obj in order:
                if assign[obj] == -1:
                    assign[obj] = cid
                    for y, _ in adj[obj]:
                        if assign[y] == -1:
                            assign[y] = cid
                    cid += 1
        elif algo == 'uclust':
            seeds = {objects[0]: 0}
            assign[objects[0]] = 0
            for obj in objects[1:]:
                best = None
                for y, d in adj[obj]:
                    if y in seeds and (best is None or d < best[1]):
                        best = (y, d)
                if best is not None:
                    assign[obj] = seeds[best[0]]
                else:
                    seeds[obj] = len(seeds)
                    assign[obj] = seeds[obj]
        elif algo == 'complete':
            import heapq
            nbr = {i: dict(adj[i]) for i in range(n)}
            heap = [(d, i, j) for i in range(n) for j, d in adj[i] if i < j]
            heapq.heapify(heap)
            alive = set(range(n))
            parent = list(range(n))
            nxt = n
            rootpos = {}
            members = {i: [i] for i in range(n)}
            while len(alive) > 1 and heap:
                d, r, c = heapq.heappop(heap)
                if r not in alive or c not in alive:
                    continue
                g = nxt
                nxt += 1
                new = {}
                for x, dx in nbr[r].items():
                    if x != c and x in nbr[c]:
                        new[x] = max(dx, nbr[c][x])
                for x in nbr[r]:
                    nbr[x].pop(r, None)
                for x in nbr[c]:
                    nbr[x].pop(c, None)
                for x, dd in new.items():
                    nbr[x][g] = dd
                    heapq.heappush(heap, (dd, x, g))
                nbr[g] = new
                del nbr[r], nbr[c]
                alive.discard(r)
                alive.discard(c)
                alive.add(g)
                members[g] = members.pop(r) + members.pop(c)
            roots = sorted(alive, reverse=True)
            for cid, g in enumerate(roots):
                for x in members[g]:
                    assign[x] = cid
        elif algo == 'leiden':
            edges = []
            ew = []
            for i in range(n):
                for j, d in adj[i]:
                    edges.append((i, j))
                    ew.append(1.0 - d)
            assign, _ = leiden(n, edges, ew, o['res'], o['beta'], o['iters'])
    # saveAssignments
    old2new = []
    if assign:
        k = max(assign) + 1
        sizes = [0] * k
        for a in assign:
            sizes[a] += 1
        order = sorted(range(k), key=lambda c: -sizes[c])
        old2new = [0] * k
        for i, c in enumerate(order):
            old2new[c] = i
    single = len(old2new)
    inside, outside = [], []
    for gi, nm in enumerate(names):
        if gi in g2l:
            inside.append((old2new[assign[g2l[gi]]], gi, nm))
        else:
            outside.append((single, gi, nm))
            single += 1
    inside.sort()
    out = ['object\tcluster']
    rep = None
    cur = None
    for c, gi, nm in inside + outside:
        if o['r']:
            if c != cur:
                cur = c
                rep = nm
            out.append(f'{nm}\t{rep}')
        else:
            out.append(f'{nm}\t{c}')
    with open(o['o'], 'w') as f:
        f.write('\n'.join(out) + '\n')


if __name__ == '__main__':
    run(parse_vclust(sys.argv[1:]))
