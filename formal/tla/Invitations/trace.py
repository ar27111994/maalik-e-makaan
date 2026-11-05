#!/usr/bin/env python3
"""Shortens a TLC counterexample of Invitations.tla to one line per step.

Usage: python3 trace.py < tlc.log

Each line names the action, the process whose locals changed (with its new
pc and outcome), and the database cells that changed in that step.
"""

import re
import sys

text = sys.stdin.read()
m = re.search(r"Error: (Invariant \w+ is violated\.|Deadlock reached\.)", text)
print(m.group(1) if m else "no violation in this log")


def variables(block):
    out = {}
    for vm in re.finditer(r"^/\\ (\w+) = (.*?)(?=^/\\ |\Z)", block, re.S | re.M):
        out[vm.group(1)] = " ".join(vm.group(2).split())
    return out


def processes(tx):
    # tx = [ C1 |-> [pc |-> "idle", ..., out |-> "none", ...], ... ]
    procs = {}
    for pm in re.finditer(r"(\w+) \|-> \[([^\]]*)\]", tx):
        fields = dict(re.findall(r'(\w+) \|-> ("[^"]*"|\{[^}]*\}|[\w-]+)', pm.group(2)))
        procs[pm.group(1)] = fields
    return procs


DB = ["pStatus", "pDel", "locks", "inv", "invLock", "mem", "memW", "acct", "acctW", "clock"]
prev = None
for block in re.split(r"\n(?=\d+: <|State \d+: )", text):
    head = re.match(r"(?:State )?(\d+): <(\w+)", block)
    if not head:
        continue
    block = block.split("\n\n")[0]
    vs = variables(block)
    procs = processes(vs.get("tx", ""))
    line = f"{head.group(1):>3} {head.group(2)}"
    if prev is not None:
        pprocs = processes(prev.get("tx", ""))
        moved = [p for p in procs if procs[p] != pprocs.get(p)]
        for p in moved:
            f = procs[p]
            line += f"  {p}: pc={f.get('pc')}"
            if f.get("out") not in (None, '"none"'):
                line += f" out={f.get('out')}"
            if f.get("resp") not in (None, '"none"'):
                line += f" role={f.get('resp')}"
        changed = [k for k in DB if vs.get(k) != prev.get(k)]
        if changed:
            line += "  | " + "; ".join(f"{k}={vs[k]}" for k in changed)
    print(line)
    prev = vs
