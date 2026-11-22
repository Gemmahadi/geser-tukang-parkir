#!/usr/bin/env python3
"""Perbaiki par semua level jadi BFS-optimal (jujur).
Level scramble 12-30 punya solusi BFS 3-7 langkah padahal par tertulis 15-44
-> bintang 3 jadi gratis dan kurva kesulitan bohong. Script ini mengganti
par + solution tiap level dengan hasil BFS solver.py, method jadi 'bfs'.
"""
import json, sys
sys.path.insert(0, ".")
from solver import Puzzle, apply_solution

with open("levels.json") as f:
    levels = json.load(f)

report = []
changed = 0
for lv in levels:
    pz = Puzzle(lv["vehicles"])
    par, sol, nodes = pz.solve()
    assert par is not None, f"{lv['name']}: BFS gagal"
    ok, msg = apply_solution(lv["vehicles"], sol)
    assert ok, f"{lv['name']}: solusi BFS tidak legal: {msg}"
    old_par, old_method = lv.get("par"), lv.get("method")
    lv["par"] = par
    lv["solution"] = sol
    lv["method"] = "bfs"
    if old_par != par or old_method != "bfs":
        changed += 1
    report.append({
        "level": int(str(lv["name"]).split()[-1]),
        "theme": lv["theme"],
        "vehicles": len(lv["vehicles"]),
        "par": par,
        "method": "bfs",
        "bfs_nodes": nodes,
        "note": "BFS-optimal" + ("" if old_par == par else f" (was par={old_par} {old_method})"),
    })
    print(f"{lv['name']}: par {old_par} ({old_method}) -> {par}  nodes={nodes}")

with open("levels.json", "w") as f:
    json.dump(levels, f, indent=2, ensure_ascii=False)
with open("report.json", "w") as f:
    json.dump(report, f, indent=2, ensure_ascii=False)
print(f"OK: {len(levels)} level, {changed} diubah, par sekarang BFS-optimal semua.")
