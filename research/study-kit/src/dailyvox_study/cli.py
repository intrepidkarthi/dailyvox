"""Command line: `dailyvox-study run | combine | synth | selfcheck | build-generic-head`.

Exit codes: 0 ok; 1 selfcheck failed; 2 invalid export or result files;
3 consent mismatch (prereg X1); 4 combine refused (duplicates or mixed
versions); 22 data-freeze interlock (the prereg's own number for "refuses to
score real data before the freeze").
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

from . import __version__
from .protocol import embedding_model_string, protocol_hash


def _cmd_run(args: argparse.Namespace) -> int:
    from .analyze import LeakError
    from .pipeline import run_export
    from .schema import ConsentMismatch, ExportError

    t0 = time.perf_counter()
    try:
        result, text, warnings = run_export(Path(args.export))
    except ExportError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except ConsentMismatch as exc:
        print(f"error (consent, prereg X1): {exc}", file=sys.stderr)
        return 3
    except LeakError as exc:  # should be impossible; refuse to write anything
        print(f"internal error, nothing written: {exc}", file=sys.stderr)
        return 2
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    out = Path(args.output)
    out.write_text(text, encoding="utf-8")
    print(f"Wrote {out} in {time.perf_counter() - t0:.1f}s.")
    print(f"  participant {result['participant_code']} ({result['platform']}), "
          f"{result['n_labelled']} labelled entries ({result['n_voice']} voice, "
          f"{result['n_typed']} typed), status: {result['status']}")
    if result["status"] != "ok":
        print("  Fewer than 35 labelled entries: this file is still worth sending; it is "
              "counted and reported, just not in the main comparison.")
    print("  The file contains numbers only: no entry text, no entry ids, no entry dates.")
    print("  Open it in any text editor to check before you send it. Send ONLY this file.")
    return 0


def _cmd_combine(args: argparse.Namespace) -> int:
    from .combine import (
        FREEZE_EXIT, CombineError, FreezeInterlock, analyse_cohort, check_cohort, check_freeze,
        collect_paths, load_results,
    )
    from .report import render

    try:
        loaded = load_results(collect_paths(args.inputs))
        check_cohort(loaded)
        check_freeze(loaded, args.freeze_date)
    except FreezeInterlock as exc:
        print(f"refused (data-freeze interlock): {exc}", file=sys.stderr)
        return FREEZE_EXIT
    except CombineError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 4 if "refusing" in str(exc) else 2
    strata = json.loads(Path(args.strata).read_text("utf-8")) if args.strata else None
    rep = analyse_cohort([d for _, d in loaded], set(args.p0 or []), strata)
    out = Path(args.output)
    out.write_text(render(rep), encoding="utf-8")
    print(f"Wrote {out}: N25 = {rep['cohort']['N25']}, claim-map row {rep['claim']['row']}.")
    if args.json:
        jpath = out.with_suffix(".json")
        jpath.write_text(json.dumps(rep, indent=2, sort_keys=True, default=str) + "\n", "utf-8")
        print(f"Wrote {jpath}.")
    return 0


def _cmd_synth(args: argparse.Namespace) -> int:
    from .synth import write_synthetic

    paths = write_synthetic(Path(args.output), args.participants, seed=args.seed)
    print(f"Wrote {len(paths)} SYNTHETIC exports to {args.output} (marked \"synthetic\": true).")
    return 0


def _cmd_selfcheck(args: argparse.Namespace) -> int:
    from .selfcheck import selfcheck

    return selfcheck(participants=args.participants,
                     keep=Path(args.keep) if args.keep else None,
                     rebuild=not args.no_rebuild)


def _cmd_build_head(args: argparse.Namespace) -> int:
    from .embed import embed_texts
    from .generic import build_and_cache, cache_path

    head, counts = build_and_cache(embed_texts)
    print(f"generic head: rows={counts} lambda={head.lam:g} val_acc={head.val_accuracy} "
          f"histogram={head.class_histogram}")
    print(f"weights sha256 {head.sha256}; cached at {cache_path()}")
    if args.output:
        Path(args.output).write_text(json.dumps(head.to_json(), sort_keys=True) + "\n", "utf-8")
        print(f"written to {args.output}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="dailyvox-study",
        description="Run the DailyVox K-curve study locally. Your diary text never leaves "
                    "this computer; only the numbers-only result file is meant to be shared.")
    p.add_argument("--version", action="version",
                   version=f"%(prog)s {__version__} (protocol {protocol_hash()[:12]}, "
                           f"{embedding_model_string()})")
    sub = p.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("run", help="analyse your own export and write result.json")
    r.add_argument("export", help="the research export file from the DailyVox app")
    r.add_argument("-o", "--output", default="result.json")
    r.set_defaults(func=_cmd_run)

    c = sub.add_parser("combine", help="pool result files into a cohort report")
    c.add_argument("inputs", nargs="+", help="result files and/or directories of them")
    c.add_argument("-o", "--output", required=True, help="report.md")
    c.add_argument("--json", action="store_true", help="also write the report as JSON")
    c.add_argument("--freeze-date", help="registered data-freeze date YYYY-MM-DD (required "
                   "for real results)")
    c.add_argument("--p0", action="append", help="participant code of P0 (the developer); "
                   "excluded from every confirmatory test (prereg X8)")
    c.add_argument("--strata", help="JSON file mapping participant_code to recruitment stratum")
    c.set_defaults(func=_cmd_combine)

    s = sub.add_parser("synth", help="write SYNTHETIC exports for testing")
    s.add_argument("-o", "--output", required=True)
    s.add_argument("--participants", type=int, default=10)
    s.add_argument("--seed", type=int, default=42)
    s.set_defaults(func=_cmd_synth)

    k = sub.add_parser("selfcheck", help="end-to-end check on synthetic data")
    k.add_argument("--participants", type=int, default=10)
    k.add_argument("--keep", help="directory to keep the synthetic exports, results and report")
    k.add_argument("--no-rebuild", action="store_true",
                   help="skip rebuilding the generic head from GoEmotions")
    k.set_defaults(func=_cmd_selfcheck)

    b = sub.add_parser("build-generic-head", help="rebuild the generic head from pinned GoEmotions")
    b.add_argument("-o", "--output", help="also write the head JSON here")
    b.set_defaults(func=_cmd_build_head)
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
