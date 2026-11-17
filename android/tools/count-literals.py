#!/usr/bin/env python3
"""Count user-facing string literals still hard-coded in the app's Kotlin.

Plan B-15 moves every user-facing string into res/values/strings.xml so it can
be translated. This is the yardstick: run it before and after an extraction
round and compare the two numbers.

    python3 android/tools/count-literals.py            # summary per file
    python3 android/tools/count-literals.py -v         # every hit, file:line

It is a heuristic, not a parser. A literal counts when it holds a word of two
or more letters AND looks like prose (has a space, starts with a capital, or
sits directly inside Text("...")). Lines that are plainly not UI are skipped:
logging, preference keys, Room annotations, intents, MIME types, exceptions,
comments. DummyData.kt is skipped on purpose (store-screenshot fixtures, never
translated). What remains is the review list; anything left in it on purpose
is explained in the PR, not silenced here.
"""
import collections
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "app", "src", "main", "kotlin", "com", "dailyvox", "app")
SKIP_FILES = {"DummyData.kt"}

LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
TEXT_CALL = re.compile(r'\bText\(\s*"')
NOT_UI = re.compile(
    r'(Log\.[dewiv]\(|println|\bTAG\b|Key\(|PreferencesKey|@Query|@Entity|@Database|'
    r'@ColumnInfo|require\(|check\(|error\(|throw |Exception\(|putExtra|StringExtra|'
    r'Intent\(|setAction|"android\.|Uri\.parse|mimeType|"text/|"application/|'
    r'"image/|"audio/|@Suppress|@file|@JvmName)'
)

# A literal in one of these slots is shown or spoken, whatever it looks like.
UI_SLOT = re.compile(r'(contentDescription|stateDescription|onClickLabel|subtitle|setContentTitle|setContentText)\s*[=(]\s*$')
# SQL in Room migrations, crypto/annotation names, regexes, script codes.
NOT_PROSE = re.compile(
    r'(`|\b(REAL|INTEGER|TEXT NOT|PRAGMA|ALTER TABLE|SELECT|DROP TABLE)\b|^Hmac|'
    r'^MissingPermission$|\\\\b|^Ha[nt]s$|^Hant$)'
)
# Date patterns handed to a formatter are not prose, whatever letters they use.
DATE_CALL = re.compile(r'(dateFormat|SimpleDateFormat|DateTimeFormatter|ofPattern|Pattern)\(')
DATE_PATTERN = re.compile(r"[EMdyhHmsaLkGuwW ,.:'·-]+")


def scan(verbose: bool):
    per_file = collections.Counter()
    text_calls = 0
    hits = []
    for d, _, files in os.walk(ROOT):
        for f in sorted(files):
            if not f.endswith(".kt") or f in SKIP_FILES:
                continue
            path = os.path.join(d, f)
            rel = os.path.relpath(path, ROOT)
            in_block = False
            raw = False
            for n, line in enumerate(open(path, encoding="utf-8"), 1):
                s = line.strip()
                if in_block:
                    if "*/" in s:
                        in_block = False
                    continue
                if s.startswith("/*"):
                    in_block = "*/" not in s
                    continue
                if s.startswith("*") or s.startswith("//"):
                    continue
                if line.count('"""') % 2 == 1:
                    raw = not raw
                    continue
                if raw:
                    continue
                code = line.split(" // ")[0]
                text_calls += len(TEXT_CALL.findall(code))
                if NOT_UI.search(code) and not TEXT_CALL.search(code):
                    continue
                for m in LITERAL.finditer(code):
                    v = m.group(1)
                    bare = re.sub(r"\$\{[^}]*\}|\$\w+", "", v)
                    if not re.search(r"[A-Za-z]{2,}", bare):
                        continue
                    prose = (" " in bare.strip()
                             or re.match(r"^[A-Z][a-z]+", bare)
                             or TEXT_CALL.search(code)
                             or UI_SLOT.search(code[:m.start()]))
                    if not prose:
                        continue
                    if NOT_PROSE.search(v) or (DATE_CALL.search(code) and DATE_PATTERN.fullmatch(v)):
                        continue
                    per_file[rel] += 1
                    hits.append(f"{rel}:{n}: \"{v}\"")
    if verbose:
        print("\n".join(hits))
    print(f"Text(\"...\") calls:        {text_calls}")
    print(f"candidate literals:       {sum(per_file.values())}")
    for k, v in per_file.most_common():
        print(f"  {v:4d}  {k}")


if __name__ == "__main__":
    scan("-v" in sys.argv)
