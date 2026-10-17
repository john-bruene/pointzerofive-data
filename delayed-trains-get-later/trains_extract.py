# trains_extract.py
# ──────────────────────────────────────────────────────────────────────
# Reduces the train data for story #006 "Does a late train get even later?" to one row per train
# run (pitch: content/pitches/006-delayed-trains-get-later.md).
#
# Inputs (not committed, too large; URLs in the pitch and the data-repository README):
#   content/incoming/trains/db-2026-09.parquet  Deutsche Bahn via piebro/deutsche-bahn-data
#   content/incoming/trains/ch-2026-09.zip      opentransportdata.swiss Ist-Daten v2, September 2026
# Outputs:
#   notebooks/raw/trains/runs_de.csv.gz, notebooks/raw/trains/runs_ch.csv.gz
#   one row per run: day, run, pattern, a_station, train_type, n_stops, delay_a (departure delay at
#   the middle stop A, minutes), delay_end (arrival delay at the final stop, empty if that arrival
#   was cancelled), cancelled_after (1 if any stop after A was cancelled), delay_last (arrival
#   delay at the last stop after A that was served, empty if none)
#
# Run from project root:  python3 notebooks/trains_extract.py [de] [ch]
# Requires: Python 3 with duckdb.
# ──────────────────────────────────────────────────────────────────────

import os
import subprocess
import tempfile

import duckdb

IN_DIR = os.path.join("content", "incoming", "trains")
OUT_DIR = os.path.join("notebooks", "raw", "trains")
DB = os.path.join(IN_DIR, "db-2026-09.parquet")
CH = os.path.join(IN_DIR, "ch-2026-09.zip")

# One row per run from a table `stops` with: day, run, pattern, station, train_type, ord (stop
# order), dep_plan, dep_real, arr_plan, arr_real, dep_cancel, arr_cancel. Minutes as doubles.
RUNS_SQL = """
WITH s AS (
  SELECT *, row_number() OVER (PARTITION BY run ORDER BY ord) AS k,
         count(*) OVER (PARTITION BY run) AS n
  FROM stops
),
a AS (
  SELECT run, k AS ka FROM s WHERE k = CAST(ceil(n / 2.0) AS INTEGER)
),
j AS (SELECT s.*, a.ka FROM s JOIN a USING (run))
SELECT
  any_value(day) AS day,
  run,
  any_value(pattern) AS pattern,
  max(CASE WHEN k = ka THEN station END) AS a_station,
  any_value(train_type) AS train_type,
  any_value(n) AS n_stops,
  max(CASE WHEN k = ka AND NOT dep_cancel THEN date_diff('second', dep_plan, dep_real) / 60.0 END)
    AS delay_a,
  max(CASE WHEN k = n AND NOT arr_cancel THEN date_diff('second', arr_plan, arr_real) / 60.0 END)
    AS delay_end,
  max(CASE WHEN k > ka AND (arr_cancel OR (k < n AND dep_cancel)) THEN 1 ELSE 0 END)
    AS cancelled_after,
  arg_max(CASE WHEN k > ka AND NOT arr_cancel THEN date_diff('second', arr_plan, arr_real) / 60.0 END,
          CASE WHEN k > ka AND NOT arr_cancel THEN k END) AS delay_last
FROM j
GROUP BY run
HAVING any_value(n) >= 3 AND delay_a IS NOT NULL
"""


def germany(con):
    con.execute(f"""
      CREATE OR REPLACE TABLE stops AS
      SELECT
        CAST(coalesce(departure_planned_time, arrival_planned_time) AS DATE) AS day0,
        regexp_replace(id, '-[0-9]+$', '') AS run,
        train_line_ride_id AS pattern,
        eva AS station,
        train_type,
        train_line_station_num AS ord,
        departure_planned_time AS dep_plan, departure_change_time AS dep_real,
        arrival_planned_time AS arr_plan, arrival_change_time AS arr_real,
        coalesce(departure_is_canceled, false) AS dep_cancel,
        coalesce(arrival_is_canceled, false) AS arr_cancel
      FROM '{DB}'
      WHERE train_type <> 'Bus' AND NOT coalesce(is_replacement_train, false)
        AND NOT coalesce(is_additional_stop, false)
    """)
    # the day of a run is the day of its first planned stop
    con.execute("""
      CREATE OR REPLACE TABLE stops AS
      SELECT * EXCLUDE (day0), min(day0) OVER (PARTITION BY run) AS day FROM stops
    """)
    rows = con.execute(f"SELECT * FROM ({RUNS_SQL}) WHERE day BETWEEN DATE '2026-09-01' AND DATE '2026-09-30'").df()
    return rows


