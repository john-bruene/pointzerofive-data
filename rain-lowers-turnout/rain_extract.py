# rain_extract.py
# ──────────────────────────────────────────────────────────────────────
# Reduces the raw files of story #007 "Does rain lower turnout?" to two small tables
# (pitch: content/pitches/007-rain-lowers-turnout.md).
#
# Inputs (content/incoming/rain/, written by rain_download.py):
#   btw_kerg.zip, wk<year>.zip, pr_hyras_1_<year>_v6-1_de.nc
# Outputs:
#   notebooks/raw/rain/turnout.csv  one row per Wahlkreis and election 2005–2025: election, wkr,
#                                   name, land, eligible, voters (this election), eligible_prev,
#                                   voters_prev (previous election on the same boundaries);
#                                   Erststimmen columns of the kerg files
#   notebooks/raw/rain/rain.csv     mean HYRAS precipitation (mm) per Wahlkreis of the geometry of
#                                   election `geometry`, for the calendar date of that election
#                                   (`which` = this) and of the previous one (`which` = prev), in
#                                   every year 1995–2025; HYRAS date D = 06 UTC on D to 06 UTC on D+1
#
# Run from project root:  python3 notebooks/rain_extract.py
# Requires: Python 3 with numpy, netCDF4, pyshp, shapely, pyproj.
# ──────────────────────────────────────────────────────────────────────

import csv
import datetime as dt
import glob
import io
import os
import tempfile
import zipfile

import netCDF4
import numpy as np
import pyproj
import shapefile
import shapely
from shapely.ops import transform, unary_union

IN_DIR = os.path.join("content", "incoming", "rain")
OUT_DIR = os.path.join("notebooks", "raw", "rain")
ELECTIONS = {
    2002: dt.date(2002, 9, 22),
    2005: dt.date(2005, 9, 18),
    2009: dt.date(2009, 9, 27),
    2013: dt.date(2013, 9, 22),
    2017: dt.date(2017, 9, 24),
    2021: dt.date(2021, 9, 26),
    2025: dt.date(2025, 2, 23),
}
YEARS = range(1995, 2026)
KERG = {e: f"btw{e}_kerg.csv" for e in ELECTIONS if e >= 2005}


def kerg_rows(e):
    """Wahlkreis rows of one kerg file: number, name, Land, eligible and voters now and before."""
    raw = zipfile.ZipFile(os.path.join(IN_DIR, "btw_kerg.zip")).read(KERG[e])
    text = raw.decode("utf-8-sig") if raw.startswith(b"\xef\xbb\xbf") else raw.decode("latin1")
    rows = list(csv.reader(io.StringIO(text), delimiter=";"))
    head = next(r for r in rows if r and r[0] == "Nr")
    i_elig = head.index("Wahlberechtigte")
    i_vote = next(i for i, h in enumerate(head) if h in ("Wähler", "Wählende"))
    i_land = next(i for i, h in enumerate(head) if h.startswith("gehört"))
    out = []
    for r in rows:
        if not r or not r[0].strip().isdigit() or not r[i_land].strip().isdigit():
            continue
        land = int(r[i_land])
        if land == 99:  # a Land row, not a Wahlkreis
            continue
        num = lambda s: int(s.replace(".", "").strip() or 0)
        out.append(
            dict(
                election=e,
                wkr=int(r[0]),
                name=r[1].strip(),
                land=land,
                eligible=num(r[i_elig]),
                voters=num(r[i_vote]),
                eligible_prev=num(r[i_elig + 1]),
                voters_prev=num(r[i_vote + 1]),
            )
        )
    assert len(out) == 299, (e, len(out))
    return out


def wahlkreise(e):
    """Wahlkreis polygons of election e in EPSG:3035 (the HYRAS grid), merged by number."""
    with tempfile.TemporaryDirectory() as tmp:
        zipfile.ZipFile(os.path.join(IN_DIR, f"wk{e}.zip")).extractall(tmp)
        shp = glob.glob(os.path.join(tmp, "**", "*.shp"), recursive=True)[0]
        crs = pyproj.CRS.from_wkt(open(shp[:-4] + ".prj").read())
        to_grid = pyproj.Transformer.from_crs(crs, "EPSG:3035", always_xy=True).transform
        r = shapefile.Reader(shp, encoding="latin1")  # names are not used
        parts = {}
        for rec, s in zip(r.records(), r.shapes()):
            g = shapely.geometry.shape(s.__geo_interface__)
            parts.setdefault(int(rec["WKR_NR"]), []).append(transform(to_grid, g))
    polys = {k: unary_union(v) for k, v in parts.items()}
    assert sorted(polys) == list(range(1, 300)), e
    return polys


def cell_index(polys, x, y):
    """For every Wahlkreis the flat indices of the grid cells whose centre lies inside."""
    xx, yy = np.meshgrid(x, y)
    out = {}
    for k, p in polys.items():
        x0, y0, x1, y1 = p.bounds
        cand = np.flatnonzero((xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1))
        inside = shapely.contains_xy(p, xx.ravel()[cand], yy.ravel()[cand])
        out[k] = cand[inside]
        assert out[k].size > 0, k
    return out


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    turnout = [row for e in KERG for row in kerg_rows(e)]
    with open(os.path.join(OUT_DIR, "turnout.csv"), "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(turnout[0]))
        w.writeheader()
        w.writerows(turnout)
    print(f"turnout.csv: {len(turnout)} rows")

    first = netCDF4.Dataset(os.path.join(IN_DIR, f"pr_hyras_1_{YEARS[0]}_v6-1_de.nc"))
    x, y = first.variables["x"][:].data, first.variables["y"][:].data
    elections = sorted(ELECTIONS)
    cells = {}
    for e in elections[1:]:
        cells[e] = cell_index(wahlkreise(e), x, y)
        print(f"  geometry {e}: median {int(np.median([v.size for v in cells[e].values()]))} cells")

    out = []
    for year in YEARS:
        ds = netCDF4.Dataset(os.path.join(IN_DIR, f"pr_hyras_1_{year}_v6-1_de.nc"))
        t = ds.variables["time"]
        days = [d.date() if hasattr(d, "date") else d for d in netCDF4.num2date(t[:], t.units)]
        days = [dt.date(d.year, d.month, d.day) for d in days]
        for i, e in enumerate(elections[1:], start=1):
            for which, ref in (("this", ELECTIONS[e]), ("prev", ELECTIONS[elections[i - 1]])):
                day = dt.date(year, ref.month, ref.day)
                field = ds.variables["pr"][days.index(day)].filled(np.nan).ravel()
                for k, idx in cells[e].items():
                    out.append((e, which, ref.strftime("%m-%d"), year, k, np.nanmean(field[idx])))
        print(f"  {year}", flush=True)
    with open(os.path.join(OUT_DIR, "rain.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["geometry", "which", "date", "year", "wkr", "mm"])
        for r in out:
            w.writerow(r[:5] + (f"{r[5]:.3f}",))
    print(f"rain.csv: {len(out)} rows")


if __name__ == "__main__":
    main()
