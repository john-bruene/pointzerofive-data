"""
us_top200_longitudinal_pipeline.py
-----------------------------------------------------------------
Build a longitudinal Top-200 university dataset with:
  1) IPEDS admissions panel (2001-2022)
  2) Greek-life snapshots (Wayback captures + current page)

Outputs:
  - data/us-top200-admissions-2000-2022.csv
  - data/us-top200-greek-snapshots-archive.csv
  - data/us-top200-longitudinal.json

Run from project root:
  python3 notebooks/us_top200_longitudinal_pipeline.py

Important limits:
  - IPEDS admissions endpoint used here starts in 2001.
    Output includes 2000 as requested, flagged unavailable in the panel.
  - Greek values are snapshots (not annual official IPEDS series).
-----------------------------------------------------------------
"""

from __future__ import annotations

import csv
import html
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any, Optional

ROOT = Path(__file__).parent.parent

OUT_ADMISSIONS_CSV = ROOT / 'data' / 'us-top200-admissions-2000-2022.csv'
OUT_GREEK_CSV = ROOT / 'data' / 'us-top200-greek-snapshots-archive.csv'
OUT_JSON = ROOT / 'data' / 'us-top200-longitudinal.json'

IPEDS_BASE = 'https://educationdata.urban.org/api/v1/college-university/ipeds'
GREEK_LIVE_URL = 'https://www.collegetransitions.com/dataverse/greek-life'
GREEK_CANONICAL = 'https://www.collegetransitions.com/dataverse/greek-life'

USER_AGENT = 'Mozilla/5.0 (pointzerofive longitudinal pipeline)'
TOP_N = 200
ADMISSIONS_YEARS = list(range(2001, 2023))
REQUESTED_ADMISSIONS_YEARS = list(range(2000, 2023))

US_50_DC = {
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY', 'DC',
}


@dataclass
class GreekRow:
    unitid: Optional[int]
    institution: str
    fraternities_yes_no: str
    sororities_yes_no: str
    pct_fraternity: float | None
    pct_sorority: float | None
    fraternity_raw: str
    sorority_raw: str


def normalize_name(value: str) -> str:
    v = value.lower().strip()
    v = v.replace('&', ' and ')
    v = v.replace('-', ' ')
    v = re.sub(r'[^a-z0-9\\s]', '', v)
    v = re.sub(r'\\s+', ' ', v).strip()
    return v


def name_keys(value: str) -> set[str]:
    base = normalize_name(value)
    keys = {base}

    # Common naming variants between IPEDS and editorial tables.
    if base.startswith('the '):
        keys.add(base[4:])
    keys.add(base.replace(' main campus', ''))
    keys.add(base.replace(' campus immersion', ''))
    keys.add(base.replace(' at ', ' '))
    keys.add(base.replace(' in the city of ', ' '))
    keys.add(base.replace(' university ', ' univ '))
    return {k.strip() for k in keys if k.strip()}