def switzerland(con):
    names = subprocess.run(["unzip", "-Z1", CH], capture_output=True, text=True, check=True)
    days = sorted(n for n in names.stdout.split() if n.endswith("_IstDaten.csv"))
    parts = []
    with tempfile.TemporaryDirectory() as tmp:
        for name in days:
            path = os.path.join(tmp, "day.csv")
            with open(path, "wb") as f:
                subprocess.run(["unzip", "-p", CH, name], stdout=f, check=True)
            ts = "strptime({col}, ['%d.%m.%Y %H:%M:%S', '%d.%m.%Y %H:%M'])"
            con.execute(f"""
              CREATE OR REPLACE TABLE raw AS
              SELECT * FROM read_csv('{path}', delim=';', header=true, all_varchar=true)
              WHERE PRODUKT_ID = 'Zug'
            """)
            con.execute(f"""
              CREATE OR REPLACE TABLE stops AS
              SELECT
                strptime(BETRIEBSTAG, '%d.%m.%Y')::DATE AS day,
                BETRIEBSTAG || '|' || FAHRT_BEZEICHNER AS run,
                FAHRT_BEZEICHNER AS pattern,
                BPUIC AS station,
                VERKEHRSMITTEL_TEXT AS train_type,
                coalesce({ts.format(col='ABFAHRTSZEIT')}, {ts.format(col='ANKUNFTSZEIT')}) AS ord,
                {ts.format(col='ABFAHRTSZEIT')} AS dep_plan, {ts.format(col='AB_PROGNOSE')} AS dep_real,
                {ts.format(col='ANKUNFTSZEIT')} AS arr_plan, {ts.format(col='AN_PROGNOSE')} AS arr_real,
                (FAELLT_AUS_TF = 'true') AS dep_cancel,
                (FAELLT_AUS_TF = 'true') AS arr_cancel
              FROM raw
              WHERE ZUSATZFAHRT_TF = 'false' AND coalesce(DURCHFAHRT_TF, 'false') = 'false'
                AND (FAELLT_AUS_TF = 'true'
                     OR coalesce(AN_PROGNOSE_STATUS, 'UNBEKANNT') <> 'UNBEKANNT'
                     OR coalesce(AB_PROGNOSE_STATUS, 'UNBEKANNT') <> 'UNBEKANNT')
                AND BETRIEBSTAG || '|' || FAHRT_BEZEICHNER IN (
                  SELECT BETRIEBSTAG || '|' || FAHRT_BEZEICHNER FROM raw
                  GROUP BY 1 HAVING bool_or(FAELLT_AUS_TF = 'false'))
            """)
            # Stops without any forecast are left out, except cancelled stops: those never carry a
            # forecast and must stay in so that a cancellation after A counts (correction of
            # 2026-10-16, see pitch section 5).
            parts.append(con.execute(RUNS_SQL).df())
            print("  ch", name, len(parts[-1]), flush=True)
            os.remove(path)
    import pandas as pd

    return pd.concat(parts, ignore_index=True)


def write(df, path):
    os.makedirs(OUT_DIR, exist_ok=True)
    df = df.sort_values(["day", "run"])
    df.to_csv(path, index=False, compression="gzip", float_format="%.2f",
              columns=["day", "run", "pattern", "a_station", "train_type", "n_stops", "delay_a",
                       "delay_end", "cancelled_after", "delay_last"])
    print(f"{path}: {len(df)} runs")


def main(countries):
    con = duckdb.connect()
    if "de" in countries:
        write(germany(con), os.path.join(OUT_DIR, "runs_de.csv.gz"))
    if "ch" in countries:
        write(switzerland(con), os.path.join(OUT_DIR, "runs_ch.csv.gz"))


if __name__ == "__main__":
    import sys

    main(sys.argv[1:] or ["de", "ch"])
