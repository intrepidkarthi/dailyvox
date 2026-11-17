#!/usr/bin/env python3
"""Export app/src/main/res/values/strings.xml as a translation source.

    python3 tools/export-translation-source.py [out.json]

Writes a JSON array, one object per translatable resource, in file order:

    {"name": ..., "type": "string" | "plurals" | "string-array",
     "english": "..." | {"one": ..., "other": ...} | ["...", ...],
     "comment": "...", "translatable": true}

`english` is the text as the app shows it: XML entities resolved and Android
escapes (\\' \\" \\n \\t \\@ \\? \\\\) undone. Format specifiers (%1$s, %1$,d,
%%) are left exactly as written. resources with translatable="false" are
skipped.

`comment` is every translator comment that applies, outermost first, joined
by a blank line:

  * a section banner (a comment holding a ==== rule) applies until the next
    banner;
  * a group comment (one followed by another comment rather than by a
    resource) applies until the next group comment, banner or blank line;
  * an item comment (the last comment right before a resource) applies to that
    resource. A resource with no comment of its own borrows one from earlier
    in the same run (no blank line, no new group) -- the file's convention for
    "shortcut_speak_short / _long" pairs and "About 30 characters each" lists --
    but only when it plausibly belongs: the keys share a stem
    (reflection_tone_light / reflection_tone_even; a one-word stem only from
    the run's latest comment), the resource extends the key
    (speech_error_busy / speech_error_busy_fix), or the comment is the run's
    latest and says "each". Among several, a comment written for a set
    ("four rows", "About 10 characters each") wins over a sibling's own note.
    A borrowed comment is flagged with "comment_from", the key it sits above,
    so a reviewer can tell an inherited note from the resource's own.

Output goes to stdout when no path is given. Standard library only.
"""
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SOURCE = Path(__file__).resolve().parent.parent / "app/src/main/res/values/strings.xml"
TYPES = {"string", "plurals", "string-array"}


def unescape(text: str) -> str:
    """Undo Android resource escaping; XML entities are already resolved."""
    # As aapt2 does it: outside "double quotes" a run of whitespace is one
    # space and the ends are trimmed; inside them, whitespace is kept.
    text = text or ""
    out, i, quoted = [], 0, False
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            n = text[i + 1]
            if n == "u" and re.fullmatch(r"[0-9a-fA-F]{4}", text[i + 2:i + 6]):
                out.append(chr(int(text[i + 2:i + 6], 16)))
                i += 6
                continue
            out.append({"n": "\n", "t": "\t"}.get(n, n))
            i += 2
            continue
        if c == '"':  # an unescaped quote only delimits; aapt drops it
            quoted = not quoted
            i += 1
            continue
        if c.isspace() and not quoted:
            while i < len(text) and text[i].isspace():
                i += 1
            out.append("\0")  # collapsible space, resolved below
            continue
        out.append(c)
        i += 1
    s = "".join(out)
    s = s.strip("\0")
    return re.sub("\0+", " ", s)


def text_of(el) -> str:
    # Inline markup (<b>, <xliff:g>) is kept as its text.
    return unescape("".join(el.itertext()))


def clean_comment(raw: str) -> str:
    lines = [ln.strip() for ln in raw.strip().splitlines()]
    lines = [ln for ln in lines if ln and not re.fullmatch(r"=+", ln)]
    return " ".join(lines)


def blank_line_after(node) -> bool:
    return (node.tail or "").count("\n") >= 2


def stem(key: str) -> str:
    return key.rsplit("_", 1)[0]


def says_each(comment: str) -> bool:
    return re.search(r"\beach\b", comment) is not None


# Words that mark a comment as written for a set of keys, not just one.
SET_WORDS = re.compile(r"\b(each|rows?|chips|buttons|labels|items|captions|"
                       r"two|three|four|six)\b", re.I)


def belongs(key: str, source: str, comment: str, latest: bool) -> bool:
    """Whether `source`'s item comment plausibly also describes `key`."""
    if key.startswith(source + "_"):
        return True
    if stem(key) == stem(source):
        # a one-word stem ("settings") is too loose unless nothing intervenes
        return "_" in stem(key) or latest
    return latest and says_each(comment)


def export(path: Path):
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.parse(path, parser=parser).getroot()
    nodes = list(root)

    banner = ""
    group = ""
    item = ""          # comment waiting for the next resource
    run = []           # (key, comment) item comments earlier in this run
    out = []
    for idx, node in enumerate(nodes):
        if node.tag is ET.Comment:
            raw = node.text or ""
            nxt = nodes[idx + 1] if idx + 1 < len(nodes) else None
            if "====" in raw:
                banner, group, item, run = clean_comment(raw), "", "", []
            elif nxt is not None and nxt.tag is ET.Comment:
                group, item, run = clean_comment(raw), "", []
            else:
                item = clean_comment(raw)
            if blank_line_after(node):
                group, item, run = "", "", []
            continue

        if node.tag not in TYPES:
            continue
        name = node.get("name")
        own, borrowed_from = item, None
        if own:
            run.append((name, own))
            item = ""
        else:
            fits = [(k, c) for i, (k, c) in enumerate(reversed(run))
                    if belongs(name, k, c, latest=i == 0)]
            # a set comment ("four rows", "About 10 characters each") over a
            # sibling's own note; recency breaks ties (the sort is stable)
            fits.sort(key=lambda kc: SET_WORDS.search(kc[1]) is None)
            if fits:
                borrowed_from, own = fits[0]
        translatable = node.get("translatable", "true") != "false"
        if translatable:
            if node.tag == "string":
                english = text_of(node)
            elif node.tag == "plurals":
                english = {q.get("quantity"): text_of(q) for q in node.findall("item")}
            else:
                english = [text_of(q) for q in node.findall("item")]
            entry = {
                "name": name,
                "type": node.tag,
                "english": english,
                "comment": "\n\n".join(c for c in (banner, group, own) if c),
                "translatable": True,
            }
            if borrowed_from:
                entry["comment_from"] = borrowed_from
            out.append(entry)
        if blank_line_after(node):
            group, item, run = "", "", []
    return out


def main():
    data = export(SOURCE)
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if len(sys.argv) > 1:
        Path(sys.argv[1]).write_text(text, encoding="utf-8")
        counts = {}
        for e in data:
            counts[e["type"]] = counts.get(e["type"], 0) + 1
        print(f"{len(data)} keys -> {sys.argv[1]} {counts}", file=sys.stderr)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
