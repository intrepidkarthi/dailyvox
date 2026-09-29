#!/usr/bin/env python3
"""Check what the Play submission documents CLAIM against what the build DOES.

Every number in this directory was written by hand and most of them were wrong:

    DATA_SAFETY.md    listed USE_FINGERPRINT (removed from the manifest) and
                      omitted DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION, in the
                      one file that is a binding declaration to Google
    SUBMISSION_RUNBOOK  "36 app unit tests"   -> 46
                        "51 engine tests"     -> 58
                        "5.2 MB AAB"          -> 5.32
                        "4.9 MB universal APK"-> 4.77
    STORE_LISTING     short description 72    -> 73
                      full description ~3,050 -> 3,880

They were not wrong when written. They rotted, silently, because nothing read
them. This does.

    python3 playstore/verify.py

Exits 1 on any mismatch a machine can settle. Numbers it cannot settle (dated
"what shipped" records) it prints, so they can be pasted rather than guessed.
"""
import glob
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ANDROID = os.path.dirname(HERE)
ROOT = os.path.dirname(ANDROID)
fail = 0


def say(ok, label, detail=""):
    global fail
    if not ok:
        fail += 1
    print(f"  [{'ok  ' if ok else 'FAIL'}] {label}" + (f"  {detail}" if detail else ""))


def aapt2():
    c = sorted(glob.glob(os.path.expanduser("~/Library/Android/sdk/build-tools/*/aapt2")))
    return c[-1] if c else None


def apk():
    c = glob.glob(f"{ANDROID}/app/build/outputs/apk/release/*.apk")
    return c[0] if c else None


def check_permissions():
    """The highest-stakes claim in the directory, so it is checked against the
    artifact rather than the source: what ships is what a reviewer inspects."""
    print("\nDATA_SAFETY.md permission list vs the built APK")
    tool, a = aapt2(), apk()
    if not tool or not a:
        say(False, "cannot check", "no aapt2 or no release APK — run :app:assembleRelease")
        return
    out = subprocess.run([tool, "dump", "permissions", a], capture_output=True, text=True).stdout
    real = sorted(set(re.findall(r"uses-permission: name='([^']+)'", out)))
    doc = sorted(set(re.findall(r"uses-permission: name='([^']+)'", open(f"{HERE}/DATA_SAFETY.md").read())))
    say(real == doc, f"{len(real)} permissions in the APK")
    for p in sorted(set(doc) - set(real)):
        say(False, "claimed but NOT in the APK", p)
    for p in sorted(set(real) - set(doc)):
        say(False, "in the APK but NOT documented", p)
    # The product's central claim, and the cheapest thing in the world to check.
    say(not any("INTERNET" in p for p in real), "no INTERNET permission")


def check_listing():
    print("\nSTORE_LISTING.md field lengths vs Play's limits")
    text = open(f"{HERE}/STORE_LISTING.md").read()
    limits = {"App name": 30, "Short description": 80, "Full description": 4000}
    found = {}
    for m in re.finditer(r"##\s*([^\n(]+?)\s*(?:\([^)]*\))?\n(.*?)```\n(.*?)\n```", text, re.S):
        if m.group(1).strip() in limits:
            found[m.group(1).strip()] = m.group(3)
    for name, limit in limits.items():
        if name not in found:
            say(False, f"{name} not found in the document")
            continue
        body = found[name]
        n = len(body)
        say(n <= limit, f"{name:18} {n:>5} / {limit}",
            "" if n <= limit else f"{n - limit} OVER — Play rejects at upload")
        # ECHO WHAT WAS MEASURED. A bare number invites the reader to attach it
        # to the wrong string: the commentary under "Short description" was once
        # read as the field itself (112 chars, and it would have been rejected),
        # because prose sat between the heading and the fence. A count with no
        # subject is exactly as useful as no count.
        shown = body if n <= 90 else body[:60].replace("\n", " ") + " … " + body[-25:].replace("\n", " ")
        print(f"           measured: |{shown}|")

    # Guard the layout that caused that misreading in the first place: the value
    # should follow its heading almost immediately, with the explanation after.
    for m in re.finditer(r"##\s*([^\n(]+?)\s*(?:\([^)]*\))?\n(.*?)```", text, re.S):
        label, gap = m.group(1).strip(), m.group(2)
        if label in limits and len(gap.strip()) > 40:
            say(False, f"{label}: {len(gap.strip())} chars of prose sit between the "
                       "heading and the fence — put the value first, commentary after")


def check_source_claims():
    """Listing and permission text that describes a default or a feature. Each
    of these shipped wrong once: the docs said the reminder and the lock were
    off by default while MainActivity turned both on, and the listing sold
    photo attachments that no button in the app could reach."""
    print("\nListing / permission claims vs the source")
    main = open(f"{ANDROID}/app/src/main/kotlin/com/dailyvox/app/MainActivity.kt").read()
    perms = open(f"{HERE}/PERMISSIONS.md").read()
    listing = open(f"{HERE}/STORE_LISTING.md").read()
    src = "".join(open(f).read() for f in glob.glob(
        f"{ANDROID}/app/src/main/kotlin/**/*.kt", recursive=True))

    reminder_on = bool(re.search(r"Reminders\.PREF_ENABLED,\s*true", main))
    doc_says_off = bool(re.search(r"reminder.{0,80}(defaults to off|off until)", perms, re.S | re.I))
    say(reminder_on != doc_says_off, f"reminder default ({'on' if reminder_on else 'off'}) matches PERMISSIONS.md")

    lock_on = 'getBoolean("lock", lockAvailableNow)' in main
    lock_doc_off = "lock is off by default" in perms
    say(not (lock_on and lock_doc_off), f"app-lock default ({'on' if lock_on else 'off'}) matches PERMISSIONS.md")

    photos_reachable = "pickPhoto.launch" in src
    photos_sold = bool(re.search(r"photo", listing.split("## Full description", 1)[-1], re.I))
    say(photos_reachable or not photos_sold, "listing does not sell unreachable photo attachments")


def counts():
    """Not pass/fail: the authoritative numbers for a dated record."""
    print("\nCurrent build facts — paste these, do not recall them")

    def tests(pattern, label):
        t = f = 0
        for p in glob.glob(pattern):
            s = open(p).read()
            m = re.search(r'tests="(\d+)".*?failures="(\d+)".*?errors="(\d+)"', s)
            if m:
                t += int(m.group(1)); f += int(m.group(2)) + int(m.group(3))
        print(f"    {label:22} {t} tests, {f} failing" if t else f"    {label:22} not run")

    tests(f"{ANDROID}/app/build/test-results/testDebugUnitTest/*.xml", "app unit tests")
    tests(f"{ROOT}/DailyVoxTwin/kotlin/engine/build/test-results/test/*.xml", "engine tests")
    for pat, label in ((f"{ANDROID}/app/build/outputs/apk/release/*.apk", "release APK"),
                       (f"{ANDROID}/app/build/outputs/bundle/release/*.aab", "release AAB")):
        for f_ in glob.glob(pat):
            print(f"    {label:22} {os.path.getsize(f_)/1048576:.2f} MB")


if __name__ == "__main__":
    check_permissions()
    check_listing()
    check_source_claims()
    counts()
    print()
    print(f"FAIL  {fail} mismatch(es)" if fail else "PASS  documents match the build")
    sys.exit(1 if fail else 0)
