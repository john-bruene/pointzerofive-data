"""
friday13_pipeline.py
──────────────────────────────────────────────────────────────────────
Data pipeline for story #002 "Are there more road accidents on Friday the 13th?".

Inputs:
  STATS19 collisions 1979 to the latest published year (Department for Transport, Road Safety
      Data, Open Government Licence v3.0). Only needed to rebuild the daily counts; streamed from
      data.dft.gov.uk, or read from a local copy with --stats19 <file>.
  notebooks/raw/stats19/daily_collisions.csv        (written by prep(), committed)
  notebooks/raw/stats19/daily_collisions.meta.json  (provenance of the daily counts)
  notebooks/claims/friday-the-13th.json             (claim and fork texts, hand-written)
Output:
  data/friday-the-13th.json

Run from project root:
    uv run --with pandas --with numpy --with holidays python notebooks/friday13_pipeline.py
    (add --stats19 <file> or --rebuild to recount the days from the raw collisions)

Requires: pandas, numpy, holidays

Method (pitch content/pitches/002-friday-the-13th.md, fixed before the analysis)
  One row per calendar day in Great Britain: collisions with at least one injured person, split
  by severity. Every Friday the 13th is compared with days of the same month (fork comparison),
  for all collisions, killed-or-seriously-injured collisions or fatal collisions (fork outcome),
  with bank holidays in England and Wales left out or kept (fork holidays). The effect and the
  month bootstrap are in friday13_stats.py.
"""

import argparse
import json
import urllib.request
from datetime import date
from pathlib import Path

import holidays as holidays_lib
import numpy as np
import pandas as pd

from friday13_stats import bootstrap, build_design, path_rng, point_estimate, summarize

ROOT = Path(__file__).parent.parent
URL = ("https://data.dft.gov.uk/road-accidents-safety-data/"
       "dft-road-casualty-statistics-collision-1979-latest-published-year.csv")
DAILY = ROOT / "notebooks" / "raw" / "stats19" / "daily_collisions.csv"
DAILY_META = DAILY.with_suffix(".meta.json")
CLAIM = ROOT / "notebooks" / "claims" / "friday-the-13th.json"
OUT = ROOT / "data" / "friday-the-13th.json"

B = 10_000  # bootstrap replicates per calculation path (as in #001)
SEED = 5
FORK_OPTIONS = {
    "comparison": ["all_days", "fridays", "friday_6th"],
    "outcome": ["all", "ksi", "fatal"],
    "holidays": ["exclude", "keep"],
}
PRIMARY = {"comparison": "fridays", "outcome": "all", "holidays": "exclude"}
WEEKDAYS = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]


def prep(source: str) -> None:
    """Count collisions per day and severity (1 fatal, 2 serious, 3 slight) from the raw file."""
    parts, rows, undated = [], 0, 0
    handle = urllib.request.urlopen(source) if source.startswith("https://") else open(source, "rb")
    with handle:
        for chunk in pd.read_csv(handle, usecols=["date", "collision_severity"], dtype=str,
                                 chunksize=1_000_000):
            rows += len(chunk)
            undated += int(chunk.date.isna().sum())
            chunk = chunk.dropna(subset=["date"])
            day = pd.to_datetime(chunk.date, format="%d/%m/%Y")
            sev = chunk.collision_severity.astype(int)
            assert sev.isin([1, 2, 3]).all(), sev.value_counts()
            parts.append(pd.DataFrame({"date": day, "all": 1, "ksi": (sev <= 2).astype(int),
                                       "fatal": (sev == 1).astype(int)})
                         .groupby("date").sum())
    daily = pd.concat(parts).groupby(level=0).sum()
    full = pd.date_range(daily.index.min(), daily.index.max(), freq="D")
    missing = full.difference(daily.index)
    assert len(missing) == 0, f"days without any collision: {list(missing[:5])}"
    assert daily.index.min() == pd.Timestamp(daily.index.min().year, 1, 1)
    assert daily.index.max() == pd.Timestamp(daily.index.max().year, 12, 31)
    assert int(daily["all"].sum()) == rows - undated

    DAILY.parent.mkdir(parents=True, exist_ok=True)
    daily.index.name = "date"
    daily.reset_index().assign(date=lambda x: x.date.dt.strftime("%Y-%m-%d")).to_csv(DAILY, index=False)
    meta = {"source": URL, "license": "Open Government Licence v3.0",
            "accessed": date.today().isoformat(), "rows": rows, "undated": undated}
    DAILY_META.write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    print(f"prep: {rows:,} collisions, {undated} without a date, {len(daily):,} days "
          f"({daily.index.min():%Y-%m-%d} to {daily.index.max():%Y-%m-%d})")


