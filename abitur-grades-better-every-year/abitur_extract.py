# abitur_extract.py
# ──────────────────────────────────────────────────────────────────────
# Reads the KMK files "Abiturnoten im Ländervergleich" 2014 to 2025 (sheet "Noten") for story #005
# "Are Abitur grades getting better every year?" (pitch: content/pitches/005-abitur-grades-better-every-year.md)
# and writes one row per Land and year, unedited.
#
# Inputs:  content/incoming/abitur/kmk_<year>.xls / .xlsx (downloaded from kmk.org on 2026-10-16;
#          URLs in the pitch and in the data-repository README)
# Output:  notebooks/raw/abitur/kmk_abitur.csv
#          year, land, exams, passed, failed, mean, previous_year (1 if the KMK marks the column as
#          the previous year's values), n_1_0 … n_4_0 (number of passes per grade)
#
# Run from project root:  python3 notebooks/abitur_extract.py
# Requires: pandas, xlrd (for .xls), openpyxl (for .xlsx).
# ──────────────────────────────────────────────────────────────────────

import csv
import glob
import os
import re

import pandas as pd

IN_DIR = os.path.join("content", "incoming", "abitur")
OUT = os.path.join("notebooks", "raw", "abitur", "kmk_abitur.csv")
LANDS = ["BW", "BY", "BE", "BB", "HB", "HH", "HE", "MV", "NI", "NW", "RP", "SL", "SN", "ST", "SH", "TH"]
GRADES = [round(1 + i / 10, 1) for i in range(31)]


def number(v):
    """A cell as a number; '-', '.', blank and text become None."""
    if v is None or (isinstance(v, float) and pd.isna(v)):
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).strip().replace(",", ".")
    try:
        return float(s)
    except ValueError:
        return None


def label(v):
    return str(v).strip() if isinstance(v, str) else ""


def read_year(path):
    year = int(re.search(r"kmk_(\d{4})", path).group(1))
    df = pd.read_excel(path, sheet_name="Noten", header=None)
    rows = df.values.tolist()
    head = next(i for i, r in enumerate(rows) if label(r[0]) == "Land")
    cols = {label(v): j for j, v in enumerate(rows[head]) if label(v) in LANDS}
    assert sorted(cols) == sorted(LANDS), (path, cols)

    def row_of(text):
        return next(r for r in rows[head:] if label(r[0]).startswith(text))

    exams, passed = row_of("Zahl der Prüfungen"), row_of("- bestanden")
    failed, mean = row_of("- nicht bestanden (abs.)"), row_of("Notenmittel")
    grade_rows = {}
    for r in rows[head:]:
        g = number(r[0])
        if g is not None and 1.0 <= g <= 4.0 and round(g, 1) in GRADES and round(g, 1) not in grade_rows:
            grade_rows[round(g, 1)] = r
    assert sorted(grade_rows) == GRADES, (path, sorted(grade_rows))

    # Columns the KMK marks as the previous year's values: a note under the table ("BW:
    # Vorjahreswerte …") or a footnote "Vorjahresdaten" for that Land.
    notes = " ".join(label(r[0]) for r in rows[head:])
    foot = pd.read_excel(path, sheet_name="Fußnoten", header=None).values.tolist()
    names = {"BW": "Baden-Württemberg", "BY": "Bayern", "BE": "Berlin", "BB": "Brandenburg",
             "HB": "Bremen", "HH": "Hamburg", "HE": "Hessen", "MV": "Mecklenburg-Vorpommern",
             "NI": "Niedersachsen", "NW": "Nordrhein-Westfalen", "RP": "Rheinland-Pfalz",
             "SL": "Saarland", "SN": "Sachsen", "ST": "Sachsen-Anhalt", "SH": "Schleswig-Holstein",
             "TH": "Thüringen"}
    previous = set()
    for land in LANDS:
        if re.search(rf"\b{land}: Vorjahres", notes):
            previous.add(land)
        for r in foot:
            first = label(r[0])
            text = " ".join(label(v) for v in r[1:])
            if first in (land, names[land]) and ("Vorjahresdaten" in text or "Vorjahreswerte" in text
                                                 or "endgültigen Werte des Schuljahres" in text):
                previous.add(land)

    out = []
    for land in LANDS:
        j = cols[land]
        out.append([year, land, number(exams[j]), number(passed[j]), number(failed[j]),
                    number(mean[j]), int(land in previous)]
                   + [number(grade_rows[g][j]) for g in GRADES])
    return out


def main():
    files = sorted(glob.glob(os.path.join(IN_DIR, "kmk_*.xls*")))
    rows = [r for f in files for r in read_year(f)]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["year", "land", "exams", "passed", "failed", "mean", "previous_year"]
                   + [f"n_{g:.1f}".replace(".", "_") for g in GRADES])
        for r in rows:
            w.writerow(["" if v is None else (int(v) if isinstance(v, float) and v.is_integer() and i != 5 else v)
                        for i, v in enumerate(r)])
    years = sorted({r[0] for r in rows})
    flagged = [(r[0], r[1]) for r in rows if r[6]]
    print(f"{len(rows)} Land-years, {years[0]}-{years[-1]}; previous-year copies: {flagged}")


if __name__ == "__main__":
    main()
