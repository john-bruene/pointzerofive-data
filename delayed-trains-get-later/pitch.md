# Story Pitch — Does a late train get even later?

> Standards: `content/story-standards.md`; rules: `content/no-slop.md`.

---

## Meta

| Field | Value |
| --- | --- |
| Story number | #006 |
| Working title | Does a late train get even later? / Sammelt ein verspäteter Zug noch mehr Verspätung? |
| Slug | `/2026/10/delayed-trains-get-later` |
| Display date | Thursday 15 October 2026 (weekly series set by John) |
| Status | pitch fixed 2026-10-16, after downloading both data sets and reading only column names, row counts, train types and how missing real-time values are coded; no delay was read |

## 1. Fragestellung (the question)

**Once a train is late, does it lose even more time on the rest of its journey than a train that
is on time?**

- Popular claim: „Wer einmal zu spät ist, bleibt hinten." A late train loses its slot, waits behind
  punctual trains, misses its crossing on single track and arrives later still.
- What we measure: for every train run, the departure delay at the middle stop of its route
  (stop A) and the arrival delay at its final stop. Additional delay = arrival delay at the end
  minus departure delay at A. We compare the additional delay of the same train on days it left A
  late with days it left A on time.
- Hypothesis, written before the analysis: no. Timetables contain buffer time, so a late train can
  make up minutes, and a train counted as late at A is late partly by chance (regression to the
  mean, as in #001). I expect the effect to be negative for Germany, maybe significantly so.
  John asked for Switzerland as well; I expect the same direction there with smaller delays.

## 1b. Der Streit, die Gabelungen, die Präregistrierung

Fixed on 2026-10-16. Known before: column names, number of rows and runs, train types and that
the DB data always fill the changed time (equal to the planned time when nothing changed).

- **Claim as yes/no question:** EN "Does a late train get even later?" /
  DE „Sammelt ein verspäteter Zug noch mehr Verspätung?"
- **Dispute:** to be filled in with verified citations before the text is written (yes side: the
  common experience of delays piling up; no side: timetable buffer time). The calculation does not
  depend on it.
  - *Added after the analysis, before the text (2026-10-16), calculation unchanged:* Science Media
    Center press briefing "Wie wird die Bahn wieder pünktlich?", 20 August 2025, transcript:
    Gernot Liedtke (TU Berlin, DLR) on delays that spread through the network (yes side); Markus
    Hecht (TU Berlin) on delays that are partly made up on the way (no side).
- **Data:**
  - Germany: Deutsche Bahn Timetables API as collected by piebro/deutsche-bahn-data, monthly
    processed file for September 2026 (all stations), CC BY 4.0 Deutsche Bahn.
  - Switzerland: opentransportdata.swiss, Ist-Daten v2, September 2026, only rail
    (`PRODUKT_ID = "Zug"`).
- **Train run:** Germany: one train on one day (stop `id` without the stop number); stops ordered
  by `train_line_station_num`; rows of type `Bus`, replacement trains and additional stops left out.
  Switzerland: `BETRIEBSTAG` + `FAHRT_BEZEICHNER`; stops ordered by planned time; extra trips
  (`ZUSATZFAHRT_TF`), runs cancelled as a whole (`FAELLT_AUS_TF` on every stop) and pass-throughs
  (`DURCHFAHRT_TF`) left out.
- **Stop A:** the middle stop of the run, stop number ceil(n / 2) of n ≥ 3 stops. Delay at A =
  changed or forecast departure time minus planned departure time, in minutes.
- **Groups:** late at A = delay at A ≥ threshold; on time at A = delay at A < 6 minutes (Deutsche
  Bahn's own definition of punctual). Runs in between are not used.
- **Outcome:** additional delay = arrival delay at the final stop minus delay at A, in minutes.
- **Same train, other days:** comparisons are made within one train pattern (Germany:
  `train_line_ride_id`; Switzerland: `FAHRT_BEZEICHNER` without the date) and the same stop A.
  Effect = least-squares coefficient of "late at A" with one constant per pattern (fixed effects),
  i.e. the weighted mean over patterns of (mean additional delay late − mean on time), weights
  n_late · n_on_time / n. Positive means late trains lose more time on the rest of the way (the
  claim).
- **Primary test and how p and the 95% interval are computed:** cluster bootstrap over train
  patterns, B = 10,000, patterns drawn with replacement; interval = 250th to 9,751st sorted
  replicate; p = 2 · min(share ≤ 0, share ≥ 0). Seed 6100 + path number.
- **α:** 0.05, **two-sided**. "Yes" needs p < 0.05 and a positive effect.
- **Main calculation:** Germany, all trains, threshold 6 minutes, runs with a cancellation after
  stop A left out.
- **Smallest relevant effect:** 1 minute of additional delay at the final stop.
- **Fixed before the analysis:** everything above and the forks below.

| Fork as an everyday question (EN / DE) | Options with one-line reason (EN / DE) | Main | Why it could flip the result |
| --- | --- | --- | --- |
| Which country? / Welches Land? | `de` Germany / Deutschland; `ch` Switzerland / Schweiz | `de` | Swiss timetables are tighter and delays smaller |
| Which trains? / Welche Züge? | `all` all trains / alle Züge; `long` long distance (DE: ICE, IC, EC, ECE, RJ, RJX, NJ, EN, FLX, TGV; CH: IC, IR, EC, ICE, TGV, RJX, NJ, EN) / Fernverkehr; `regional` all others / Nah- und Regionalverkehr | `all` | Long-distance trains share track with everything and have long runs |
| From how many minutes is a train late? / Ab wie vielen Minuten ist ein Zug verspätet? | `6`, `11`, `16` minutes at stop A | `6` | Badly late trains may be late for a reason that persists (a broken train, a closed track) |
| What about cancellations? / Was ist mit Ausfällen? | `drop` runs with a cancelled stop after A left out / Fahrten mit Ausfall nach A fallen heraus; `lastserved` the last stop actually served counts as the end / der letzte bediente Halt zählt als Ende | `drop` | Very late trains are often cut short; leaving them out hides the worst cases |

2 × 3 × 3 × 2 = 36 calculation paths.

## 2. Datenbeschaffung (data acquisition)

| Source | URL | Format | License / Terms | Accessed |
| --- | --- | --- | --- | --- |
| Deutsche Bahn via piebro/deutsche-bahn-data | https://huggingface.co/datasets/piebro/deutsche-bahn-data (monthly_processed_data/data-2026-09.parquet) | Parquet | CC BY 4.0 Deutsche Bahn | 2026-10-16 |
| SBB / opentransportdata.swiss Ist-Daten v2 | https://archive.opentransportdata.swiss/istdaten/2026/ist-daten-v2-2026-09.zip | CSV in ZIP | opentransportdata.swiss terms of use (open use, source to be cited) | 2026-10-16 |

- **Acquisition plan:** `notebooks/trains_extract.py` (Python, duckdb) reduces both files to one row
  per train run with pattern, stop A, delay at A, arrival delay at the end and at the last served
  stop, cancellation flags and train type: `notebooks/raw/trains/runs_de.csv.gz`,
  `runs_ch.csv.gz`. `notebooks/trains_pipeline.R` does the analysis.
- **Unit of analysis:** train run; comparisons within train patterns.
- **Known biases / caveats:** changed times are real-time forecasts or actual times, whichever the
  API had last; regression to the mean pulls the late group back; some hours of DB data are missing
  in some months (none reported for September 2026).

## 3. Geplante Visualisierung (planned figures)

1. Mean additional delay by delay at stop A, Germany (first results).
2. Effect per train type or country (analysis).
3. Specification curve of all 36 paths (robustness, `SpecPaths`).

## 4. Quellenangaben (sources & attribution)

- Deutsche Bahn, Timetables API, CC BY 4.0, collected by Piet Brömmel (deutsche-bahn-data).
- opentransportdata.swiss, Ist-Daten.

## 5. Outcome

Analysis run 2026-10-16 with `trains_pipeline.R`, exactly as fixed above, after one correction.

- **Correction after the first run:** the Swiss extraction left out stops without a forecast
  (decided after this pitch, before the analysis). Cancelled stops never carry a forecast in the
  Swiss data, so that rule also removed every cancelled stop, and the first run found no Swiss
  cancellation after stop A. That contradicts the definitions above. `trains_extract.py` now
  keeps cancelled stops; Switzerland was extracted and every path computed again. Germany is not
  affected. Swiss runs: 418,805 (first run 422,676), 6,840 with a cancellation after A.
- **Main calculation (Germany, all trains, 6 minutes, cancellations dropped):** −0.78 minutes
  [−0.83, −0.73], p < 0.001, n = 716,223 runs. Verdict **no**, and significant in the other
  direction: late trains make up time compared with the same trains on punctual days.
- **Forks:** "yes" on 0 of 36 paths (also 0 in the first run). 31 paths significantly negative;
  the 5 not significant ones are all Swiss with the line at 11 or 16 minutes, four of them long
  distance (few runs, wide intervals).
- **Size:** at most about 2.4 minutes (Swiss long distance at 6 minutes: −2.42). No path comes
  near the smallest relevant effect in the claimed direction.
- **Note:** late trains are more often cut short after stop A (Germany 5.7% against 1.0%,
  Switzerland 6.2% against 1.5%); the `lastserved` fork includes them and does not change the
  verdict.
