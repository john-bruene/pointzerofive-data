# gingerbread_download.py
# ──────────────────────────────────────────────────────────────────────
# Downloads the Google Trends data for story #004 "Does the gingerbread season start earlier every
# year?" (pitch: content/pitches/004-gingerbread-earlier-every-year.md).
#
# One request per season: web search, Germany, 1 June to 31 December (Google returns daily values
# for windows this short), the terms "Lebkuchen", "Spekulatius" and "Dominosteine" together, so the
# three series share one scale (0 to 100 within the request). Google samples its data; a repeated
# download can differ by a few points. The file written here is the data of record and is not
# edited afterwards.
#
# Output: notebooks/raw/gingerbread/trends_daily.csv (season, date, term, value, partial)
#         notebooks/raw/gingerbread/download_log.json (time of each request)
#
# Run from project root:  python3 notebooks/gingerbread_download.py
# Requires: Python 3 standard library only. Seasons already in the CSV are skipped, so the script
# can be run again after Google answers "429 Too Many Requests".
# ──────────────────────────────────────────────────────────────────────

import csv
import http.cookiejar
import json
import os
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

TERMS = ["Lebkuchen", "Spekulatius", "Dominosteine"]
SEASONS = range(2004, 2026)
OUT_DIR = os.path.join("notebooks", "raw", "gingerbread")
CSV_PATH = os.path.join(OUT_DIR, "trends_daily.csv")
LOG_PATH = os.path.join(OUT_DIR, "download_log.json")
BASE = "https://trends.google.com/trends/api/"

jar = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar))
opener.addheaders = [("User-Agent", "Mozilla/5.0"), ("Accept-Language", "de-DE")]


def get_json(url):
    """GET a Trends API URL and parse the JSON after Google's anti-hijacking prefix."""
    for attempt in range(6):
        try:
            text = opener.open(url, timeout=60).read().decode("utf-8")
            return json.loads(text[text.index("{"):])
        except urllib.error.HTTPError as e:
            if e.code != 429:
                raise
            wait = 60 * (attempt + 1) + random.uniform(0, 20)
            print(f"  429, waiting {wait:.0f} s", flush=True)
            time.sleep(wait)
    raise RuntimeError("Google kept answering 429; run the script again later")


def season(year):
    window = f"{year}-06-01 {year}-12-31"
    req = {
        "comparisonItem": [{"keyword": t, "geo": "DE", "time": window} for t in TERMS],
        "category": 0,
        "property": "",
    }
    q = {"hl": "de", "tz": "-120", "req": json.dumps(req)}
    explore = get_json(BASE + "explore?" + urllib.parse.urlencode(q))
    widget = next(w for w in explore["widgets"] if w["id"] == "TIMESERIES")
    time.sleep(random.uniform(4, 8))
    q = {"hl": "de", "tz": "-120", "req": json.dumps(widget["request"]), "token": widget["token"]}
    data = get_json(BASE + "widgetdata/multiline?" + urllib.parse.urlencode(q))
    rows = []
    for point in data["default"]["timelineData"]:
        day = datetime.fromtimestamp(int(point["time"]), tz=timezone.utc).strftime("%Y-%m-%d")
        for term, value in zip(TERMS, point["value"]):
            rows.append([year, day, term, value, int(bool(point.get("isPartial")))])
    if widget["request"].get("resolution") != "DAY" or len(rows) != 214 * len(TERMS):
        raise RuntimeError(f"{year}: expected 214 daily values per term, got {len(rows)}")
    return rows


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    done = set()
    if os.path.exists(CSV_PATH):
        with open(CSV_PATH, newline="", encoding="utf-8") as f:
            done = {int(r["season"]) for r in csv.DictReader(f)}
    log = json.load(open(LOG_PATH, encoding="utf-8")) if os.path.exists(LOG_PATH) else {}
    new_file = not os.path.exists(CSV_PATH)
    with open(CSV_PATH, "a", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        if new_file:
            w.writerow(["season", "date", "term", "value", "partial"])
        for year in SEASONS:
            if year in done:
                continue
            print(f"season {year}", flush=True)
            rows = season(year)
            w.writerows(rows)
            f.flush()
            log[str(year)] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            with open(LOG_PATH, "w", encoding="utf-8") as lf:
                json.dump(log, lf, indent=1, sort_keys=True)
            time.sleep(random.uniform(20, 40))
    print("done", file=sys.stderr)


if __name__ == "__main__":
    main()
