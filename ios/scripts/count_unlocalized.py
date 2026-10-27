#!/usr/bin/env python3
"""Count user-facing English string literals that bypass localization (B-14).

Usage:
    python3 ios/scripts/count_unlocalized.py [repo-root] [summary|list]

A literal counts when it looks like prose (two or more words, or a capitalised
word) and it is NOT:
  - inside String(localized:), LocalizedStringResource(...), LocalizedStringKey(...)
    or Text(verbatim:) (deliberately unlocalized)
  - the first argument of a SwiftUI initialiser or modifier that takes a
    LocalizedStringKey (Text, Label, Button, Toggle, Section, Picker, TextField,
    Link, Menu, NavigationLink, .navigationTitle, .alert, .confirmationDialog,
    .accessibilityLabel/Hint/Value, .help, ContentUnavailableView, ...);
    Xcode extracts those into the catalog on its own
  - inside a log, print or assertion call
  - a key, identifier, SF Symbol, URL, format, or `comment:` argument
  - inside an `#if DEBUG` block or a preview
  - on a line marked `// i18n-ignore: <reason>` (a deliberate leftover)

Whole files that are debug-only screens, seeders or research export are
counted separately and not in TOTAL (see EXCLUDED_FILES).

This is a heuristic. It is meant to be run before and after an extraction
pass so the two numbers are comparable, not to be an exact census. To count a
commit without checking it out:

    git archive <commit> ios | tar -x -C /tmp/base
    python3 ios/scripts/count_unlocalized.py /tmp/base

Blind spots, to check by hand: enum raw values shown as text
(`case work = "Work"` then `Text(area.rawValue)`), lone lower-case words
("day", "match"), and text that comes from the engine package.
"""
import bisect
import collections
import os
import re
import sys

ROOT = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
MODE = sys.argv[2] if len(sys.argv) > 2 else "summary"
DIRS = ["ios/solyn", "ios/SolynWidget"]

EXCLUDED_FILES = {
    # Debug-only screens and seeders (Settings > Developer, App Store screenshots)
    "MemoryProbe.swift": "debug-only memory probe",
    "MemoryProbeView.swift": "debug-only memory probe screen",
    "SpeechLocaleProbe.swift": "debug-only speech locale probe",
    "SpeechLocaleProbeView.swift": "debug-only speech locale probe screen",
    "ScreenshotDataSeeder.swift": "App Store screenshot seed data",
    "ScreenshotScene.swift": "App Store screenshot scenes",
    # Research export: column names and codes are a data contract, not UI
    "ResearchExport.swift": "research export column names",
}

LOCALIZED_OPEN = re.compile(
    r"(String\(localized:|LocalizedStringResource\(|LocalizedStringKey\(|"
    r"String\.LocalizationValue\(|Text\(verbatim:|localizedStringResource:)"
)
KEY_INITS = re.compile(
    r"((?<![\w.])(Text|Label|Button|Toggle|Section|Picker|TextField|SecureField|Link|"
    r"Menu|NavigationLink|Stepper|DatePicker|LabeledContent|ContentUnavailableView|"
    r"ProgressView|Tab|ControlGroup|GroupBox|DisclosureGroup)"
    r"|\.(navigationTitle|navigationBarTitle|alert|confirmationDialog|accessibilityLabel|"
    r"accessibilityHint|accessibilityValue|help|badge|searchable|configurationDisplayName|"
    r"description|displayName))"
    r"\(\s*$"
)
# App Intents and WidgetKit parameters typed LocalizedStringResource / LocalizedStringKey
RESOURCE_ARGS = re.compile(
    r"((?<![\w.])(IntentDescription|IntentDialog|Summary|AppShortcut|ControlWidgetButton|Parameter)\("
    r"|\b(dialog|phrases|requestValueDialog)\s*:\s*\[?)\s*$"
    r"|static var (title|description)\b[^=]*=\s*$"
)
SKIP_CONTEXT = re.compile(
    r"(print\(|debugPrint\(|Logger\(|logger\.|\blog\.|\blog\(|os_log|NSLog|fatalError\(|"
    r"assert|precondition|dvLog|forKey:|@AppStorage\(|systemImage:|systemName:|"
    r"Image\(|UIImage\(|Color\(|named:|identifier:|withIdentifier|NSPredicate|"
    r"comment:\s*$|domain:\s*$|let kind\b[^=]*=\s*$|URL\(string:|appendingPathComponent|"
    r"forResource|Notification\.Name\(|entityName|UTType|kind:\s*$|"
    r"\bcase\s+\w+\s*=\s*$|dateFormat\s*=|setLocalizedDateFormatFromTemplate)"
)
# A deliberate leftover carries this marker and a reason on the same line,
# e.g. `"Inter-Regular"  // i18n-ignore: font name`.
IGNORE_MARK = "i18n-ignore"
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')


