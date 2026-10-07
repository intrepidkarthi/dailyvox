"""End-to-end selfcheck: synth -> run -> combine, plus the null-collapse gate.

WHY: the pre-registration (precondition P12) forbids treating any number as
claim-bearing until the whole registered pipeline has executed end to end on
synthetic personas. This command is that execution, runnable by anyone on
their own laptop. It fails (non-zero exit) if any of these break:

  1. the generic head rebuilt from the pinned GoEmotions files matches the
     shipped head (predictions identical on the synthetic test rows);
  2. every synthetic export runs and passes the no-leak check;
  3. a re-run of one export is byte-identical apart from created_at;
  4. `combine` runs and its duplicate refusal fires on a duplicated file;
  5. the permutation null collapses on synthetic data (uniform labels):
     mean null Delta-acc near 0 and null win-rate below one half;
  6. a cohort whose labels are shuffled across entries shows no lift
     (mean Delta-acc near 0) and accuracy near chance;
  7. with round-1 results only, combine reports Step 4 as unrunnable and why;
  8. the full two-round flow (run -> weights -> donors -> run --donors ->
     combine) on two contrasting cohorts: H3b must be RETAINED where each
     persona has private cues (personal signal) and NOT retained where every
     persona shares the same cues (register-only signal);
  9. round 2 refuses an export that differs from the round-1 file.
It also prints how closely the head-built donor arms match the prereg's
row-level refits on synthetic data (informational, cited in DEVIATIONS.md).

Why the collapse band is asymmetric (no lift above +2 pts, but down to -6 / -8
pts allowed): with shuffled labels a person's adaptation pool and test tail are
drawn WITHOUT replacement from one fixed multiset of labels, so the classes
over-represented in the pool are under-represented in the test tail. A head
that learns the pool's label frequencies is therefore slightly WORSE than
chance on the tail. A small negative null is the expected finite-population
signature; a positive one would mean the pipeline leaks the test window.
"""

from __future__ import annotations

import json
import shutil
import tempfile
import time
from pathlib import Path

import numpy as np

from .combine import CombineError, analyse_cohort, check_cohort, load_results
from .generic import build_and_cache, get_generic_head
from .heads import add_bias, predict
from .pipeline import run_export
from .report import render
from .synth import make_persona_export, shuffle_labels, write_synthetic
from .tworound import approximation_check, run_two_round

# Two-round cohorts: everyone at or above 35 entries so N25 = 10.
TWO_ROUND_COUNTS = (60, 70, 45, 60, 85, 60, 55, 60, 40, 100)

LIFT_MAX = 0.02            # no positive lift under the null
NULL_DELTA_MIN = -0.06
SHUFFLED_DELTA_MIN = -0.08
SHUFFLED_ACC_MAX = 0.30


def collapsed(mean_delta: float, floor: float) -> bool:
    return floor <= mean_delta <= LIFT_MAX


