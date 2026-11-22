#!/usr/bin/env python3
"""Rush Hour (geser-mobil) solver BFS + verifier.

Grid 6x6, rows/cols 0-5. Player P: len 2, H, row 2.
Types: car len 2, angkot len 3, motor len 1, mogok len 2 FIXED
(mogok never moves; treated as a permanent wall), player len 2.
Themes: pasar (Lv 1-10), terminal (Lv 11-20), mal (Lv 21-30).
Win: player head col == 6 (both cells out of grid).
One move = slide ONE vehicle any distance (1..k) in ONE direction.
Par = optimal number of moves (BFS).

State: packed int, 3 bits per vehicle head position (0..6).
  For H vehicles head = col, for V vehicles head = row.
Occupancy: 36-bit mask, bit r*6+c.
Usage:
  python3 solver.py --check levels.json   # verify all levels, print OK + par
  python3 solver.py --solve levels.json   # same, plus solution check
"""
import argparse, json, sys
from collections import deque

N = 6

def cell_bit(r, c):
    return 1 << (r * 6 + c)

class Puzzle:
    def __init__(self, vehicles):
        self.vehicles = vehicles
        self.n = len(vehicles)
        # masks[v][pos] -> occupancy bitmask of that vehicle at head pos
        self.masks = []
        self.max_pos = []
        for v in vehicles:
            L = v["len"]
            masks = []
            if v["dir"] == "H":
                r = v["row"]
                for col in range(0, 7 - L + 1):  # 0..6-L ; player may go to 6
                    m = 0
                    for k in range(L):
                        if col + k < 6:
                            m |= cell_bit(r, col + k)
                    masks.append(m)
                # player special: allow head 6 (empty mask, fully out)
                if v.get("type") == "player":
                    # masks list already covers col up to 5 (6-2+1=5 -> range 0..5)
                    # append pos 6 with mask 0
                    masks.append(0)
            else:
                c = v["col"]
                for row in range(0, 7 - L):
                    m = 0
                    for k in range(L):
                        m |= cell_bit(row + k, c)
                    masks.append(m)
            self.masks.append(masks)
            self.max_pos.append(len(masks) - 1)
        # start state
        s = 0
        for i, v in enumerate(vehicles):
            pos = v["col"] if v["dir"] == "H" else v["row"]
            s |= pos << (3 * i)
        self.start = s
        # player index (assume 0, but find it)
        self.pidx = next(i for i, v in enumerate(vehicles) if v.get("type") == "player")
        self._vid_index = {v["id"]: i for i, v in enumerate(vehicles)}

    def get_pos(self, state, i):
        return (state >> (3 * i)) & 7

    def set_pos(self, state, i, pos):
        return (state & ~(7 << (3 * i))) | (pos << (3 * i))

    def occupancy(self, state, skip=-1):
        occ = 0
        for i in range(self.n):
            if i == skip:
                continue
            occ |= self.masks[i][self.get_pos(state, i)]
        return occ

    def is_goal(self, state):
        return self.get_pos(state, self.pidx) == 6

    def moves(self, state):
        """Yield (new_state, vehicle_id, direction_letter, distance)."""
        occ_all = self.occupancy(state)
        for i, v in enumerate(self.vehicles):
            if v.get("type") == "mogok":
                continue  # fixed: never moves
            pos = self.get_pos(state, i)
            own = self.masks[i][pos]
            occ = occ_all & ~own
            L = v["len"]
            if v["dir"] == "H":
                r = v["row"]
                # left
                d = 0
                c = pos - 1
                while c >= 0 and not (occ & cell_bit(r, c)):
                    d += 1
                    yield (self.set_pos(state, i, c), v["id"], "L", d)
                    c -= 1
                # right (in-grid steps first; player exit handled after)
                d = 0
                c = pos + L
                while c < 6 and not (occ & cell_bit(r, c)):
                    d += 1
                    yield (self.set_pos(state, i, pos + d), v["id"], "R", d)
                    c += 1
                # player exit: if the whole row 2 from pos+L to col 5 is
                # clear, the player can slide straight out to head col 6.
                if v.get("type") == "player" and c >= 6 and pos < 6:
                    yield (self.set_pos(state, i, 6), v["id"], "R", 6 - pos)
            else:
                c0 = v["col"]
                # up
                d = 0
                r = pos - 1
                while r >= 0 and not (occ & cell_bit(r, c0)):
                    d += 1
                    yield (self.set_pos(state, i, r), v["id"], "U", d)
                    r -= 1
                # down
                d = 0
                r = pos + L
                while r < 6 and not (occ & cell_bit(r, c0)):
                    d += 1
                    yield (self.set_pos(state, i, pos + d), v["id"], "D", d)
                    r += 1

    def solve(self, max_nodes=0, max_depth=0):
        """BFS (layer by layer, one parent dict). Returns
        (par, solution_list, nodes_expanded) or (None, None, nodes)."""
        return self.solve_from(self.start, max_nodes, max_depth)

    def solve_from(self, start, max_nodes=0, max_depth=0):
        """BFS from an arbitrary start state. Same return contract."""
        if self.is_goal(start):
            return 0, [], 0
        # parent[state] = (prev_state << 9) | move_code ; root maps to 0.
        # move_code = (vid << 5) | (dir_code << 3) | dist, dir U=0 D=1 L=2 R=3
        dcode = {"U": 0, "D": 1, "L": 2, "R": 3}
        parent = {start: 0}
        frontier = [start]
        nodes = 0
        depth = 0
        while frontier:
            depth += 1
            if max_depth and depth > max_depth:
                return None, None, nodes
            nxt = []
            for s in frontier:
                nodes += 1
                if max_nodes and nodes > max_nodes:
                    return None, None, nodes
                for ns, vid, direction, dist in self.moves(s):
                    if ns in parent:
                        continue
                    parent[ns] = (s << 9) | (self._vid_index[vid] << 5) | (dcode[direction] << 3) | dist
                    if self.is_goal(ns):
                        sol = []
                        cur = ns
                        while parent[cur] != 0:
                            code = parent[cur] & 511
                            prev = parent[cur] >> 9
                            vi = code >> 5
                            dc = (code >> 3) & 3
                            dd = code & 7
                            sol.append([self.vehicles[vi]["id"], "UDLR"[dc], dd])
                            cur = prev
                        sol.reverse()
                        return len(sol), sol, nodes
                    nxt.append(ns)
            frontier = nxt
        return None, None, nodes


