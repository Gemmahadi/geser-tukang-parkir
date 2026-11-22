#!/usr/bin/env python3
"""Build the 30 levels (Pasar 1-10, Terminal 11-20, Mal 21-30).

Methods:
  - 'bfs'      : candidate level whose par is proven BFS-optimal by solver.py
  - 'scramble' : level built by reverse scramble from a near-solved state;
                 par = scramble length (NOT claimed BFS-optimal). The stored
                 solution is verified legal by solver.apply_solution, and the
                 level is statically valid. Used only when BFS-optimal
                 construction cannot reach the target par window.

Checkpoint: after each level is accepted, levels.json + report.json are
rewritten, so a killed run keeps its progress. Re-run resumes missing slots.
Usage: python3 build_levels.py [--seed N] [--only 21,22] [--max-tries N]
"""
import argparse, json, os, random, sys, time
sys.path.insert(0, ".")
from solver import Puzzle, validate_level, apply_solution
from gen import rand_level
from gen2 import make_level as scramble_level

HERE = os.path.dirname(os.path.abspath(__file__))
LEVELS_PATH = os.path.join(HERE, "levels.json")
REPORT_PATH = os.path.join(HERE, "report.json")

# slot: (level_no, theme, n_vehicles, par_lo, par_hi, method_preference)
SLOTS = []
for i in range(1, 31):
    if i <= 10:
        theme = "pasar"
        n = [4, 4, 5, 5, 5, 6, 6, 6, 6, 6][i - 1]
        lo, hi = [ (3,5),(4,6),(5,7),(6,8),(7,9),(8,10),(9,11),(10,12),(11,13),(12,15) ][i-1]
    elif i <= 20:
        theme = "terminal"
        n = [6, 7, 7, 7, 8, 8, 8, 8, 8, 8][i - 11]
        lo, hi = [ (12,16),(13,17),(14,18),(15,19),(16,20),(17,21),(18,22),(19,23),(20,25),(22,27) ][i-11]
    else:
        theme = "mal"
        n = [8, 8, 9, 9, 9, 9, 10, 10, 10, 10][i - 21]
        lo, hi = [ (22,28),(24,30),(25,32),(26,34),(28,36),(30,38),(32,40),(34,42),(36,45),(38,50) ][i-21]
    SLOTS.append((i, theme, n, lo, hi))

def load_existing():
    if os.path.exists(LEVELS_PATH):
        with open(LEVELS_PATH) as f:
            return json.load(f)
    return []

def save(levels, report):
    with open(LEVELS_PATH, "w") as f:
        json.dump(levels, f, indent=2)
    with open(REPORT_PATH, "w") as f:
        json.dump(report, f, indent=2)

def bfs_candidate(rng, n_veh, lo, hi, tries=400, max_nodes=3000000):
    """Random placement + BFS filter. Returns (level_dict, stats) or None.
    Also returns the best sub-target candidate seen (highest par <= hi)."""
    best = None  # (par, vs, sol, nodes)
    for _ in range(tries):
        vs = rand_level(rng, n_veh, allow_mogok=(n_veh >= 7))
        if vs is None:
            continue
        pz = Puzzle(vs)
        par, sol, nodes = pz.solve(max_nodes=max_nodes)
        if par is None:
            continue
        if par < 2:
            continue
        if lo <= par <= hi:
            return vs, sol, par, nodes, True
        if par <= hi and (best is None or par > best[0]):
            best = (par, vs, sol, nodes)
    if best is not None:
        par, vs, sol, nodes = best
        return vs, sol, par, nodes, False
    return None

def scramble_candidate(rng, n_veh, target_len, tries=40):
    """Reverse scramble of length target_len (solution len = target+1 incl.
    exit move). Best-of-tries by TRUE BFS par, so the scramble level is as
    genuinely hard as possible even though its stated par is the scramble
    length. Returns (vs, solution, bfs_par, bfs_nodes) or None."""
    best = None
    for _ in range(tries):
        r = scramble_level(rng, n_veh, target_len,
                           n_mogok=1 if n_veh >= 8 else 0, n_angkot=1)
        if r is None:
            continue
        vs, solution = r
        pz = Puzzle(vs)
        par, _, nodes = pz.solve(max_nodes=3000000)
        score = par if par is not None else -1
        if best is None or score > best[0]:
            best = (score, vs, solution, nodes)
    if best is None:
        return None
    return best[1], best[2], best[0], best[3]