def selfcheck(participants: int = 10, keep: Path | None = None, rebuild: bool = True) -> int:
    from .embed import embed_texts, load_model

    failures: list[str] = []
    work = Path(tempfile.mkdtemp(prefix="dailyvox-selfcheck-"))
    try:
        t0 = time.perf_counter()
        load_model()
        print(f"[1/11] embedding model loaded ({time.perf_counter() - t0:.1f}s)")
        head = get_generic_head(embed_texts)
        print(f"      generic head: source={head.source} lambda={head.lam:g} rows={head.n_rows} "
              f"sha256={head.sha256[:16]}...")

        if rebuild:
            t0 = time.perf_counter()
            rebuilt, counts = build_and_cache(embed_texts)
            probe_doc = make_persona_export(0, 60)
            Xb = add_bias(embed_texts([e["text"] for e in probe_doc["entries"]]))
            agree = float(np.mean(predict(Xb, rebuilt.W) == predict(Xb, head.W)))
            maxdiff = float(np.max(np.abs(rebuilt.W - head.W)))
            print(f"[2/11] generic head rebuilt from pinned GoEmotions in "
                  f"{time.perf_counter() - t0:.1f}s: rows={counts}, lambda={rebuilt.lam:g}, "
                  f"max|dW|={maxdiff:.2e}, prediction agreement={agree:.3f}, "
                  f"identical bytes={rebuilt.sha256 == head.sha256}")
            if agree < 1.0 or rebuilt.lam != head.lam:
                failures.append("rebuilt generic head disagrees with the shipped head")
        else:
            print("[2/11] generic head rebuild skipped")

        exports = write_synthetic(work / "exports", participants)
        results_dir = work / "results"
        results_dir.mkdir()
        times = []
        for p in exports:
            t0 = time.perf_counter()
            result, text, _ = run_export(p, head=head)
            times.append(time.perf_counter() - t0)
            (results_dir / f"result-{result['participant_code']}.json").write_text(text, "utf-8")
        print(f"[3/11] ran {len(exports)} synthetic participants: per participant "
              f"median {np.median(times):.2f}s, max {max(times):.2f}s (model already loaded)")

        _, again, _ = run_export(exports[0], head=head)
        first = json.loads((results_dir / f"result-{json.loads(again)['participant_code']}.json")
                           .read_text("utf-8"))
        second = json.loads(again)
        first.pop("created_at")
        second.pop("created_at")
        same = json.dumps(first, sort_keys=True) == json.dumps(second, sort_keys=True)
        print(f"[4/11] deterministic re-run identical apart from created_at: {same}")
        if not same:
            failures.append("re-run was not byte-identical")

        loaded = load_results(sorted(results_dir.glob("*.json")))
        check_cohort(loaded)
        rep = analyse_cohort([d for _, d in loaded])
        report_md = render(rep)
        (work / "report.md").write_text(report_md, "utf-8")
        dup = results_dir / "duplicate.json"
        shutil.copy(sorted(results_dir.glob("result-*.json"))[0], dup)
        try:
            check_cohort(load_results(sorted(results_dir.glob("*.json"))))
            failures.append("combine accepted a duplicated result file")
            refused = False
        except CombineError:
            refused = True
        dup.unlink()
        s1 = rep["steps"]["step1"]
        print(f"[5/11] combine: N25={rep['cohort']['N25']} N10={rep['cohort']['N10']} "
              f"mean Delta(K=25)={s1['mean_delta'] * 100:+.1f} pts, Step 1 p={s1['p']:.4g}, "
              f"wins={rep['steps']['step2']['wins']}/{rep['cohort']['N25']}, claim row "
              f"{rep['claim']['row']}; duplicate refused: {refused}")

        nl = rep["null"]
        null_ok = (collapsed(nl["mean_null_delta_primary_over_permutations"], NULL_DELTA_MIN)
                   and nl["null_win_rate_mean"] < 0.5)
        print(f"[6/11] permutation null: mean null Delta={nl['mean_null_delta_primary_over_permutations'] * 100:+.2f} pts "
              f"(band {NULL_DELTA_MIN * 100:+.0f} to {LIFT_MAX * 100:+.0f}), "
              f"null win-rate={nl['null_win_rate_mean']:.3f} "
              f"(must be < 0.5): {'OK' if null_ok else 'FAIL'}")
        if not null_ok:
            failures.append("permutation null did not collapse on synthetic data")

        shuf_dir = work / "shuffled"
        shuf_dir.mkdir()
        deltas, accs = [], []
        for i, p in enumerate(exports):
            doc = json.loads(p.read_text("utf-8"))
            sp = shuf_dir / p.name
            sp.write_text(json.dumps(shuffle_labels(doc, 1000 + i)), "utf-8")
            r, _, _ = run_export(sp, head=head)
            if r["status"] == "ok":
                deltas.append(r["delta_primary"])
                accs.append(r["acc"]["k25"])
        md, ma = float(np.mean(deltas)), float(np.mean(accs))
        shuf_ok = collapsed(md, SHUFFLED_DELTA_MIN) and ma <= SHUFFLED_ACC_MAX
        print(f"[7/11] label-shuffled cohort (n={len(deltas)}): mean Delta={md * 100:+.2f} pts "
              f"(band {SHUFFLED_DELTA_MIN * 100:+.0f} to {LIFT_MAX * 100:+.0f}), "
              f"mean acc K=25={ma * 100:.1f}% "
              f"(chance 14.3%, must be <= {SHUFFLED_ACC_MAX * 100:.0f}%): "
              f"{'OK' if shuf_ok else 'FAIL'}")
        if not shuf_ok:
            failures.append("shuffled-label cohort did not collapse")

        # --- two-round donor arms ---------------------------------------------------
        s4 = rep["steps"]["step4"]
        r1_ok = (not s4["runnable"]) and "only round-1" in s4["reason"] and rep["claim"]["row"] in (
            "3", "4", "4b", "5", "6", "7", "8", "9", "10")
        print(f"[8/11] round-1-only combine: Step 4 unrunnable with reason given, claim row "
              f"{rep['claim']['row']}: {'OK' if r1_ok else 'FAIL'}")
        if not r1_ok:
            failures.append("round-1-only combine did not report Step 4 as unrunnable with a reason")

        verdicts = {}
        for name, shared in (("personal-signal", False), ("register-only", True)):
            t0 = time.perf_counter()
            cohort = write_synthetic(work / name / "exports", 10, counts=TWO_ROUND_COUNTS,
                                     shared_mapping=shared)
            tr = run_two_round(cohort, head, work / name)
            r2 = tr["report"]
            st4 = r2["steps"]["step4"]
            verdicts[name] = st4
            (work / f"report-{name}.md").write_text(render(r2), "utf-8")
            print(f"[{9 if not shared else 10}/11] two-round {name} cohort (N25={r2['cohort']['N25']}, "
                  f"{time.perf_counter() - t0:.1f}s): Step 1 mean Delta vs generic "
                  f"{r2['steps']['step1']['mean_delta'] * 100:+.1f} pts; H3b mean(personal - "
                  f"donorPlusPrior) {st4['mean_delta'] * 100:+.1f} pts, p={st4['p']:.4g}, "
                  f"upper95 {st4['upper_95_bootstrap'] * 100:+.1f} pts -> VERDICT "
                  f"{st4['verdict']}; pooledLOPO >= personal for "
                  f"{st4['pooled_lopo_ge_personalized_count']}/{r2['cohort']['N25']}; claim row "
                  f"{r2['claim']['row']}")
        h3b_ok = (verdicts["personal-signal"]["verdict"] == "retained"
                  and verdicts["register-only"]["verdict"] != "retained")
        if not h3b_ok:
            failures.append("H3b did not separate the personal-signal cohort (expected retained) "
                            "from the register-only cohort (expected not retained)")

        # round 2 must refuse an export that is not the round-1 file
        from .pipeline import run_export_full
        from .weights import DonorError
        cohort_dir = work / "personal-signal"
        some_donor = sorted((cohort_dir / "donors").glob("donors-DV-*.json"))[0]
        code = json.loads(some_donor.read_text("utf-8"))["participant_code"]
        export = next(p for p in sorted((cohort_dir / "exports").glob("*.json")) if code in p.name)
        tampered = work / "tampered.json"
        doc = json.loads(export.read_text("utf-8"))
        doc["entries"][0]["self_label"] = ("joy" if doc["entries"][0]["self_label"] != "joy"
                                           else "fear")
        tampered.write_text(json.dumps(doc), "utf-8")
        try:
            run_export_full(tampered, head=head, donors_path=some_donor)
            refused2 = False
            failures.append("round 2 accepted an export that differs from round 1")
        except DonorError:
            refused2 = True
        approx = approximation_check(
            sorted((work / "register-only" / "exports").glob("*.json")), head, embed_texts)
        print(f"[11/11] round 2 refuses a changed export: {refused2}; head-built vs row-level "
              f"refit agreement on test predictions (register-only cohort): donor "
              f"{approx['donor_agreement']:.3f}, pooledLOPO {approx['pooled_agreement']:.3f} "
              f"(acc exact/heads: donor {approx['acc_donor_exact']:.3f}/"
              f"{approx['acc_donor_heads']:.3f}, pooled {approx['acc_pooled_exact']:.3f}/"
              f"{approx['acc_pooled_heads']:.3f})")
        if keep:
            keep.mkdir(parents=True, exist_ok=True)
            for sub in ("exports", "results"):
                shutil.copytree(work / sub, keep / sub, dirs_exist_ok=True)
            for rp in work.glob("report*.md"):
                shutil.copy(rp, keep / rp.name)
            for name in ("personal-signal", "register-only"):
                shutil.copytree(work / name, keep / name, dirs_exist_ok=True)
            print(f"      artefacts kept in {keep}")
    finally:
        shutil.rmtree(work, ignore_errors=True)
    if failures:
        print("SELFCHECK FAILED:\n  - " + "\n  - ".join(failures))
        return 1
    print("SELFCHECK PASSED")
    return 0
