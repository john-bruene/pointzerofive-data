# Does the halfway leader usually win the Bundesliga?

Data and code behind the story
[Does the halfway leader usually win the Bundesliga?](https://pointzerofive.net/2026/10/herbstmeister-usually-champion)
(#008, 29 October 2026; German:
[Wird der Herbstmeister am Ende meistens Meister?](https://pointzerofive.net/de/2026/10/herbstmeister-usually-champion)).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/herbstmeister-usually-champion/story_008_herbstmeister.ipynb)
(choose the R runtime).

File | Contents
---|---
`story_008_herbstmeister.ipynb` | R notebook that reproduces every number in the story, including all 12 calculation paths
`herbstmeister-usually-champion.json` | Published results: main calculation, the 12 calculation paths (`specs`), one row per season, chart data
`herbstmeister-usually-champion.output.txt` | Console output of the pipeline run, unedited, ending with R and package versions
`matches_1963_2010.csv` | Every Bundesliga result from 1963/64 to 2009/10 (football.csv)
`matches.csv` | Every Bundesliga result from 2010/11 to 2025/26 (openfootball)
`reference_lists.csv` | Halfway leaders and champions from Wikipedia, used only to check the tables built from the results
`claim.json` | Texts of the claim and of the forks, English and German
`pitch.md` | The pitch: question, dispute, main calculation and forks, fixed before the analysis
`herbstmeister_pipeline.R` | Builds `matches_1963_2010.csv`, the tables of every season and the published results
`estimation_table.R` | Builds and prints the result table of the main calculation (key `estimation` in the JSON)

The notebook runs in this folder as it is. The pipeline script expects the folder layout of the
website's repository (`notebooks/raw/bundesliga/`, `data/`). Requires base R and `jsonlite`.

## matches_1963_2010.csv and matches.csv

Header | Definition
---|---
`season` | Season, e.g. `1963-64`
`matchday` | Matchday, 1 to 30 (16 clubs, 1963/64 and 1964/65), 1 to 38 (20 clubs, 1991/92) or 1 to 34
`date` | Date of the match
`home`, `away` | Home and away club
`home_goals`, `away_goals` | Goals

## reference_lists.csv

Header | Definition
---|---
`season` | First year of the season (1963 = 1963/64)
`herbstmeister_de_wikipedia` | Halfway leader as listed in the German Wikipedia article "Herbstmeister"
`herbstmeister_champion_de_wikipedia` | 1 if that article marks the halfway leader as champion
`champion_en_wikipedia` | Champion as listed in the English Wikipedia "List of German football champions"

Both pages were read on 17 November 2026.

## Sources and licences

- Results 1963/64 to 2009/10: [football.csv / deutschland](https://github.com/footballcsv/deutschland),
  CC0 1.0, an export of openfootball.
- Results 2010/11 to 2025/26: [openfootball/deutschland](https://github.com/openfootball/deutschland),
  CC0 1.0.
- `reference_lists.csv`: facts taken from Wikipedia for checking only.

Everything else in this folder: © John Brüne, all rights reserved (see the main README).
