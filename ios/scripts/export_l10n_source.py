#!/usr/bin/env python3
"""Export the iOS string catalogs as one translation source file.

Plan section 5 (docs/multilingual-plan-2026-10.md): every user-facing key goes
to the translator with its English, its translator comment, whether it is a
plural, and what the catalog holds today for each target language. The output
is a JSON array, one object per key:

    {
      "catalog":  "Localizable" | "InfoPlist" | "Widget",
      "key":      the catalog key (the English itself, or an explicit key such
                  as "lifeArea.health" when one English word serves contexts
                  that need different words in other languages),
      "english":  what an English user sees (the en value when the catalog has
                  one, otherwise the key),
      "comment":  the translator comment (several contexts are joined by
                  newlines; each line is one place the string shows),
      "plural":   true when the English has plural variations,
      "english_plural": {"one": ..., "other": ...}   (only when plural),
      "placeholders": ["%lld", "%@", ...]             (in order, may be empty),
      "existing": {"de": {"value": ..., "state": ...} | null, "es": ..., ...}
    }

Keys marked shouldTranslate: false are left out. Run from anywhere:

    python3 ios/scripts/export_l10n_source.py OUT.json [--langs de,es,fr,it]
"""

import argparse
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
IOS = os.path.dirname(HERE)

CATALOGS = [
    ("Localizable", os.path.join(IOS, "solyn", "Localizable.xcstrings")),
    ("InfoPlist", os.path.join(IOS, "solyn", "InfoPlist.xcstrings")),
    ("Widget", os.path.join(IOS, "SolynWidget", "Localizable.xcstrings")),
]

# printf-style specifiers as the catalogs use them: %@, %lld, %d, %1$@, %.1f, %%
PLACEHOLDER = re.compile(r"%(?:\d+\$)?[-+ 0#]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?[@dDiuUxXoOfFeEgGcCsSaAp%]")


def placeholders(text):
    return [m for m in PLACEHOLDER.findall(text or "") if m != "%%"]


def unit_of(loc):
    """(value, state) of a localization's plain string unit, or None."""
    if not loc:
        return None
    su = loc.get("stringUnit")
    if su:
        return {"value": su.get("value"), "state": su.get("state")}
    return None


def plural_of(loc):
    """English plural forms {category: value} if the localization varies by plural."""
    if not loc:
        return None
    var = loc.get("variations", {}).get("plural")
    if var:
        return {cat: (v.get("stringUnit") or {}).get("value") for cat, v in var.items()}
    return None


def existing_for(loc):
    """What a target language holds today: a plain unit, or plural forms."""
    if not loc:
        return None
    plural = plural_of(loc)
    if plural:
        states = {
            (v.get("stringUnit") or {}).get("state")
            for v in loc["variations"]["plural"].values()
        }
        return {"plural": plural, "state": states.pop() if len(states) == 1 else sorted(s for s in states if s)}
    return unit_of(loc)


def export(langs):
    out = []
    for name, path in CATALOGS:
        with open(path, encoding="utf-8") as f:
            cat = json.load(f)
        source = cat.get("sourceLanguage", "en")
        for key, entry in cat["strings"].items():
            if entry.get("shouldTranslate") is False:
                continue
            if key.strip() == "":
                continue
            locs = entry.get("localizations") or {}
            en = locs.get(source)
            en_plural = plural_of(en)
            en_unit = unit_of(en)
            english = en_unit["value"] if en_unit and en_unit.get("value") is not None else key
            row = {
                "catalog": name,
                "key": key,
                "english": english,
                "comment": entry.get("comment", ""),
                "plural": bool(en_plural),
            }
            if en_plural:
                row["english_plural"] = en_plural
            row["placeholders"] = placeholders(
                english if not en_plural else (en_plural.get("other") or english)
            )
            row["existing"] = {lang: existing_for(locs.get(lang)) for lang in langs}
            out.append(row)
    return out


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out", help="where to write the JSON array")
    ap.add_argument("--langs", default="de,es,fr,it", help="target languages to report existing values for")
    args = ap.parse_args(argv)
    langs = [l.strip() for l in args.langs.split(",") if l.strip()]
    rows = export(langs)
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
        f.write("\n")
    by_cat = {}
    for r in rows:
        by_cat[r["catalog"]] = by_cat.get(r["catalog"], 0) + 1
    with_existing = sum(1 for r in rows if any(r["existing"].values()))
    print(f"{len(rows)} keys -> {args.out}  {by_cat}  ({with_existing} with an existing translation)")


if __name__ == "__main__":
    main(sys.argv[1:])