def apply_solution(vehicles, solution):
    """Simulate solution; return (ok, error_msg). Checks legality + win."""
    # mutable positions: id -> (row, col)
    pos = {}
    by_id = {}
    for v in vehicles:
        by_id[v["id"]] = v
        pos[v["id"]] = (v["row"], v["col"])
    def occupied(exclude=None):
        occ = set()
        for vid, v in by_id.items():
            if vid == exclude:
                continue
            r, c = pos[vid]
            for k in range(v["len"]):
                if v["dir"] == "H":
                    if c + k < 6:
                        occ.add((r, c + k))
                else:
                    occ.add((r + k, c))
        return occ
    for step_no, mv in enumerate(solution, 1):
        vid, direction, dist = mv[0], mv[1], int(mv[2])
        if vid not in by_id:
            return False, f"step {step_no}: unknown vehicle {vid}"
        v = by_id[vid]
        if v.get("type") == "mogok":
            return False, f"step {step_no}: mogok {vid} is fixed and cannot move"
        r, c = pos[vid]
        dr = dc = 0
        if direction == "U": dr = -1
        elif direction == "D": dr = 1
        elif direction == "L": dc = -1
        elif direction == "R": dc = 1
        else:
            return False, f"step {step_no}: bad direction {direction}"
        if v["dir"] == "H" and dr != 0:
            return False, f"step {step_no}: {vid} is H, cannot move {direction}"
        if v["dir"] == "V" and dc != 0:
            return False, f"step {step_no}: {vid} is V, cannot move {direction}"
        if dist < 1:
            return False, f"step {step_no}: dist < 1"
        occ = occupied(exclude=vid)
        # check every intermediate cell the vehicle sweeps into
        for s in range(1, dist + 1):
            nr, nc = r + dr * s, c + dc * s
            # cells of vehicle after s steps
            for k in range(v["len"]):
                if v["dir"] == "H":
                    cc = nc + k
                    if cc >= 6:
                        if vid != "P":
                            return False, f"step {step_no}: non-player exits grid"
                        continue
                    if cc < 0 or (nr, cc) in occ:
                        return False, f"step {step_no}: {vid} blocked at {(nr, cc)}"
                else:
                    rr = nr + k
                    if rr < 0 or rr >= 6 or (rr, nc) in occ:
                        return False, f"step {step_no}: {vid} blocked at {(rr, nc)}"
        pos[vid] = (r + dr * dist, c + dc * dist)
    pr, pc = pos["P"]
    if pc != 6:
        return False, f"player head col is {pc}, not 6 after solution"
    return True, ""


