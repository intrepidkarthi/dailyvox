#!/usr/bin/env python3
"""Write machine-drafted translations into the three iOS string catalogs.

Plan section 5 (docs/multilingual-plan-2026-10.md): translations are machine
drafts until a named native reviewer signs the checklist for that language.
So every value this script writes that is new, or that differs from what the
catalog already held, gets state "needs_review". A value that matches the
catalog's current one keeps its state.

Inputs are what the translation pass produced from export_l10n_source.py:

  CHUNKS/ios-NN.json  the source rows (catalog, key, english, ...) in chunks,
                      as handed to the translators
  DRAFTS/ios-NN.json  for one language, {key: value} per chunk, same NN

The chunk number tells which catalog a key belongs to, so a key that lives in
two catalogs ("Welcome back" in the app and the widget) can carry a different
value in each. A draft value may be a string, or {category: value} for a key
whose English varies by plural; plural drafts go under variations.plural.

    python3 ios/scripts/import_l10n_drafts.py CHUNKS de=DRAFTS_DE [es=DRAFTS_ES ...]
"""

import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IOS = os.path.dirname(HERE)

CATALOGS = {
    "Localizable": os.path.join(IOS, "solyn", "Localizable.xcstrings"),
    "InfoPlist": os.path.join(IOS, "solyn", "InfoPlist.xcstrings"),
    "Widget": os.path.join(IOS, "SolynWidget", "Localizable.xcstrings"),
}


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save(path, cat):
    # Xcode's own layout: two-space indent, " : " separators, no trailing newline.
    text = json.dumps(cat, ensure_ascii=False, indent=2, separators=(",", " : "))
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def unit(value, state):
    return {"stringUnit": {"state": state, "value": value}}


def current(loc):
    """The value a localization holds today: a string, a {cat: value} dict, or None."""
    if not loc:
        return None
    if "stringUnit" in loc:
        return loc["stringUnit"].get("value")
    var = (loc.get("variations") or {}).get("plural")
    if var:
        return {c: (v.get("stringUnit") or {}).get("value") for c, v in var.items()}
    return None


def build(value, old_loc):
    old = current(old_loc)
    if isinstance(value, dict):
        old_states = {}
        if old_loc and (old_loc.get("variations") or {}).get("plural"):
            old_states = {c: (v.get("stringUnit") or {}).get("state")
                          for c, v in old_loc["variations"]["plural"].items()}
        forms = {}
        for c in sorted(value):
            same = isinstance(old, dict) and old.get(c) == value[c]
            forms[c] = unit(value[c], old_states.get(c) if same and old_states.get(c) else "needs_review")
        return {"variations": {"plural": forms}}, old != value
    if old == value and old_loc and "stringUnit" in old_loc:
        return old_loc, False
    return unit(value, "needs_review"), True


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2
    chunks_dir = argv[0]
    langs = [a.split("=", 1) for a in argv[1:]]
    cats = {name: load(path) for name, path in CATALOGS.items()}
    chunk_files = sorted(glob.glob(os.path.join(chunks_dir, "ios-*.json")))
    if not chunk_files:
        print(f"no ios-NN.json chunks in {chunks_dir}")
        return 2
    for lang, drafts_dir in langs:
        new = changed = same = 0
        for cf in chunk_files:
            nn = re.search(r"ios-(\d+)\.json$", cf).group(1)
            rows = load(cf)
            draft_path = os.path.join(drafts_dir, f"ios-{nn}.json")
            drafts = load(draft_path)
            for row in rows:
                key = row["key"]
                if key not in drafts:
                    print(f"{lang}: {row['catalog']} {key!r} has no draft in {draft_path}")
                    return 1
                entry = cats[row["catalog"]]["strings"][key]
                locs = entry.setdefault("localizations", {})
                old_loc = locs.get(lang)
                loc, diff = build(drafts[key], old_loc)
                locs[lang] = loc
                if old_loc is None:
                    new += 1
                elif diff:
                    changed += 1
                else:
                    same += 1
                entry["localizations"] = dict(sorted(locs.items()))
        print(f"{lang}: {new} new, {changed} changed, {same} unchanged")
    for name, path in CATALOGS.items():
        save(path, cats[name])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