def state_to_vehicles(pz, state):
    vs = []
    for i, v in enumerate(pz.vehicles):
        nv = dict(v)
        pos = pz.get_pos(state, i)
        if v["dir"] == "H":
            nv["col"] = pos
        else:
            nv["row"] = pos
        vs.append(nv)
    return vs

def ascent_candidate(rng, vs_start, lo, steps=20, max_nodes=3000000):
    """Greedy ascent on true BFS par in state space, starting from vs_start.
    Returns (vs, sol, par, nodes) of the best state seen with player col 0,
    or None."""
    pz = Puzzle(vs_start)
    state = pz.start
    cur_par, _, _ = pz.solve(max_nodes=max_nodes)
    if cur_par is None:
        return None
    best = None
    if pz.get_pos(state, pz.pidx) == 0:
        best = (cur_par, state)
    for _step in range(steps):
        if cur_par >= lo:
            break
        scored = []
        for ns, _vid, _d, _dist in pz.moves(state):
            if pz.is_goal(ns):
                continue
            pp, _, _ = pz.solve_from(ns, max_nodes=max_nodes)
            if pp is not None:
                scored.append((pp, ns))
        if not scored:
            break
        scored.sort(key=lambda x: -x[0])
        top_p = scored[0][0]
        if top_p > cur_par:
            _, state = rng.choice([s for s in scored if s[0] == top_p])
            cur_par = top_p
        elif top_p == cur_par:
            _, state = rng.choice([s for s in scored if s[0] == cur_par])
        else:
            _, state = rng.choice(scored)
            cur_par = top_p
        if pz.get_pos(state, pz.pidx) == 0 and (best is None or cur_par > best[0]):
            best = (cur_par, state)
    if best is None:
        return None
    par, bstate = best
    vs = state_to_vehicles(pz, bstate)
    pz2 = Puzzle(vs)
    par2, sol, nodes = pz2.solve(max_nodes=max_nodes)
    if par2 is None:
        return None
    return vs, sol, par2, nodes

def build_slot(rng, slot, max_tries=400):
    no, theme, n, lo, hi = slot
    name = f"Level {no}"
    # --- BFS path: random filter (+ ascent) ---
    # Pasar (1-10): ALWAYS BFS-optimal, accept best found even below window.
    # Terminal low (11-16, lo<=16): BFS if it reaches the window or close.
    # Terminal high (lo>=17) and Mal (21-30): straight to scramble, the
    # random filter can never reach those windows (BFS cap for 10 vehicles
    # is ~10-13, measured by greedy ascent plateauing at par 10).
    use_bfs_path = (no <= 10) or (11 <= no <= 20 and lo <= 16)
    if use_bfs_path:
        r = bfs_candidate(rng, n, lo, hi, tries=max_tries)
        if r is not None:
            vs, sol, par, nodes, in_window = r
            if in_window:
                lv = {"name": name, "theme": theme, "vehicles": vs,
                      "par": par, "solution": sol, "method": "bfs"}
                return lv, {"level": no, "theme": theme, "vehicles": n, "par": par,
                            "method": "bfs", "bfs_nodes": nodes,
                            "note": "BFS-optimal"}
            if lo - par <= 6:
                a = ascent_candidate(rng, vs, lo, steps=12)
                if a is not None:
                    avs, asol, apar, anodes = a
                    if apar >= lo:
                        lv = {"name": name, "theme": theme, "vehicles": avs,
                              "par": apar, "solution": asol, "method": "bfs"}
                        return lv, {"level": no, "theme": theme, "vehicles": n, "par": apar,
                                    "method": "bfs", "bfs_nodes": anodes,
                                    "note": "BFS-optimal (greedy ascent from random level)"}
                    if apar > par:
                        vs, sol, par, nodes = avs, asol, apar, anodes
            if no <= 10 or lo - par <= 3:
                lv = {"name": name, "theme": theme, "vehicles": vs,
                      "par": par, "solution": sol, "method": "bfs"}
                return lv, {"level": no, "theme": theme, "vehicles": n, "par": par,
                            "method": "bfs", "bfs_nodes": nodes,
                            "note": f"BFS-optimal, below target window {lo}-{hi} (best found)"}
    # --- scramble path ---
    target = (lo + hi) // 2
    r2 = scramble_candidate(rng, n, target - 1)
    if r2 is None:
        raise RuntimeError(f"Level {no}: scramble generation failed")
    vs, solution, bfs_par, bfs_nodes = r2
    ok, msg = apply_solution(vs, solution)
    if not ok:
        raise RuntimeError(f"Level {no}: scramble solution invalid: {msg}")
    lv = {"name": name, "theme": theme, "vehicles": vs,
          "par": len(solution), "solution": solution, "method": "scramble"}
    return lv, {"level": no, "theme": theme, "vehicles": n, "par": len(solution),
                "method": "scramble", "bfs_nodes": bfs_nodes,
                "note": f"scramble length {target-1} + exit move; NOT BFS-optimal "
                        f"(solver BFS-optimal par of this level is {bfs_par})"}