def validate_level(level):
    """Static checks: counts, bounds, overlap, player spec, exit blocked."""
    errs = []
    vs = level.get("vehicles", [])
    if not vs:
        errs.append("no vehicles")
        return errs
    # theme + vehicle-count ramp (total incl. player)
    theme = level.get("theme")
    if theme not in ("pasar", "terminal", "mal"):
        errs.append(f"bad/missing theme {theme!r} (must be pasar/terminal/mal)")
    else:
        want = {"pasar": (4, 6), "terminal": (6, 8), "mal": (8, 10)}[theme]
        if not (want[0] <= len(vs) <= want[1]):
            errs.append(f"theme {theme}: {len(vs)} vehicles, want {want[0]}-{want[1]}")
        try:
            num = int(str(level.get("name", "")).split()[-1])
            exp_theme = "pasar" if num <= 10 else ("terminal" if num <= 20 else "mal")
            if theme != exp_theme:
                errs.append(f"Level {num} should be theme {exp_theme}, got {theme}")
        except Exception:
            pass
    if level.get("method", "bfs") not in ("bfs", "scramble"):
        errs.append(f"bad method {level.get('method')!r}")
    p = vs[0]
    if p.get("id") != "P" or p.get("type") != "player" or p.get("len") != 2 \
            or p.get("dir") != "H" or p.get("row") != 2 or p.get("col") != 0:
        errs.append("player must be first: id P, type player, len 2, dir H, row 2, col 0")
    ids = set()
    occ = {}
    for v in vs:
        if v["id"] in ids:
            errs.append(f"duplicate id {v['id']}")
        ids.add(v["id"])
        if v["type"] == "player":
            if v["color"] != "red":
                errs.append("player color must be red")
            continue
        if v["type"] not in ("car", "angkot", "motor", "mogok"):
            errs.append(f"{v['id']}: bad type {v['type']}")
        exp_len = {"car": 2, "angkot": 3, "motor": 1, "mogok": 2}[v["type"]] if v["type"] in ("car", "angkot", "motor", "mogok") else None
        if exp_len is not None and v["len"] != exp_len:
            errs.append(f"{v['id']}: {v['type']} must have len {exp_len}")
        if v["dir"] not in ("H", "V"):
            errs.append(f"{v['id']}: bad dir")
        if v["color"] not in ("blue", "yellow", "green", "orange", "purple", "white", "pink", "cyan", "brown"):
            errs.append(f"{v['id']}: bad color {v.get('color')}")
        # bounds + overlap
        for k in range(v["len"]):
            r = v["row"] + k if v["dir"] == "V" else v["row"]
            c = v["col"] + k if v["dir"] == "H" else v["col"]
            if not (0 <= r < 6 and 0 <= c < 6):
                errs.append(f"{v['id']}: cell {(r, c)} out of grid")
            elif (r, c) in occ:
                errs.append(f"{v['id']}: overlaps {occ[(r, c)]} at {(r, c)}")
            else:
                occ[(r, c)] = v["id"]
    # player cells
    for k in range(2):
        if (2, k) in occ:
            errs.append(f"player overlaps {occ[(2, k)]}")
    # exit blocked: at least one vehicle cell in row 2, col >= 2
    blocked = any((2, c) in occ for c in range(2, 6))
    if not blocked:
        errs.append("exit not blocked: player could leave in 1 move")
    return errs


def check_file(path, max_nodes=0):
    with open(path) as f:
        levels = json.load(f)
    all_ok = True
    seen_layouts = {}
    for lv in levels:
        sig = json.dumps([(v["id"], v["type"], v["len"], v["dir"], v["row"], v["col"])
                          for v in lv.get("vehicles", [])])
        if sig in seen_layouts:
            print(f"{lv.get('name', '?')}: DUPLICATE LAYOUT of {seen_layouts[sig]}")
            all_ok = False
        seen_layouts[sig] = lv.get("name", "?")
    for lv in levels:
        name = lv.get("name", "?")
        errs = validate_level(lv)
        if errs:
            print(f"{name}: INVALID: {'; '.join(errs)}")
            all_ok = False
            continue
        ok, msg = apply_solution(lv["vehicles"], lv.get("solution", []))
        if not ok:
            print(f"{name}: stored solution INVALID: {msg}")
            all_ok = False
            continue
        if lv.get("par") != len(lv.get("solution", [])):
            print(f"{name}: claimed par {lv.get('par')} != solution length {len(lv.get('solution', []))}")
            all_ok = False
            continue
        if lv.get("method", "bfs") == "scramble":
            # Scramble level: par is the scramble length, NOT claimed
            # BFS-optimal. Only the solution's legality is verified here.
            print(f"{name}: OK (SCRAMBLE, not BFS-optimal) theme={lv.get('theme')} par={lv.get('par')} vehicles={len(lv['vehicles'])} solution_len={len(lv['solution'])}")
            continue
        pz = Puzzle(lv["vehicles"])
        par, sol, nodes = pz.solve(max_nodes=max_nodes)
        if par is None:
            print(f"{name}: BFS did not finish (nodes={nodes}) par_claimed={lv.get('par')}")
            all_ok = False
            continue
        if len(lv.get("solution", [])) != par:
            print(f"{name}: stored solution len {len(lv['solution'])} != BFS par {par} (claimed {lv.get('par')})")
            all_ok = False
            continue
        if lv.get("par") != par:
            print(f"{name}: claimed par {lv.get('par')} != BFS par {par}")
            all_ok = False
            continue
        print(f"{name}: OK (BFS-optimal) theme={lv.get('theme')} par={par} vehicles={len(lv['vehicles'])} bfs_nodes={nodes} solution_len={len(sol)}")
    print("ALL OK" if all_ok else "FAILURES ABOVE")
    return 0 if all_ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", metavar="FILE")
    ap.add_argument("--solve", metavar="FILE")
    ap.add_argument("--max-nodes", type=int, default=0)
    args = ap.parse_args()
    if args.check:
        sys.exit(check_file(args.check, args.max_nodes))
    if args.solve:
        sys.exit(check_file(args.solve, args.max_nodes))
    ap.print_help()
    return 1

if __name__ == "__main__":
    main()
