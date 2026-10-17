# friday13_holidays.py
# ──────────────────────────────────────────────────────────────────────
# Writes the bank holidays of England and Wales for story #002 (Friday the 13th) as a small table,
# so that the R pipeline needs no holiday package:
#   notebooks/raw/stats19/bank_holidays_eng.csv   date, name
#   notebooks/raw/stats19/bank_holidays_eng.meta.json   version of the Python package holidays
#
# Run from project root:  python3 notebooks/friday13_holidays.py [first year] [last year]
# Requires: Python 3 with holidays.
# ──────────────────────────────────────────────────────────────────────

import csv
import json
import sys
from pathlib import Path

import holidays

OUT = Path("notebooks") / "raw" / "stats19" / "bank_holidays_eng.csv"


def main(first: int, last: int) -> None:
    days = holidays.UK(subdiv="ENG", years=range(first, last + 1))
    with OUT.open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["date", "name"])
        for d in sorted(days):
            w.writerow([d.isoformat(), days[d]])
    meta = {"package": "holidays", "version": holidays.__version__, "subdiv": "ENG",
            "years": [first, last]}
    OUT.with_suffix(".meta.json").write_text(json.dumps(meta, indent=1) + "\n", encoding="utf-8")
    print(f"{OUT}: {len(days)} days, holidays {holidays.__version__}")


if __name__ == "__main__":
    a = sys.argv[1:]
    main(int(a[0]) if a else 1979, int(a[1]) if len(a) > 1 else 2025)