def strip_comments(src: str) -> str:
    """Blank out // and /* */ comments, keeping string literals and line numbers."""
    out, i, n = [], 0, len(src)
    in_str = False
    while i < n:
        c = src[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(src[i + 1])
                i += 2
                continue
            if c == '"' or c == "\n":
                in_str = False
            i += 1
            continue
        if src.startswith('"""', i):
            j = src.find('"""', i + 3)
            j = n if j < 0 else j + 3
            out.append(src[i:j])
            i = j
            continue
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append("\n" * src[i:j].count("\n"))
            i = j
            continue
        if c == '"':
            in_str = True
        out.append(c)
        i += 1
    return "".join(out)


def is_prose(s: str) -> bool:
    t = re.sub(r"\\\((?:[^()]|\((?:[^()]|\([^()]*\))*\))*\)", " X ", s)  # \(...) with nesting
    t = re.sub(r"\\u\{[0-9a-fA-F]+\}", " ", t).strip()
    if not t:
        return False
    if re.match(r"^(https?:|mailto:|com\.|group\.|[a-z]+\.[a-z])", t):
        return False
    if " " not in re.sub(r"\s*\bX\b\s*", "", t).strip() and re.search(r"\.[A-Za-z]{2,4}$", t):
        return False  # file name
    if "\\(" in s and any(re.fullmatch(r"[A-Za-z][A-Za-z'’]+[.,:;!?…]*", tok) for tok in t.split()):
        return True  # interpolated count or value next to a word: "\(n) waiting"
    if re.fullmatch(r"[a-z][A-Za-z0-9]*([._\-/][A-Za-z0-9]+)*", t):
        return False  # camelCase, dotted.key, snake_case
    if re.fullmatch(r"[\w.\-/:%@#]*", t) and not re.match(r"^[A-Z][a-z]{2,}", t):
        return False  # identifier-ish
    if re.fullmatch(r"[A-Z0-9_]+", t) and len(t) <= 3:
        return False
    words = re.findall(r"[A-Za-z]{2,}", t)
    if not words:
        return False
    if len(words) >= 2 and " " in t:
        return True
    return bool(re.match(r"^[A-Z][a-z]+", t) or re.fullmatch(r"[A-Z]{4,}", t))


def debug_lines(lines):
    flags, stack = [], []
    for line in lines:
        s = line.strip()
        if s.startswith("#if"):
            stack.append("DEBUG" in s and "!" not in s)
        elif s.startswith("#else") and stack:
            stack[-1] = False
        elif s.startswith("#endif") and stack:
            stack.pop()
        flags.append(any(stack))
    return flags


def innermost_call(before: str) -> str:
    """Text just before the innermost '(' or '[' still open at the end of `before`."""
    depth = 0
    in_str = False
    for i in range(len(before) - 1, -1, -1):
        c = before[i]
        if c == '"':
            in_str = not in_str
            continue
        if in_str:
            continue
        if c in ")]":
            depth += 1
        elif c in "([":
            if depth == 0:
                # A bare grouping paren, as in `a ? "x" : ("y")`, is not a call:
                # keep looking outward for the call it sits in.
                if c == "(" and not re.search(r"[\w!>\]]\s*$", before[:i]) or \
                        (c == "(" and re.search(r"[?:]\s*$", before[:i])):
                    continue
                return before[:i + 1]
            depth -= 1
    return ""


def preview_lines(lines):
    """Lines inside #Preview { } or a PreviewProvider type."""
    flags = [False] * len(lines)
    i = 0
    while i < len(lines):
        if re.match(r"\s*#Preview\b", lines[i]) or "PreviewProvider" in lines[i]:
            depth, started, j = 0, False, i
            while j < len(lines):
                depth += lines[j].count("{") - lines[j].count("}")
                started = started or "{" in lines[j]
                flags[j] = True
                if started and depth <= 0:
                    break
                j += 1
            i = j + 1
            continue
        i += 1
    return flags


def scan(path):
    raw = open(path, encoding="utf-8").read()
    raw_lines = raw.split("\n")
    src = strip_comments(raw)
    lines = src.split("\n")
    dbg = debug_lines(lines)
    prev = preview_lines(lines)
    starts, pos = [], 0
    for line in lines:
        starts.append(pos)
        pos += len(line) + 1
    hits = []
    for m in LITERAL.finditer(src):
        s = m.group(1)
        if not is_prose(s):
            continue
        ln = bisect.bisect_right(starts, m.start()) - 1
        if dbg[ln] or prev[ln]:
            continue
        if IGNORE_MARK in raw_lines[ln]:
            continue
        before = src[max(0, m.start() - 600):m.start()]
        line_before = src[starts[ln]:m.start()]
        # inside a localized call that is still open on this or the previous lines
        last_open = max(before.rfind("String(localized:"), before.rfind("LocalizedStringResource("),
                        before.rfind("LocalizedStringKey("), before.rfind("Text(verbatim:"))
        if last_open >= 0 and before[last_open:].count("(") > before[last_open:].count(")"):
            continue
        if LOCALIZED_OPEN.search(line_before):
            continue
        call = innermost_call(before)
        if KEY_INITS.search(before) or (call and KEY_INITS.search(call)):
            continue
        if RESOURCE_ARGS.search(before) or (call and RESOURCE_ARGS.search(call)):
            continue
        # ternary between two literals as the argument of a localizing call
        tern = re.search(r"\?\s*$|:\s*$", before)
        if tern and call and (KEY_INITS.search(call) or RESOURCE_ARGS.search(call)):
            continue
        if SKIP_CONTEXT.search(line_before) or SKIP_CONTEXT.search(before[-60:]):
            continue
        hits.append((ln + 1, s))
    return hits


def main():
    per = collections.Counter()
    excluded = collections.Counter()
    listing = []
    for d in DIRS:
        for dp, _, files in os.walk(os.path.join(ROOT, d)):
            for f in sorted(files):
                if not f.endswith(".swift"):
                    continue
                p = os.path.join(dp, f)
                rel = os.path.relpath(p, ROOT)
                hits = scan(p)
                if f in EXCLUDED_FILES:
                    excluded[rel] += len(hits)
                    continue
                per[rel] += len(hits)
                listing += [f"{rel}:{ln}: {s}" for ln, s in hits]
    if MODE == "list":
        print("\n".join(listing))
        return
    for rel, n in per.most_common():
        if n:
            print(f"{n:5d}  {rel}")
    print(f"TOTAL {sum(per.values())}")
    print(f"excluded (debug / screenshot / research files): {sum(excluded.values())}")
    for rel, n in excluded.most_common():
        print(f"{n:5d}  {rel}  [{EXCLUDED_FILES[os.path.basename(rel)]}]")


if __name__ == "__main__":
    main()