def load_daily() -> pd.DataFrame:
    daily = pd.read_csv(DAILY, parse_dates=["date"])
    daily.index = daily.date.dt.date
    return daily.drop(columns="date")


def bank_holidays(first_year: int, last_year: int) -> set[date]:
    return set(holidays_lib.UK(subdiv="ENG", years=range(first_year, last_year + 1)))


def compute_specs(daily: pd.DataFrame, hol: set[date], forks: list[dict]) -> list[dict]:
    """Every combination of the forks in the claim file, in fork order."""
    ids = [f["id"] for f in forks]
    options = {f["id"]: [o["id"] for o in f["options"]] for f in forks}
    assert ids == list(FORK_OPTIONS) and options == FORK_OPTIONS, (ids, options)
    specs = []
    for comparison in FORK_OPTIONS["comparison"]:
        for outcome in FORK_OPTIONS["outcome"]:
            for holidays in FORK_OPTIONS["holidays"]:
                choices = {"comparison": comparison, "outcome": outcome, "holidays": holidays}
                key = "|".join(f"{f}={choices[f]}" for f in ids)
                d = build_design(daily[outcome], comparison, hol if holidays == "exclude" else None)
                summary = summarize(bootstrap(d, path_rng(SEED, key), B))
                specs.append({"choices": choices, "effect": point_estimate(d), **summary, "n": d.n})
                sp = specs[-1]
                print(f"  {key}: n={sp['n']}, {sp['effect']:+.2f}% "
                      f"[{sp['ci_low']:+.2f}, {sp['ci_high']:+.2f}] p={sp['p']:.4f}")
    return specs


