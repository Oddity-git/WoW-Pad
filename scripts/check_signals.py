#!/usr/bin/env python3
"""Verify src/signals.cpp and addon/WowPad/Signals.lua agree (names, keys, order)."""
import re, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
c = (root / "src/signals.cpp").read_text()
lua = (root / "addon/WowPad/Signals.lua").read_text()
cs = re.findall(r'/\*\s*SIG_(\w+)\s*\*/\s*\{\s*"([^"]+)"', c)
ls = re.findall(r'\{\s*"(\w+)",\s*"([^"]+)"\s*\}', lua.split("SIGNAL_KEYS")[1].split("\n}")[0])
cs = [(n.strip(), k) for n, k in cs]
ok = cs == ls
print(f"C: {len(cs)} signals, Lua: {len(ls)} signals -> {'MATCH' if ok else 'MISMATCH'}")
if not ok:
    for a, b in zip(cs, ls):
        if a != b: print("  C", a, " Lua", b)
sys.exit(0 if ok else 1)
