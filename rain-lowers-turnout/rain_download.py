# rain_download.py
# ──────────────────────────────────────────────────────────────────────
# Downloads the raw files for story #007 "Does rain lower turnout?"
# (pitch: content/pitches/007-rain-lowers-turnout.md).
#
#   btw_kerg.zip                      Bundeswahlleiterin, Wahlkreis results 1949–2025
#   wk<year>.zip                      Bundeswahlleiterin, Wahlkreis geometry of each election
#   pr_hyras_1_<year>_v6-1_de.nc      DWD HYRAS-DE-PR v6-1, daily precipitation, 1995–2025
#
# Run from project root:  python3 notebooks/rain_download.py [target folder]
# (default content/incoming/rain; the files are too large for the repository).
# ──────────────────────────────────────────────────────────────────────

import os
import sys
import time
import urllib.request

BWL = "https://www.bundeswahlleiterin.de/dam/jcr/"
FILES = {
    "btw_kerg.zip": BWL + "ce2d2b6a-f211-4355-8eea-355c98cd4e47/btw_kerg.zip",
    "wk2025.zip": BWL + "b3656fdd-eb0c-4721-ba02-9e7fdf558475/btw25_geometrie_wahlkreise_vg250_shp.zip",
    "wk2021.zip": BWL + "f0ce06a7-188c-4ef3-b49b-5a66719d2b46/btw21_geometrie_wahlkreise_vg250_shp.zip",
    "wk2017.zip": BWL + "67e3e9b8-dbca-4bc9-8977-ac792665bbce/btw17_geometrie_wahlkreise_vg250_shp.zip",
    "wk2013.zip": BWL + "beb67d24-4bf3-4e06-8a1b-c00c0ddc69d9/btw13_geometrie_wahlkreise_lam_shp.zip",
    "wk2009.zip": BWL + "5c8c348a-8e14-414a-aa53-dc28732baa29/btw09_geometrie_wahlkreise_shp.zip",
    "wk2005.zip": BWL + "d5eb37c1-6683-444c-8265-04a5cea3523e/btw05_geometrie_wahlkreise_shp_utm32.zip",
}
HYRAS = "https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/hyras_de/precipitation/"
for year in range(1995, 2026):
    name = f"pr_hyras_1_{year}_v6-1_de.nc"
    FILES[name] = HYRAS + name


def fetch(url, path):
    for attempt in range(5):
        try:
            tmp = path + ".part"
            with urllib.request.urlopen(url, timeout=120) as r, open(tmp, "wb") as f:
                while chunk := r.read(1 << 20):
                    f.write(chunk)
            os.replace(tmp, path)
            return
        except OSError as e:
            print(f"  retry {attempt + 1}: {e}", flush=True)
            time.sleep(5 * (attempt + 1))
    raise RuntimeError(f"failed: {url}")


def main(target):
    os.makedirs(target, exist_ok=True)
    for name, url in FILES.items():
        path = os.path.join(target, name)
        if os.path.exists(path):
            continue
        fetch(url, path)
        print(f"{name}: {os.path.getsize(path):,} bytes", flush=True)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else os.path.join("content", "incoming", "rain"))