def weekday_profile(daily: pd.DataFrame, hol: set[date], dates13: tuple[date, ...]) -> list[dict]:
    """Mean collisions per day by weekday in the months with a Friday the 13th (holidays and the
    13ths themselves left out), main outcome."""
    months = {(d.year, d.month) for d in dates13}
    days = [d for d in daily.index if (d.year, d.month) in months and d not in hol and d.day != 13]
    s = daily.loc[days, "all"]
    wd = pd.Series([d.weekday() for d in days], index=s.index)
    out = s.groupby(wd.values).agg(["mean", "size"])
    return [{"weekday": WEEKDAYS[i], "mean": round(float(r["mean"]), 1), "days": int(r["size"])}
            for i, r in out.iterrows()]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stats19", help="local copy of the STATS19 collision CSV")
    parser.add_argument("--rebuild", action="store_true", help="recount the days from the raw file")
    args = parser.parse_args()
    if args.stats19 or args.rebuild or not DAILY.exists():
        prep(args.stats19 or URL)

    daily = load_daily()
    first, last = daily.index.min().year, daily.index.max().year
    hol = bank_holidays(first, last)
    raw_meta = json.loads(DAILY_META.read_text(encoding="utf-8"))

    claim_file = json.loads(CLAIM.read_text(encoding="utf-8"))
    primary = {f["id"]: f["primary"] for f in claim_file["forks"]}
    assert primary == PRIMARY, primary
    print("Calculation paths:")
    specs = compute_specs(daily, hol, claim_file["forks"])
    main_spec = next(sp for sp in specs if sp["choices"] == PRIMARY)

    main_design = build_design(daily["all"], "fridays", hol)
    naive_design = build_design(daily["all"], "all_days", hol)
    assert abs(point_estimate(main_design) - main_spec["effect"]) < 1e-12
    all13 = [d for d in build_design(daily["all"], "fridays", None).dates]
    holiday13 = [d for d in all13 if d in hol]
    holiday_controls = sorted(d.replace(day=k) for d in all13 for k in (6, 20)
                              if d.replace(day=k) in hol)

    per_year = daily.groupby([d.year for d in daily.index])["all"].agg(["sum", "size"])
    fridays = [d for d in daily.index if d.weekday() == 4 and d not in hol and d.day != 13]
    weekdays_mean = daily.loc[[d for d in daily.index if d not in hol], "all"].mean()
    pct = 100 * (main_design.y / main_design.c - 1)
    ex = main_design.dates[-1]

    data = {
        "meta": {
            "source": "Department for Transport, Road Safety Data (STATS19), Open Government Licence v3.0",
            "updated": date.today().isoformat(),
            "accessed": raw_meta["accessed"],
            "years": f"{first}–{last}",
            "firstYear": int(first),
            "lastYear": int(last),
            "bootstrap": B,
            "holidaysPackage": holidays_lib.__version__,
        },
        "summary": {
            "collisions": int(daily["all"].sum()),
            "ksi": int(daily["ksi"].sum()),
            "fatal": int(daily["fatal"].sum()),
            "undated": int(raw_meta["undated"]),
            "days": int(len(daily)),
            "fridays13": len(all13),
            "holiday13": [d.isoformat() for d in holiday13],
            "holidayControls": [d.isoformat() for d in holiday_controls],
            "perDayFirstYear": round(float(per_year.loc[first, "sum"] / per_year.loc[first, "size"]), 1),
            "perDayLastYear": round(float(per_year.loc[last, "sum"] / per_year.loc[last, "size"]), 1),
            "fridayVsAverage": round(float(100 * (daily.loc[fridays, "all"].mean() / weekdays_mean - 1)), 2),
        },
        "main": {
            "sum13": int(main_design.y.sum()),
            "sumComparison": round(float(main_design.c.sum()), 1),
            "mean13": round(float(main_design.y.mean()), 1),
            "meanComparison": round(float(main_design.c.mean()), 1),
            "moreCount": int((pct > 0).sum()),
            "fewerCount": int((pct < 0).sum()),
            "naiveMean13": round(float(naive_design.y.mean()), 1),
            "naiveMeanComparison": round(float(naive_design.c.mean()), 1),
        },
        "example": {
            "date": ex.isoformat(),
            "on13": int(daily.loc[ex, "all"]),
            "on6": int(daily.loc[ex.replace(day=6), "all"]),
            "on20": int(daily.loc[ex.replace(day=20), "all"]),
        },
        "weekdays": weekday_profile(daily, hol, main_design.dates),
        "points": [
            {"date": d.isoformat(), "on13": int(y), "comparison": round(float(c), 1),
             "pct": round(float(p), 2)}
            for d, y, c, p in zip(main_design.dates, main_design.y, main_design.c, pct)
        ],
        "claim": claim_file["claim"],
        "forks": claim_file["forks"],
        "specs": specs,
    }
    OUT.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)}")
    print(f"  {data['summary']['collisions']:,} collisions on {len(daily):,} days, "
          f"{len(all13)} Fridays the 13th ({len(holiday13)} bank holidays)")
    print(f"  main: {main_spec['effect']:+.2f}% , 95% range "
          f"[{main_spec['ci_low']:+.2f}, {main_spec['ci_high']:+.2f}], p = {main_spec['p']:.4f}, n = {main_spec['n']}")
    yes = sum(1 for sp in specs if sp["p"] < 0.05 and sp["effect"] > 0)
    print(f"  yes paths: {yes} of {len(specs)}")


if __name__ == "__main__":
    main()
