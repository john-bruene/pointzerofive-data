# Does a late train get even later?

Data and code behind the story
[Does a late train get even later?](https://pointzerofive.net/2026/10/delayed-trains-get-later)
(#006, 15 October 2026; German:
[Sammelt ein verspäteter Zug noch mehr Verspätung?](https://pointzerofive.net/de/2026/10/delayed-trains-get-later)).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/delayed-trains-get-later/story_006_trains.ipynb)
(choose the R runtime; the notebook installs lme4 and lmerTest, and the 36 mixed models take about half an hour).

File | Contents
---|---
`story_006_trains.ipynb` | R notebook that reproduces every number in the story, including all 36 calculation paths
`delayed-trains-get-later.json` | Published results: main calculation, the 36 calculation paths (`specs`), chart data
`delayed-trains-get-later.output.txt` | Console output of the pipeline run, unedited, ending with R and package versions
`runs_de.csv.gz` | One row per train run in Germany, September 2026
`runs_ch.csv.gz` | One row per train run in Switzerland, September 2026
`claim.json` | Texts of the claim and of the forks, English and German
`pitch.md` | The pitch: question, main calculation and forks, fixed before the analysis
`trains_extract.py` | Reduces the two raw data sets to one row per run (Python with duckdb)
`trains_pipeline.R` | Computes all calculation paths and the published results
`estimation_table.R` | Builds and prints the result table of the main calculation (key `estimation` in the JSON)

The notebook runs in this folder as it is. The raw files are too large for this repository; the
extraction script expects them in `content/incoming/trains/` (see Sources).

## runs_de.csv.gz and runs_ch.csv.gz

Header | Definition
---|---
`day` | Day of the run
`run` | Run: Germany the stop id without the stop number (pattern and first departure), Switzerland day and `FAHRT_BEZEICHNER`
`pattern` | Train pattern: the same train on different days (Germany `train_line_ride_id`, Switzerland `FAHRT_BEZEICHNER`)
`a_station` | Stop A, the middle stop: Germany EVA number, Switzerland BPUIC
`train_type` | Train category, e.g. `ICE`, `RE`, `S` (Germany) or `IC`, `IR`, `S` (Switzerland)
`n_stops` | Number of stops of the run used
`delay_a` | Departure delay at stop A, minutes
`delay_end` | Arrival delay at the final stop, minutes; empty if that arrival was cancelled or has no forecast
`cancelled_after` | 1 if a stop after A was cancelled
`delay_last` | Arrival delay at the last stop after A that was served, minutes

## Sources and licences

- Germany: Deutsche Bahn Timetables API, data licensed CC BY 4.0 by Deutsche Bahn, collected by
  Piet Brömmel, [deutsche-bahn-data](https://github.com/piebro/deutsche-bahn-data), file
  `monthly_processed_data/data-2026-09.parquet` on
  [Hugging Face](https://huggingface.co/datasets/piebro/deutsche-bahn-data), downloaded on
  16 October 2026.
- Switzerland: [opentransportdata.swiss](https://opentransportdata.swiss), Ist-Daten v2,
  `https://archive.opentransportdata.swiss/istdaten/2026/ist-daten-v2-2026-09.zip`, downloaded on
  16 October 2026; terms of use of opentransportdata.swiss.

Everything else in this folder: © John Brüne, all rights reserved (see the main README).
