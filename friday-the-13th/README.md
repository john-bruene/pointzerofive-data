# Are there more road accidents on Friday the 13th?

Data and code behind the story
[Are there more road accidents on Friday the 13th?](https://pointzerofive.net/2026/09/friday-the-13th)
(#002, 17 September 2026; German:
[Passieren an Freitag, dem 13., mehr Verkehrsunfälle?](https://pointzerofive.net/de/2026/09/friday-the-13th)).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/friday-the-13th/story_002_friday_13th.ipynb)

File | Contents
---|---
`story_002_friday_13th.ipynb` | Python notebook that reproduces every number in the story, including all calculation paths
`friday-the-13th.json` | Published results: main calculation, all calculation paths (`specs`), chart data
`daily_collisions.csv` | Road collisions with at least one injured person in Great Britain, per day, 1979 to 2025
`daily_collisions.meta.json` | Where the daily counts come from: source file, licence, date accessed, rows read
`claim.json` | Texts of the claim and of the forks, English and German
`pitch.md` | The plan for the analysis, written before it: question, main calculation, forks
`friday13_pipeline.py` | Counts the collisions per day and builds the published results
`friday13_stats.py` | Effect, month bootstrap and seeds

The notebook runs in this folder as it is. The pipeline expects the folder layout of the
website's repository (`notebooks/raw/stats19/`, `data/`). Requires pandas, numpy and holidays.

## daily_collisions.csv

Header | Definition
---|---
`date` | Calendar day
`all` | Collisions with at least one injured person
`ksi` | Collisions in which someone was killed or seriously injured
`fatal` | Collisions in which someone was killed

## Sources and licences

- Department for Transport, Road Safety Data (STATS19), collisions 1979 to 2025, accessed on
  15 October 2026. Contains public sector information licensed under the
  [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/).

Everything else in this folder: © John Brüne, all rights reserved (see the main README).
