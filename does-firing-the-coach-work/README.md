# Does changing the coach win more points?

Data and code behind the story
[Does changing the coach win more points?](https://pointzerofive.net/2026/09/does-firing-the-coach-work)
(#001, 10 September 2026; German:
[Bringt ein Trainerwechsel mehr Punkte?](https://pointzerofive.net/de/2026/09/does-firing-the-coach-work)).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/does-firing-the-coach-work/story_001_coach_firing.ipynb)
(choose the R runtime).

File | Contents
---|---
`story_001_coach_firing.ipynb` | R notebook that reproduces every number in the story, including all 18 calculation paths
`does-firing-the-coach-work.json` | Published results: main calculation, the 18 calculation paths (`specs`), chart data
`does-firing-the-coach-work.output.txt` | Console output of the pipeline run, unedited, ending with R and package versions
`coach_games_L1.csv` | Every Bundesliga match from 2012/13 to 2025/26 with the coach of each team
`matches.csv` | Every Bundesliga result from 2010/11 to 2025/26, used to check the scores
`claim.json` | Texts of the claim and of the forks, English and German
`bundesliga_matches_pipeline.R` | Builds `matches.csv` from openfootball
`coach_firing_pipeline.R` | Builds `coach_games_L1.csv` and the published results
`coach_firing_stats.R` | Estimators and cluster bootstrap
`estimation_table.R` | Builds and prints the result table of the main calculation (key `estimation` in the JSON)

The notebook runs in this folder as it is. The pipeline scripts expect the folder layout of the
website's repository (`notebooks/raw/bundesliga/`, `data/`). Requires base R and `jsonlite`.

## coach_games_L1.csv

Header | Definition
---|---
`season` | First year of the season (2012 = 2012/13)
`round` | Matchday as given by Transfermarkt, e.g. `1. Matchday`
`date` | Date of the match
`home_club_name`, `away_club_name` | Home and away club
`home_club_goals`, `away_club_goals` | Goals
`home_club_manager_name`, `away_club_manager_name` | Coach of each team in this match

## matches.csv

Header | Definition
---|---
`season` | Season, e.g. `2010-11`
`matchday` | Matchday, 1 to 34
`date` | Date of the match
`home`, `away` | Home and away club, one spelling per club across seasons
`home_goals`, `away_goals` | Goals

## Sources and licences

- Matches and coaches: [transfermarkt-datasets](https://github.com/dcaribou/transfermarkt-datasets),
  `games` table, release of 5 September 2026, CC0 1.0; data from Transfermarkt.de.
- Results for the check: [openfootball/deutschland](https://github.com/openfootball/deutschland),
  CC0 1.0.

Everything else in this folder: © John Brüne, all rights reserved (see the main README).
