#!/usr/bin/env python3
"""Generator: random Rush Hour levels + BFS filter. Run: python3 gen.py [seed]"""
import json, random, sys, time
sys.path.insert(0, ".")
from solver import Puzzle, validate_level, apply_solution

PALETTE = ["blue", "yellow", "green", "orange", "purple", "white", "pink", "cyan", "brown"]
IDS = "ABCDEFGHIJ"

def rand_level(rng, n_veh, allow_mogok=True, allow_angkot=True):
    """n_veh = total incl. player. Returns vehicles list or None."""
    for _attempt in range(200):
        occ = {(2, 0), (2, 1)}
        vs = [{"id": "P", "type": "player", "len": 2, "dir": "H", "row": 2, "col": 0, "color": "red"}]
        # force one blocker in row 2: a V vehicle covering (2, c) for c in 3..5,
        # or an H vehicle in row 2.
        n_other = n_veh - 1
        types = []
        for i in range(n_other):
            r = rng.random()
            if allow_mogok and i == 0 and rng.random() < 0.35:
                types.append("mogok")
            elif allow_angkot and r < 0.18:
                types.append("angkot")
            elif r < 0.38:
                types.append("motor")
            else:
                types.append("car")
        # place blocker first: choose a V car/angkot at col 3 or 4 covering row 2
        placed_blocker = False
        for idx, typ in enumerate(types):
            vid = IDS[idx]
            L = {"car": 2, "angkot": 3, "motor": 1, "mogok": 2}[typ]
            # try random placements
            placed = False
            for _try in range(60):
                d = rng.choice("HV")
                if d == "H":
                    row = rng.randrange(6)
                    col = rng.randrange(0, 7 - L)
                    cells = [(row, col + k) for k in range(L)]
                else:
                    row = rng.randrange(0, 7 - L)
                    col = rng.randrange(6)
                    cells = [(row + k, col) for k in range(L)]
                if any(c in occ for c in cells):
                    continue
                # first vehicle: prefer it blocks row 2
                if not placed_blocker and idx == 0:
                    if (2, 3) not in cells and (2, 4) not in cells and (2, 2) not in cells:
                        continue
                for c in cells:
                    occ.add(c)
                vs.append({"id": vid, "type": typ, "len": L, "dir": d,
                           "row": row, "col": col, "color": PALETTE[idx % len(PALETTE)]})
                placed = True
                if any(c[0] == 2 and c[1] >= 2 for c in cells):
                    placed_blocker = True
                break
            if not placed:
                vs = None
                break
        if vs is None or not placed_blocker:
            continue
        # validate statically (overlap/bounds/blocked)
        _theme = "pasar" if n_veh<=6 else ("terminal" if n_veh<=8 else "mal")
        _num = 1 if _theme=="pasar" else (11 if _theme=="terminal" else 21)
        _errs = validate_level({"name": f"Level {_num}", "theme": _theme, "vehicles": vs})
        if _errs:
            continue
        return vs
    return None

def bfs_par(vs, max_nodes=1500000):
    pz = Puzzle(vs)
    t0 = time.time()
    par, sol, nodes = pz.solve(max_nodes=max_nodes)
    return par, sol, nodes, time.time() - t0

if __name__ == "__main__":
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    rng = random.Random(seed)
    for n in (5, 8, 10):
        for trial in range(3):
            vs = rand_level(rng, n, allow_mogok=(n >= 7))
            if vs is None:
                print(f"n={n} gen FAIL"); continue
            par, sol, nodes, dt = bfs_par(vs)
            print(f"n={n} par={par} nodes={nodes} time={dt:.1f}s types={[v['type'] for v in vs]}")
