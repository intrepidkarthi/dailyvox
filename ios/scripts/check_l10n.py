#!/usr/bin/env python3
"""Check the iOS string catalogs are complete and safe for each language.

For every translatable key in Localizable, InfoPlist and the widget catalog,
and every language asked for:

  - the language has a value, and no value is empty or whitespace
  - plural keys carry every plural category CLDR requires for the language
  - the placeholders match the English: the same multiset of conversions, and
    in an order the formatter can follow (a translation that reorders must use
    positional placeholders %1$@, %2$lld, each pointing at an argument of the
    same type the English passes)
  - no stray printf conversion hides in the text ("100 % e..." reads as "% e")
    where the English has format arguments

Exits non-zero on any error.

    python3 ios/scripts/check_l10n.py de es fr it pt-BR hi
"""

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

# CLDR cardinal categories an integer count can hit, per language.
PLURAL_CATEGORIES = {
    "en": {"one", "other"},
    "de": {"one", "other"},
    "es": {"one", "many", "other"},
    "fr": {"one", "many", "other"},
    "it": {"one", "many", "other"},
    "pt-BR": {"one", "many", "other"},
    "hi": {"one", "other"},
}

SPEC = re.compile(r"%(?:(\d+)\$)?([-+ 0#]*)(\d*(?:\.\d+)?)((?:hh|h|ll|l|q|z|t|j)?)([@dDiuUxXoOfFeEgGcCsSaAp%])")
INT = set("dDiuUxXoOc")


def specs(text, literal_percent=False):
    """[(position or None, kind)] for each conversion in text, %% skipped.

    literal_percent: the string is shown as is (no format arguments), so a
    percent sign followed by a space ("100% on-device", "100 % privat") is
    prose, not a conversion with the space flag.
    """
    out = []
    for m in SPEC.finditer(text or ""):
        pos, flags, width, length, conv = m.groups()
        if conv == "%":
            continue
        if literal_percent and " " in flags:
            continue
        kind = "int" if conv in INT else "obj" if conv in "@" else "float" if conv in "fFeEgGaA" else conv
        out.append((int(pos) if pos else None, kind, m.group(0)))
    return out


def check_value(english, value):
    """Problems with one translated value against its English."""
    if value is None or not value.strip():
        return ["empty value"]
    eng = specs(english, literal_percent=True)
    # Without real arguments the text is shown as is, so "% p" in it is prose.
    # With them, a stray "% e" in the translation is a real bug: count it.
    tr = specs(value, literal_percent=not eng)
    eng_kinds = [k for _, k, _ in eng]
    problems = []
    if sorted(eng_kinds) != sorted(k for _, k, _ in tr):
        problems.append(f"placeholders {[s for *_, s in eng]} != {[s for *_, s in tr]}")
        return problems
    positional = [p for p, _, _ in tr if p is not None]
    if positional and len(positional) != len(tr):
        problems.append("mixes positional and plain placeholders")
    elif positional:
        if sorted(positional) != list(range(1, len(eng) + 1)):
            problems.append(f"positions {positional} do not cover 1..{len(eng)}")
        else:
            for p, k, s in tr:
                if eng_kinds[p - 1] != k:
                    problems.append(f"{s} points at a {eng_kinds[p - 1]} argument")
    elif [k for _, k, _ in tr] != eng_kinds:
        problems.append("reorders plain placeholders; use %1$@ style")
    return problems


def main(langs):
    errors = 0
    warnings = 0
    for name, path in CATALOGS:
        with open(path, encoding="utf-8") as f:
            cat = json.load(f)
        for key, entry in cat["strings"].items():
            if entry.get("shouldTranslate") is False or not key.strip():
                continue
            locs = entry.get("localizations") or {}
            en = locs.get("en") or {}
            en_plural = (en.get("variations") or {}).get("plural")
            english = (en.get("stringUnit") or {}).get("value") or key
            for lang in langs:
                loc = locs.get(lang)
                where = f"{name} [{lang}] {key!r}"
                if not loc:
                    print(f"ERROR {where}: missing")
                    errors += 1
                    continue
                var = (loc.get("variations") or {}).get("plural")
                if var:
                    need = PLURAL_CATEGORIES.get(lang, {"other"})
                    missing = need - set(var)
                    if missing:
                        print(f"ERROR {where}: plural lacks {sorted(missing)}")
                        errors += 1
                    for c, v in var.items():
                        eng_form = (en_plural or {}).get(c) or (en_plural or {}).get("other") or english
                        for p in check_value(eng_form, (v.get("stringUnit") or {}).get("value")):
                            # a "one" form may spell the count out ("one star")
                            if c == "one" and p.startswith("placeholders") and not specs(v["stringUnit"]["value"]):
                                continue
                            print(f"ERROR {where} ({c}): {p}")
                            errors += 1
                    continue
                if en_plural:
                    print(f"ERROR {where}: English varies by plural but {lang} does not")
                    errors += 1
                value = (loc.get("stringUnit") or {}).get("value")
                for p in check_value(english, value):
                    print(f"ERROR {where}: {p}")
                    errors += 1
                if not specs(english) and value and re.search(r"%[   ]?[A-Za-z@]", value) and "%%" not in value:
                    # no format arguments, so the text is shown as is; flag in case it ever is formatted
                    if specs(value) and not specs(english):
                        print(f"warn  {where}: {value!r} would misparse if ever passed through String(format:)")
                        warnings += 1
    print(f"{errors} error(s), {warnings} warning(s) for {', '.join(langs)}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or ["de", "es", "fr", "it"]))
