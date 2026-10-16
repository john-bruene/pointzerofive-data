# Does home advantage shrink without fans?

Data and code behind the story
[Does home advantage shrink without fans?](https://pointzerofive.net/2026/09/home-advantage-without-fans)
(#003, 24 September 2026; German:
[Schrumpft der Heimvorteil ohne Zuschauer?](https://pointzerofive.net/de/2026/09/home-advantage-without-fans)).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/home-advantage-without-fans/story_003_home_advantage.ipynb)
(choose the R runtime).

File | Contents
---|---
`story_003_home_advantage.ipynb` | R notebook that reproduces every number in the story, including all 18 calculation paths
`home-advantage-without-fans.json` | Published results: main calculation, the 18 calculation paths (`specs`), chart data
`home-advantage-without-fans.output.txt` | Console output of the pipeline run, unedited, ending with R and package versions
`games_top5.csv` | Every league match of the Bundesliga, Premier League, LaLiga, Serie A and Ligue 1 from 2012/13 to 2025/26, with attendance
`matches.csv` | Every Bundesliga result from 2010/11 to 2025/26 (openfootball), used to check the scores
`claim.json` | Texts of the claim and of the forks, English and German
`pitch.md` | The pitch: question, dispute, main calculation and forks, fixed before the analysis
`home_advantage_pipeline.R` | Builds `games_top5.csv` and the published results

The notebook runs in this folder as it is. The pipeline script expects the folder layout of the
website's repository (`notebooks/raw/home_advantage/`, `data/`). Requires base R and `jsonlite`.

## games_top5.csv

Header | Definition
---|---
`competition_id` | `L1` Bundesliga, `GB1` Premier League, `ES1` LaLiga, `IT1` Serie A, `FR1` Ligue 1
`season` | First year of the season (2012 = 2012/13)
`round` | Matchday as given by Transfermarkt, e.g. `26. Matchday`
`date` | Date of the match
`home_club_name`, `away_club_name` | Home and away club
`home_club_goals`, `away_club_goals` | Goals
`attendance` | Spectators as recorded by Transfermarkt; empty for matches without spectators (and for a few gaps, see the story)

## matches.csv

Header | Definition
---|---
`season` | Season, e.g. `2010-11`
`matchday` | Matchday, 1 to 34
`date` | Date of the match
`home`, `away` | Home and away club, one spelling per club across seasons
`home_goals`, `away_goals` | Goals

## Sources and licences

- Matches and attendance: [transfermarkt-datasets](https://github.com/dcaribou/transfermarkt-datasets),
  `games` table, release of 5 September 2026, CC0 1.0; data from Transfermarkt.de.
- Results for the check: [openfootball/deutschland](https://github.com/openfootball/deutschland),
  CC0 1.0.

Everything else in this folder: © John Brüne, all rights reserved (see the main README).
