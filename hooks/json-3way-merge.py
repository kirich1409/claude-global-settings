#!/usr/bin/env python3
"""3-way JSON merge driver for settings.json (and similar config JSON).

Git invokes it as:  json-3way-merge.py <base> <ours> <theirs>
  <ours> is also the OUTPUT file — git reads the merged result back from it.
  exit 0 = fully merged; exit 1 = unresolved conflict, so git marks the path
  conflicted and the caller's loud fallback (auto-pull .remote / csync claude -p)
  takes over. The point is to auto-resolve the COMMON cases so that path is rare.

Why this exists: settings.json is the #1 sync-conflict source. Git's line merge (and
the built-in `union` driver) corrupts JSON. This does a structural 3-way merge:

  - objects: deep 3-way merge per key.
  - arrays: treated as sets by deep value-equality — an element survives if kept by
    both sides or added by either; an element removed by one side (and untouched by the
    other) is dropped. Order: surviving base order, then ours-additions, then
    theirs-additions. This is exactly what permissions.allow/deny/ask and
    sandbox.network.allowedDomains want — additions from different machines accumulate.
  - scalars: equal -> ok; one side == base -> take the changed side; both changed
    differently -> conflict (exit 1).
"""
import json
import sys

_SENTINEL = object()


class Conflict(Exception):
    pass


def _key(v):
    # stable identity for dedup / equality of arbitrary JSON values
    return json.dumps(v, sort_keys=True, ensure_ascii=False)


def merge(base, ours, theirs):
    if _key(ours) == _key(theirs):
        return ours
    if base is not _SENTINEL and _key(ours) == _key(base):
        return theirs
    if base is not _SENTINEL and _key(theirs) == _key(base):
        return ours
    # both sides changed relative to base (or there is no base)
    if isinstance(ours, dict) and isinstance(theirs, dict):
        return merge_dict(base if isinstance(base, dict) else {}, ours, theirs)
    if isinstance(ours, list) and isinstance(theirs, list):
        return merge_list(base if isinstance(base, list) else [], ours, theirs)
    raise Conflict()


def merge_dict(base, ours, theirs):
    out = {}
    # ours key order first, then keys only in theirs — keeps the diff minimal/stable
    keys = list(ours.keys()) + [k for k in theirs.keys() if k not in ours]
    for k in keys:
        o = ours.get(k, _SENTINEL)
        t = theirs.get(k, _SENTINEL)
        b = base.get(k, _SENTINEL)
        if o is _SENTINEL:                       # key only on theirs side
            if b is _SENTINEL:
                out[k] = t                       # added by theirs
            elif _key(t) == _key(b):
                continue                         # ours deleted, theirs unchanged -> delete
            else:
                raise Conflict()                 # ours deleted, theirs modified
            continue
        if t is _SENTINEL:                       # key only on ours side
            if b is _SENTINEL:
                out[k] = o                       # added by ours
            elif _key(o) == _key(b):
                continue                         # theirs deleted, ours unchanged -> delete
            else:
                raise Conflict()                 # theirs deleted, ours modified
            continue
        out[k] = merge(b, o, t)
    return out


def merge_list(base, ours, theirs):
    bset = {_key(x) for x in base}
    oset = {_key(x) for x in ours}
    tset = {_key(x) for x in theirs}
    out, seen = [], set()

    def add(x):
        k = _key(x)
        if k not in seen:
            seen.add(k)
            out.append(x)

    for x in base:                               # base elements kept by BOTH sides
        if _key(x) in oset and _key(x) in tset:
            add(x)
    for x in ours:                               # additions from ours
        if _key(x) not in bset:
            add(x)
    for x in theirs:                             # additions from theirs
        if _key(x) not in bset:
            add(x)
    return out


def detect_indent(path):
    try:
        with open(path) as f:
            for line in f:
                stripped = line.lstrip(" ")
                if stripped and stripped != line and stripped not in ("\n", "\r\n"):
                    return len(line) - len(stripped)
    except OSError:
        pass
    return 2


def load(path):
    with open(path) as f:
        return json.load(f)


def main():
    if len(sys.argv) < 4:
        return 1
    base_f, ours_f, theirs_f = sys.argv[1], sys.argv[2], sys.argv[3]
    try:
        base = load(base_f)
    except (OSError, ValueError):
        base = _SENTINEL                         # no/empty base — add/add case
    try:
        ours = load(ours_f)
        theirs = load(theirs_f)
    except (OSError, ValueError):
        return 1                                 # invalid JSON on a side -> let caller handle
    try:
        merged = merge(base, ours, theirs)
    except Conflict:
        return 1
    indent = detect_indent(ours_f)
    with open(ours_f, "w") as f:
        json.dump(merged, f, indent=indent, ensure_ascii=False)
        f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