def layout_sig(lv):
    return json.dumps([(v["id"], v["type"], v["len"], v["dir"], v["row"], v["col"])
                       for v in lv["vehicles"]])

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=20261121)
    ap.add_argument("--only", default="")
    ap.add_argument("--max-tries", type=int, default=400)
    args = ap.parse_args()
    rng = random.Random(args.seed)
    only = {int(x) for x in args.only.split(",") if x.strip()} or None
    levels = load_existing()
    done = {lv["name"] for lv in levels}
    report = []
    if os.path.exists(REPORT_PATH):
        with open(REPORT_PATH) as f:
            report = json.load(f)
    rep_by_no = {r["level"]: r for r in report}
    for slot in SLOTS:
        no = slot[0]
        if only is not None and no not in only:
            continue
        if f"Level {no}" in done:
            print(f"Level {no}: already built, skip", flush=True)
            continue
        t0 = time.time()
        lv, rep = build_slot(rng, slot, max_tries=args.max_tries)
        # uniqueness guard: same seed reused across runs + overlapping par
        # windows can otherwise return the identical layout twice.
        accepted = {layout_sig(x) for x in levels}
        attempt = 0
        while layout_sig(lv) in accepted and attempt < 5:
            attempt += 1
            print(f"Level {no}: duplicate layout, retrying with new seed (attempt {attempt})", flush=True)
            rng.seed(args.seed + 7919 * attempt + no)
            lv, rep = build_slot(rng, slot, max_tries=args.max_tries)
        if layout_sig(lv) in accepted:
            raise RuntimeError(f"Level {no}: could not produce a unique layout")
        errs = validate_level(lv)
        assert not errs, f"Level {no} invalid: {errs}"
        ok, msg = apply_solution(lv["vehicles"], lv["solution"])
        assert ok, f"Level {no} solution invalid: {msg}"
        if lv["method"] == "bfs":
            pz = Puzzle(lv["vehicles"])
            par, sol, nodes = pz.solve()
            assert par == lv["par"], f"Level {no}: re-solve par {par} != {lv['par']}"
        levels.append(lv)
        levels.sort(key=lambda l: int(l["name"].split()[-1]))
        rep_by_no[no] = rep
        report = [rep_by_no[k] for k in sorted(rep_by_no)]
        save(levels, report)
        print(f"Level {no} [{slot[1]}] n={slot[2]} par={lv['par']} method={lv['method']} "
              f"({rep['note']}) {time.time()-t0:.1f}s", flush=True)
    print(f"Done: {len(levels)} levels in {LEVELS_PATH}")

if __name__ == "__main__":
    main()
