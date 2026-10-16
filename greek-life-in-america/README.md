# How Popular Is Greek Life?

Data and code behind the story
[How Popular Is Greek Life?](https://pointzerofive.net/2026/02/greek-life-in-america) (#002,
6 March 2026, from before the relaunch; English only).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/greek-life-in-america/story_002_greek_life.ipynb)

File | Contents
---|---
`story_002_greek_life.ipynb` | Python notebook with the numbers and charts of the story
`us-college-greek-life.json` | Published results: 24 universities, applicants and fraternity and sorority shares
`us-top200-longitudinal.json` | Published results: admissions panel 2001 to 2022 and Greek-life snapshots for the 200 universities with the most applicants
`us_college_greek_raw.csv` | Input for `us-college-greek-life.json`
`us-top200-admissions-2000-2022.csv` | IPEDS admissions panel, one row per university and year
`us_college_greek_pipeline.py` | Builds `us-college-greek-life.json`
`us_top200_longitudinal_pipeline.py` | Builds the admissions panel and `us-top200-longitudinal.json`

## us_college_greek_raw.csv

Header | Definition
---|---
`university` | University
`region` | US region
`control` | Public or private
`applicants` | First-year applicants (Common Data Set, C1)
`admit_rate` | Admission rate in percent
`greek_rate` | Share of undergraduates in fraternities or sororities, percent (Common Data Set, F1)
`undergrads` | Undergraduates
`cds_year` | Year of the Common Data Set

## Sources and licences

- Common Data Set 2023-2024 of each university (C1, F1) and institutional reports.
- IPEDS through the [Urban Institute Education Data API](https://educationdata.urban.org/).
- Greek-life snapshots: [College Transitions](https://www.collegetransitions.com/dataverse/greek-life)
  and the [Internet Archive](https://web.archive.org/).

Code and notebook: © John Brüne, all rights reserved (see the main README).
