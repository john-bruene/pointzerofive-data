# friday13_prep.py
# ──────────────────────────────────────────────────────────────────────
# Counts the STATS19 collisions per day and severity for story #002 (Friday the 13th).
#
# Input: STATS19 collisions 1979 to the latest published year (Department for Transport, Road
#   Safety Data, Open Government Licence v3.0), streamed from data.dft.gov.uk or read from a local
#   copy given as the first argument.
# Outputs:
#   notebooks/raw/stats19/daily_collisions.csv        date, all, ksi, fatal
#   notebooks/raw/stats19/daily_collisions.meta.json  source, licence, access date, row counts
#
# Run from project root:  python3 notebooks/friday13_prep.py [local copy of the CSV]
# Requires: Python 3 with pandas. The analysis is notebooks/friday13_pipeline.R.
# ──────────────────────────────────────────────────────────────────────

import json
import sys
import urllib.request
from datetime import date
from pathlib import Path

import pandas as pd

URL = ("https://data.dft.gov.uk/road-accidents-safety-data/"
       "dft-road-casualty-statistics-collision-1979-latest-published-year.csv")
DAILY = Path("notebooks") / "raw" / "stats19" / "daily_collisions.csv"
DAILY_META = DAILY.with_suffix(".meta.json")


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
    assert int(daily["all"].sum()) == rows - undated

    DAILY.parent.mkdir(parents=True, exist_ok=True)
    daily.index.name = "date"
    daily.reset_index().assign(date=lambda x: x.date.dt.strftime("%Y-%m-%d")).to_csv(DAILY, index=False)
    meta = {"source": URL, "license": "Open Government Licence v3.0",
            "accessed": date.today().isoformat(), "rows": rows, "undated": undated}
    DAILY_META.write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    print(f"prep: {rows:,} collisions, {undated} without a date, {len(daily):,} days")


if __name__ == "__main__":
    prep(sys.argv[1] if len(sys.argv) > 1 else URL)