def fetch_text(url: str, retries: int = 4, timeout: int = 240) -> str:
    for attempt in range(retries):
        req = urllib.request.Request(url, headers={'User-Agent': USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read().decode('utf-8', 'ignore')
        except (urllib.error.URLError, TimeoutError):
            if attempt == retries - 1:
                raise
            time.sleep((attempt + 1) * 1.3)
    raise RuntimeError(f'Failed to fetch text: {url}')


def fetch_json(url: str, retries: int = 4, timeout: int = 240) -> dict[str, Any]:
    text = fetch_text(url, retries=retries, timeout=timeout)
    return json.loads(text)


def fetch_ipeds(endpoint: str, year: int) -> list[dict[str, Any]]:
    url = f'{IPEDS_BASE}/{endpoint}/{year}/?per_page=20000'
    payload = fetch_json(url)
    return payload['results']


def clean_cell(raw: str) -> str:
    txt = re.sub(r'<[^>]+>', '', raw)
    txt = html.unescape(txt)
    txt = re.sub(r'\s+', ' ', txt).strip()
    return txt


def parse_percent(value: str) -> float | None:
    v = value.strip()
    if v in {'', '-', 'Not Reported', 'N/A'}:
        return None
    if v.endswith('%'):
        v = v[:-1]
    try:
        return float(v)
    except ValueError:
        return None


def parse_greek_table(
    html_text: str,
) -> tuple[str, dict[int, GreekRow], dict[str, GreekRow]]:
    label = 'Greek Life (unknown snapshot label)'

    # Table aria-label is the cleanest source label if present.
    m = re.search(r'aria-label="([^"]*Greek Life[^"]*)"', html_text, flags=re.IGNORECASE)
    if m:
        label = clean_cell(m.group(1))
    else:
        m2 = re.search(r'"title":"(Greek Life[^"\\]*)"', html_text)
        if m2:
            label = m2.group(1)

    tbody_match = re.search(r'<tbody>(.*?)</tbody>', html_text, flags=re.IGNORECASE | re.DOTALL)
    if not tbody_match:
        raise RuntimeError('No <tbody> found in Greek table HTML')

    tbody = tbody_match.group(1)
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', tbody, flags=re.IGNORECASE | re.DOTALL)

    parsed_by_unitid: dict[int, GreekRow] = {}
    parsed_by_name: dict[str, GreekRow] = {}
    for row in rows:
        cells = [clean_cell(c) for c in re.findall(r'<td[^>]*>(.*?)</td>', row, flags=re.IGNORECASE | re.DOTALL)]
        if len(cells) < 5:
            continue

        # Newer table layout: unitid, institution, tag, fratYN, soroYN, frat%, soro%
        if len(cells) >= 7 and cells[0].isdigit():
            unitid = int(cells[0])
            institution = cells[1]
            frat_yn = cells[3]
            soro_yn = cells[4]
            frat_raw = cells[5]
            soro_raw = cells[6]
        else:
            # Older layout: institution, fratYN, soroYN, frat%, soro% (+ optional tags)
            unitid = None
            institution = cells[0]
            frat_yn = cells[1]
            soro_yn = cells[2]
            frat_raw = cells[3]
            soro_raw = cells[4]

        entry = GreekRow(
            unitid=unitid,
            institution=institution,
            fraternities_yes_no=frat_yn,
            sororities_yes_no=soro_yn,
            pct_fraternity=parse_percent(frat_raw),
            pct_sorority=parse_percent(soro_raw),
            fraternity_raw=frat_raw,
            sorority_raw=soro_raw,
        )

        if unitid is not None:
            parsed_by_unitid[unitid] = entry

        for key in name_keys(institution):
            parsed_by_name[key] = entry

    return label, parsed_by_unitid, parsed_by_name


def get_wayback_yearly_candidates() -> dict[int, list[str]]:
    cdx_url = (
        'https://web.archive.org/cdx/search/cdx?'
        + urllib.parse.urlencode(
            {
                'url': 'www.collegetransitions.com/dataverse/greek-life*',
                'output': 'json',
                'fl': 'timestamp,original,statuscode,mimetype',
                'filter': 'statuscode:200',
                'from': '2000',
                'to': '2026',
            }
        )
    )

    data = json.loads(fetch_text(cdx_url, retries=4, timeout=180))
    records = data[1:] if data else []

    by_year: dict[int, set[str]] = {}
    for rec in records:
        ts, original, status, mimetype = rec
        if status != '200' or 'html' not in mimetype:
            continue
        if '?' in original:
            continue

        normalized = original.rstrip('/')
        if not normalized.endswith('/dataverse/greek-life'):
            continue

        year = int(ts[:4])
        by_year.setdefault(year, set()).add(ts)

    # Descending timestamps so caller can attempt newest parseable capture first.
    return {year: sorted(list(stamps), reverse=True) for year, stamps in by_year.items()}


def is_top200_candidate(directory_row: dict[str, Any]) -> bool:
    return (
        directory_row.get('institution_level') == 4
        and directory_row.get('state_abbr') in US_50_DC
        and directory_row.get('currently_active_ipeds') == 1
    )


def select_top200(
    admissions_2022: list[dict[str, Any]],
    directory_2022: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    dir_by_unitid = {r['unitid']: r for r in directory_2022}
    rows: list[dict[str, Any]] = []

    for a in admissions_2022:
        if a.get('sex') != 99:
            continue
        applicants = a.get('number_applied')
        if applicants is None:
            continue

        unitid = a['unitid']
        d = dir_by_unitid.get(unitid)
        if not d or not is_top200_candidate(d):
            continue

        rows.append(
            {
                'unitid': unitid,
                'institution_name': d['inst_name'],
                'state_abbr': d['state_abbr'],
                'inst_control': d.get('inst_control'),
                'sector': d.get('sector'),
                'institution_level': d.get('institution_level'),
                'offering_highest_degree': d.get('offering_highest_degree'),
                'applicants_2022': applicants,
            }
        )

    rows.sort(key=lambda x: x['applicants_2022'], reverse=True)
    top200 = rows[:TOP_N]
    for i, row in enumerate(top200, start=1):
        row['rank_2022_by_applicants'] = i
    return top200


def safe_ratio(numer: int | None, denom: int | None) -> float | None:
    if numer is None or denom is None or denom == 0:
        return None
    return round(numer / denom, 6)


def build_admissions_panel(
    top200: list[dict[str, Any]],
    admissions_by_year: dict[int, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    top_by_unitid = {x['unitid']: x for x in top200}
    panel: list[dict[str, Any]] = []

    for year in REQUESTED_ADMISSIONS_YEARS:
        totals = (
            {r['unitid']: r for r in admissions_by_year[year] if r.get('sex') == 99}
            if year in admissions_by_year
            else {}
        )
        available = year in admissions_by_year
        for unitid, school in top_by_unitid.items():
            a = totals.get(unitid)
            applicants = a.get('number_applied') if a else None
            admitted = a.get('number_admitted') if a else None
            enrolled_total = a.get('number_enrolled_total') if a else None

            panel.append(
                {
                    'year': year,
                    'unitid': unitid,
                    'institution_name': school['institution_name'],
                    'state_abbr': school['state_abbr'],
                    'rank_2022_by_applicants': school['rank_2022_by_applicants'],
                    'admissions_data_available': available,
                    'applicants': applicants,
                    'admitted': admitted,
                    'enrolled_total': enrolled_total,
                    'admit_rate': safe_ratio(admitted, applicants),
                    'yield_rate': safe_ratio(enrolled_total, admitted),
                }
            )

    return panel


def build_greek_panel(
    top200: list[dict[str, Any]],
    greek_snapshots: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    top_by_unitid = {x['unitid']: x for x in top200}
    panel: list[dict[str, Any]] = []

    for snap in greek_snapshots:
        rows_by_unitid: dict[int, GreekRow] = snap['rows_by_unitid']
        rows_by_name: dict[str, GreekRow] = snap['rows_by_name']
        for unitid, school in top_by_unitid.items():
            g = rows_by_unitid.get(unitid)
            match_type = 'unitid' if g else None
            matched_key = str(unitid) if g else None

            if g is None:
                for key in name_keys(school['institution_name']):
                    candidate = rows_by_name.get(key)
                    if candidate is not None:
                        g = candidate
                        match_type = 'name'
                        matched_key = key
                        break

            panel.append(
                {
                    'snapshot_date': snap['snapshot_date'],
                    'snapshot_year': snap['snapshot_year'],
                    'snapshot_label': snap['snapshot_label'],
                    'snapshot_source': snap['snapshot_source'],
                    'snapshot_timestamp': snap['snapshot_timestamp'],
                    'match_type': match_type,
                    'matched_key': matched_key,
                    'unitid': unitid,
                    'institution_name': school['institution_name'],
                    'state_abbr': school['state_abbr'],
                    'rank_2022_by_applicants': school['rank_2022_by_applicants'],
                    'fraternities_yes_no': g.fraternities_yes_no if g else None,
                    'sororities_yes_no': g.sororities_yes_no if g else None,
                    'pct_fraternity': g.pct_fraternity if g else None,
                    'pct_sorority': g.pct_sorority if g else None,
                    'fraternity_raw': g.fraternity_raw if g else None,
                    'sorority_raw': g.sorority_raw if g else None,
                }
            )

    return panel


def write_csv(rows: list[dict[str, Any]], out_path: Path) -> None:
    if not rows:
        raise RuntimeError(f'No rows to write: {out_path}')
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    print('Fetching base IPEDS data for top-200 selection...')
    directory_2022 = fetch_ipeds('directory', 2022)
    admissions_2022 = fetch_ipeds('admissions-enrollment', 2022)

    top200 = select_top200(admissions_2022, directory_2022)
    print(f'Top-200 schools selected: {len(top200)}')

    print('Fetching IPEDS admissions panel (2001-2022)...')
    admissions_by_year: dict[int, list[dict[str, Any]]] = {}
    for year in ADMISSIONS_YEARS:
        print(f'  - {year}')
        admissions_by_year[year] = fetch_ipeds('admissions-enrollment', year)

    admissions_panel = build_admissions_panel(top200, admissions_by_year)

    print('Fetching Wayback snapshots for Greek table...')
    yearly_candidates = get_wayback_yearly_candidates()
    print(f'  Found yearly snapshot groups: {len(yearly_candidates)}')

    greek_snapshots: list[dict[str, Any]] = []
    for year in sorted(yearly_candidates.keys()):
        parsed = False
        for ts in yearly_candidates[year]:
            archive_url = f'https://web.archive.org/web/{ts}id_/{GREEK_CANONICAL}'
            print(f'  - Wayback {year} ({ts})')
            try:
                html_text = fetch_text(archive_url, retries=3, timeout=240)
                label, rows_by_unitid, rows_by_name = parse_greek_table(html_text)
                greek_snapshots.append(
                    {
                        'snapshot_date': f'{year}-12-31',
                        'snapshot_year': year,
                        'snapshot_label': label,
                        'snapshot_source': 'wayback',
                        'snapshot_timestamp': ts,
                        'rows_by_unitid': rows_by_unitid,
                        'rows_by_name': rows_by_name,
                    }
                )
                parsed = True
                break
            except Exception as exc:
                print(f'    candidate failed ({exc})')
        if not parsed:
            print(f'    no parseable snapshot for {year}')

    print('Fetching current Greek table...')
    live_html = fetch_text(GREEK_LIVE_URL, retries=3, timeout=240)
    live_label, live_rows_by_unitid, live_rows_by_name = parse_greek_table(live_html)
    greek_snapshots.append(
        {
            'snapshot_date': str(date.today()),
            'snapshot_year': date.today().year,
            'snapshot_label': live_label,
            'snapshot_source': 'live',
            'snapshot_timestamp': None,
            'rows_by_unitid': live_rows_by_unitid,
            'rows_by_name': live_rows_by_name,
        }
    )

    greek_panel = build_greek_panel(top200, greek_snapshots)

    write_csv(admissions_panel, OUT_ADMISSIONS_CSV)
    write_csv(greek_panel, OUT_GREEK_CSV)

    # Snapshot coverage by snapshot-year for top-200.
    coverage = []
    for snap in greek_snapshots:
        matched = sum(
            1
            for row in greek_panel
            if row['snapshot_date'] == snap['snapshot_date'] and row['match_type'] is not None
        )
        coverage.append(
            {
                'snapshot_date': snap['snapshot_date'],
                'snapshot_year': snap['snapshot_year'],
                'snapshot_label': snap['snapshot_label'],
                'snapshot_source': snap['snapshot_source'],
                'snapshot_timestamp': snap['snapshot_timestamp'],
                'top200_matches': matched,
                'top200_total': len(top200),
            }
        )

    output = {
        '_comment': 'Generated by notebooks/us_top200_longitudinal_pipeline.py - do not edit manually.',
        'meta': {
            'updated': str(date.today()),
            'top200_definition': 'Top 200 institutions by applicants in 2022 (IPEDS admissions-enrollment sex=99), with institution_level=4, active IPEDS, and US 50 states + DC.',
            'requested_admissions_start_year': min(REQUESTED_ADMISSIONS_YEARS),
            'requested_admissions_end_year': max(REQUESTED_ADMISSIONS_YEARS),
            'admissions_available_start_year': min(ADMISSIONS_YEARS),
            'admissions_available_end_year': max(ADMISSIONS_YEARS),
            'admissions_limit_note': 'Urban IPEDS admissions-enrollment endpoint reports 2001-2022; year 2000 is not available there.',
            'greek_limit_note': 'Greek-life metrics are web snapshots (current + archived) of CDS-derived tables, not a complete annual 2000+ panel.',
            'sources': [
                {
                    'name': 'Urban Institute Education Data API endpoint catalog',
                    'url': 'https://educationdata.urban.org/api/v1/api-endpoints/?mode=R',
                },
                {
                    'name': 'IPEDS directory endpoint',
                    'url': 'https://educationdata.urban.org/api/v1/college-university/ipeds/directory/2022/',
                },
                {
                    'name': 'IPEDS admissions-enrollment endpoint',
                    'url': 'https://educationdata.urban.org/api/v1/college-university/ipeds/admissions-enrollment/2022/',
                },
                {
                    'name': 'College Transitions Greek Life (live)',
                    'url': GREEK_LIVE_URL,
                },
                {
                    'name': 'Internet Archive CDX API',
                    'url': 'https://web.archive.org/cdx/search/cdx',
                },
            ],
        },
        'summary': {
            'top200_count': len(top200),
            'admissions_rows': len(admissions_panel),
            'admissions_years_requested': len(REQUESTED_ADMISSIONS_YEARS),
            'admissions_years_with_source_data': len(ADMISSIONS_YEARS),
            'greek_snapshot_points': len(greek_snapshots),
            'greek_panel_rows': len(greek_panel),
            'greek_coverage_by_snapshot': coverage,
        },
        'top200': top200,
        'admissions_panel': admissions_panel,
        'greek_panel': greek_panel,
    }

    with open(OUT_JSON, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
        f.write('\n')

    print(f'Written -> {OUT_ADMISSIONS_CSV}')
    print(f'Written -> {OUT_GREEK_CSV}')
    print(f'Written -> {OUT_JSON}')


if __name__ == '__main__':
    main()
