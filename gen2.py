#!/usr/bin/env python3
"""Scramble generator: start near-solved (player at col 4, 1 move from exit),
apply K random legal moves (never the exit move, never the exact inverse of
the previous move). Reverse of the scramble is a valid solution.
Then BFS-verify the true optimal par."""
import json, random, sys, time
sys.path.insert(0, ".")
from solver import Puzzle, validate_level, apply_solution

PALETTE = ["blue", "yellow", "green", "orange", "purple", "white", "pink", "cyan", "brown"]
IDS = "ABCDEFGHIJ"
LENS = {"car": 2, "angkot": 3, "motor": 1, "mogok": 2}
INV = {"U": "D", "D": "U", "L": "R", "R": "L"}

def make_s0(rng, n_veh, n_mogok=0, n_angkot=1):
    """Near-solved state: player at (2,4). Others placed randomly, not
    overlapping player cells (2,4),(2,5)."""
    for _ in range(300):
        occ = {(2, 4), (2, 5)}
        vs = [{"id": "P", "type": "player", "len": 2, "dir": "H", "row": 2, "col": 4, "color": "red"}]
        types = []
        for i in range(n_veh - 1):
            if i < n_mogok:
                types.append("mogok")
            elif i < n_mogok + n_angkot:
                types.append("angkot")
            elif rng.random() < 0.25:
                types.append("motor")
            else:
                types.append("car")
        rng.shuffle(types)
        ok = True
        for idx, typ in enumerate(types):
            L = LENS[typ]
            placed = False
            for _try in range(80):
                d = rng.choice("HV")
                if d == "H":
                    row, col = rng.randrange(6), rng.randrange(0, 7 - L)
                    cells = [(row, col + k) for k in range(L)]
                else:
                    row, col = rng.randrange(0, 7 - L), rng.randrange(6)
                    cells = [(row + k, col) for k in range(L)]
                if any(c in occ for c in cells):
                    continue
                for c in cells:
                    occ.add(c)
                vs.append({"id": IDS[idx], "type": typ, "len": L, "dir": d,
                           "row": row, "col": col, "color": PALETTE[idx % len(PALETTE)]})
                placed = True
                break
            if not placed:
                ok = False
                break
        if ok:
            return vs
    return None

def scramble(rng, vs0, K):
    """Return (start_vehicles, solution) or None."""
    pz = Puzzle(vs0)
    state = pz.start
    moves = []
    prev_inv = None  # (vid, dir, dist) that would undo previous move
    for _step in range(K):
        cands = []
        for ns, vid, direction, dist in pz.moves(state):
            if pz.is_goal(ns):
                continue  # never exit during scramble
            if prev_inv and (vid, direction, dist) == prev_inv:
                continue
            cands.append((ns, vid, direction, dist))
        if not cands:
            return None
        ns, vid, direction, dist = rng.choice(cands)
        moves.append([vid, direction, dist])
        prev_inv = (vid, INV[direction], dist)
        state = ns
    # build start vehicles from final state
    vs = []
    for i, v in enumerate(vs0):
        pos = pz.get_pos(state, i)
        nv = dict(v)
        if v["dir"] == "H":
            nv["col"] = pos
        else:
            nv["row"] = pos
        vs.append(nv)
    # player must be back at col 0 in the level start (spec: player row 2 col 0)
    # Scramble may leave player elsewhere; if player col != 0, this scramble
    # is unusable as a level (player start is fixed). Reject.
    if vs[0]["col"] != 0:
        return None
    # reverse scramble brings the player back to col 4 (S0); the final
    # exit move P R 2 takes it out of the grid.
    solution = [[vid, INV[d], dist] for vid, d, dist in reversed(moves)]
    solution.append(["P", "R", 2])
    return vs, solution

def make_level(rng, n_veh, K, n_mogok=0, n_angkot=1):
    for _ in range(60):
        vs0 = make_s0(rng, n_veh, n_mogok, n_angkot)
        if vs0 is None:
            continue
        r = scramble(rng, vs0, K)
        if r is None:
            continue
        vs, solution = r
        # static validation needs theme/name; caller fills those in
        ok, msg = apply_solution(vs, solution)
        if not ok:
            continue
        return vs, solution
    return None

if __name__ == "__main__":
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 7
    rng = random.Random(seed)
    for n, K in [(6, 12), (6, 25), (8, 25), (8, 40), (10, 40), (10, 70)]:
        pars = []
        t0 = time.time()
        for trial in range(6):
            r = make_level(rng, n, K, n_mogok=1 if n >= 8 else 0, n_angkot=1)
            if r is None:
                pars.append("FAIL")
                continue
            vs, sol = r
            pz = Puzzle(vs)
            par, bsol, nodes = pz.solve(max_nodes=3000000)
            pars.append((par, len(sol), nodes))
        print(f"n={n} K={K} -> {pars} time={time.time()-t0:.1f}s")
