#!/usr/bin/env python3
"""Set the app versions shown on the site, everywhere they appear.

    python3 website/set_version.py --ios 1.13 --android 1.2

The top-bar badge and the footer on every page name both platforms, because
they are separate version lines: a bare "v1.11.0" once sat on 166 pages and
read, to an Android visitor, as "your app is behind". These were hand-edited
before and drifted; this rewrites them from one pair of numbers.

Also updates the SoftwareApplication `softwareVersion` (one number, the iPhone
app's, which is what that field describes) and the "latest version" lines in
llms.txt, llms-full.txt, facts.html and the blog index. Prose about what a
release contains (changelog, roadmap) is still written by hand.
"""
import argparse
import pathlib
import re

PUBLIC = pathlib.Path(__file__).resolve().parent / "public"

RULES = [
    # footer, every page
    (r"&middot; iOS [\d.]+ &middot; Android [\d.]+ &middot; built on-device",
     "&middot; iOS {ios} &middot; Android {android} &middot; built on-device"),
    # top-bar badge
    (r'class="ver" title="Release history">iOS [\d.]+ &middot; Android [\d.]+</a>',
     'class="ver" title="Release history">iOS {ios} &middot; Android {android}</a>'),
    # schema.org
    (r'("softwareVersion":\s*)"[\d.]+"', r'\g<1>"{ios_full}"'),
    # "latest" lines
    (r"Latest: v[\d.]+ on iPhone &middot; v[\d.]+ on Android",
     "Latest: v{ios} on iPhone &middot; v{android} on Android"),
    (r"Current version: [\d.]+ on iPhone; [\d.]+ on Android",
     "Current version: {ios} on iPhone; {android} on Android"),
    (r"- Latest version: [\d.]+ on iPhone; [\d.]+ on Android",
     "- Latest version: {ios} on iPhone; {android} on Android"),
    (r"\*\*Current Version\*\*: [\d.]+ on iPhone; [\d.]+ on Android",
     "**Current Version**: {ios_full} on iPhone; {android} on Android"),
]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ios", required=True, help="e.g. 1.13 (shown); 1.13.0 is derived for schema")
    ap.add_argument("--android", required=True, help="e.g. 1.2")
    a = ap.parse_args()
    ios = a.ios.rstrip(".0") if a.ios.count(".") > 1 and a.ios.endswith(".0") else a.ios
    ios_full = ios if ios.count(".") >= 2 else ios + ".0"
    vals = dict(ios=ios, ios_full=ios_full, android=a.android)
    changed = 0
    for f in sorted(PUBLIC.rglob("*")):
        if f.suffix not in (".html", ".txt") or not f.is_file():
            continue
        s = f.read_text(encoding="utf-8")
        t = s
        for pat, rep in RULES:
            t = re.sub(pat, rep.format(**vals), t)
        if t != s:
            f.write_text(t, encoding="utf-8")
            changed += 1
    print(f"set iOS {ios} / Android {a.android} in {changed} files")


if __name__ == "__main__":
    main()
