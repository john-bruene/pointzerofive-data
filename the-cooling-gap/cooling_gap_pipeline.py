"""
cooling_gap_pipeline.py
──────────────────────────────────────────────────────────────────────
Data pipeline: story #003 "The Cooling Gap".

Input:  notebooks/raw/pavanello2021/*.dta  (Pavanello et al. 2021 output data,
        see notebooks/raw/pavanello2021/README.md for provenance + license)
Output: data/the-cooling-gap.json

Run from project root:
    python notebooks/cooling_gap_pipeline.py

Requires: pandas, numpy, scipy, statsmodels
──────────────────────────────────────────────────────────────────────

What it builds
  states       92 states (India, Brazil, Mexico): heat exposure (wet-bulb CDD),
               spending per person, survey-weighted AC share, households
  heatCurve    Pr(AC) vs CDD for an average household (study's logit margins)
  heatEffect   +100 CDD effect on Pr(AC), by household spending (with 95% CI)
  deciles      AC share by national spending decile, today and 2040
               (median across states, following the study's Figure 5)
  electricity  growth in household electricity use by decile, today → 2040
  withoutAc    households without AC today and in 2040, 10 RCP×SSP scenarios
  stats        every statistic quoted in the story
"""

import json
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
import statsmodels.formula.api as smf
from scipy import stats as st

ROOT = Path(__file__).parent.parent
RAW = ROOT / "notebooks" / "raw" / "pavanello2021"
OUT = ROOT / "data" / "the-cooling-gap.json"

COUNTRIES = ["India", "Brazil", "Mexico"]
SURVEYS = {"India": "NSS", "Brazil": "POF", "Mexico": "ENIGH"}
RCPS = ["rcp45", "rcp85"]
SSPS = ["SSP1", "SSP2", "SSP3", "SSP4", "SSP5"]
SCENARIOS = [f"{r}_{s}" for r in RCPS for s in SSPS]
MAIN = "rcp45_SSP2"  # "middle of the road" socio-economics, moderate warming
PROJECTION_YEAR = 2040
HOT_CDD = 100  # projected wet-bulb CDD (24 °C base) above which a state counts as hot


def read(name: str) -> pd.DataFrame:
    return pd.read_stata(RAW / name)


def r1(x: float, d: int = 1) -> float:
    return float(round(float(x), d))


# ── 1. States: heat, spending, AC share ────────────────────────────────
def build_states() -> pd.DataFrame:
    f4 = read("Figure_4.dta")
    agg = read("HH_4countries_agg_state.dta")
    df = f4.merge(
        agg[["country", "year", "state3", "exp_cap_usd_2011", "ac_sh_state_wgt"]],
        on=["country", "year", "state3"],
        how="inner",
    )
    # One state (no CDD value) cannot be placed on the heat axis
    df = df[df["mean_CDD_wb"].notna()].copy()
    df["lspend"] = np.log(df["exp_cap_usd_2011"])
    df["hot"] = df.groupby("country")["mean_CDD_wb"].transform(lambda x: x > x.median())
    df["rich"] = df.groupby("country")["exp_cap_usd_2011"].transform(lambda x: x > x.median())
    return df


def pearson(x, y) -> dict:
    r, p = st.pearsonr(x, y)
    return {"r": r1(r, 2), "p": float(p), "n": int(len(x))}


def state_stats(df: pd.DataFrame) -> dict:
    by_country = {}
    for c in COUNTRIES:
        g = df[df.country == c]
        by_country[c] = {
            "heat": pearson(g.mean_CDD_wb, g.ac_sh_state_wgt),
            "spend": pearson(g.lspend, g.ac_sh_state_wgt),
        }

    # Within-country standardized regression: AC ~ heat + spending (+ interaction)
    z = df.copy()
    for v in ["mean_CDD_wb", "lspend", "ac_sh_state_wgt"]:
        z[v] = z.groupby("country")[v].transform(lambda x: (x - x.mean()) / x.std())
    m = smf.ols("ac_sh_state_wgt ~ mean_CDD_wb + lspend", data=z).fit()
    mi = smf.ols("ac_sh_state_wgt ~ mean_CDD_wb * lspend", data=z).fit()

    # Quadrants: hotter / richer than the country's median state
    quad = {}
    for (hot, rich), g in df.groupby(["hot", "rich"]):
        key = f"{'hot' if hot else 'cool'}_{'rich' if rich else 'poor'}"
        quad[key] = {
            "states": int(len(g)),
            "households_m": r1(g.hh_state.sum() / 1e6),
            "ac_share": r1(np.average(g.ac_sh_state_wgt, weights=g.hh_state)),
        }
    hp = df[df.hot & ~df.rich].ac_sh_state_wgt
    hr = df[df.hot & df.rich].ac_sh_state_wgt
    mw = st.mannwhitneyu(hp, hr, alternative="two-sided")

    return {
        "n_states": int(len(df)),
        "by_country": by_country,
        "regression": {
            "beta_heat": r1(m.params["mean_CDD_wb"], 2),
            "beta_spend": r1(m.params["lspend"], 2),
            "p_heat": float(m.pvalues["mean_CDD_wb"]),
            "p_spend": float(m.pvalues["lspend"]),
            "r2": r1(m.rsquared, 2),
            "beta_interaction": r1(mi.params["mean_CDD_wb:lspend"], 2),
            "p_interaction": float(mi.pvalues["mean_CDD_wb:lspend"]),
        },
        "quadrants": quad,
        "hot_poor_vs_hot_rich_mannwhitney_p": float(mw.pvalue),
    }


# ── 2. Heat response curves (study's logit margins) ─────────────────────
def build_heat_curve() -> dict:
    out = {}
    for c in COUNTRIES:
        d = read(f"{SURVEYS[c]}_ac_CDD_wb_pred_prob.dta")
        out[c] = [
            {"cdd": int(a), "p": r1(m * 100), "lo": r1(lo * 100), "hi": r1(hi * 100)}
            for a, m, lo, hi in zip(d["_at1"], d["_margin"], d["_ci_lb"], d["_ci_ub"])
        ]
    return out


def build_heat_effect() -> dict:
    """dPr(AC)/dCDD by log household spending → percentage points per +100 CDD."""
    out = {}
    for c in COUNTRIES:
        d = read(f"{SURVEYS[c]}_ac_CDD_wb_exp.dta")
        d = d[(d["_at2"] >= 6) & (d["_at2"] <= 12)]
        out[c] = [
            {
                "lnSpend": float(a),
                "spend": int(round(np.exp(a), -1)),
                "pp": r1(m * 1e4, 2),
                "lo": r1(lo * 1e4, 2),
                "hi": r1(hi * 1e4, 2),
            }
            for a, m, lo, hi in zip(d["_at2"], d["_margin"], d["_ci_lb"], d["_ci_ub"])
        ]
    return out


# ── 3. Deciles: today vs 2040 ───────────────────────────────────────────
def build_deciles() -> tuple[dict, dict]:
    dec = read("HH_4countries_proj_dec.dta")
    fut = [f"ac_fut_{s}" for s in SCENARIOS]
    med = dec.groupby(["country", "dec_inc"])[["ac"] + fut].median() * 100
    ely_cols = ["ely_q", f"ely_hat_fut_int_{MAIN}_q"]
    ely = dec.groupby(["country", "dec_inc"])[ely_cols].median()

    deciles, electricity = {}, {}
    for c in COUNTRIES:
        rows, erows = [], []
        for d in range(1, 11):
            m = med.loc[(c, d)]
            rows.append(
                {
                    "decile": d,
                    "today": r1(m["ac"]),
                    "main": r1(m[f"ac_fut_{MAIN}"]),
                    "lo": r1(m[fut].min()),
                    "hi": r1(m[fut].max()),
                }
            )
            e = ely.loc[(c, d)]
            erows.append({"decile": d, "growth": r1((e[ely_cols[1]] / e["ely_q"] - 1) * 100)})
        deciles[c] = rows
        electricity[c] = erows
    deciles_meta = {
        "n_states": {c: int(dec[dec.country == c].state3.nunique()) for c in COUNTRIES}
    }
    return {"meta": deciles_meta, "series": deciles}, electricity


# ── 4. Households without AC ────────────────────────────────────────────
def build_without_ac() -> dict:
    f4 = read("Figure_4.dta")
    out = {}
    for c in COUNTRIES:
        g = f4[f4.country == c]
        out[c] = {
            "surveyYear": int(g.year.iloc[0]),
            "households": r1(g.hh_state.sum() / 1e6),
            "today": r1(g.n_without_ac.sum()),
            "todayHot": r1(g.loc[g.mean_CDD_wb >= HOT_CDD, "n_without_ac"].sum()),
            "scenarios": {s: r1(g[f"n_without_ac_{s}"].sum()) for s in SCENARIOS},
            "scenariosHot": {
                s: r1(
                    g.loc[
                        g[f"mean_CDD_2021_2060_wb_{s.split('_')[0]}_{s.split('_')[1]}"] >= HOT_CDD,
                        f"n_without_ac_{s}",
                    ].sum()
                )
                for s in SCENARIOS
            },
        }
    return out


def main() -> None:
    states = build_states()
    deciles, electricity = build_deciles()
    without = build_without_ac()

    # Totals from unrounded state values (summing rounded country values drifts by ~0.1M)
    f4 = read("Figure_4.dta")

    def hot_total(s: str) -> float:
        rcp, ssp = s.split("_")
        return f4.loc[f4[f"mean_CDD_2021_2060_wb_{rcp}_{ssp}"] >= HOT_CDD, f"n_without_ac_{s}"].sum()

    totals = {s: r1(f4[f"n_without_ac_{s}"].sum()) for s in SCENARIOS}
    totals_hot = {s: r1(hot_total(s)) for s in SCENARIOS}
    households = f4.hh_state.sum() / 1e6
    today = f4.n_without_ac.sum()
    rcp, ssp = MAIN.split("_")
    india_hot = f4.loc[
        (f4.country == "India") & (f4[f"mean_CDD_2021_2060_wb_{rcp}_{ssp}"] >= HOT_CDD),
        f"n_without_ac_{MAIN}",
    ].sum()

    stats = state_stats(states)
    stats["without_ac"] = {
        "households_today_m": r1(households),
        "today_m": r1(today),
        "today_share": r1(today / households * 100),
        "today_hot_m": r1(f4.loc[f4.mean_CDD_wb >= HOT_CDD, "n_without_ac"].sum()),
        "main_m": totals[MAIN],
        "min_m": min(totals.values()),
        "min_scenario": min(totals, key=totals.get),
        "max_m": max(totals.values()),
        "max_scenario": max(totals, key=totals.get),
        "hot_main_m": totals_hot[MAIN],
        "hot_min_m": min(totals_hot.values()),
        "hot_max_m": max(totals_hot.values()),
        "hot_main_india_share": r1(india_hot / hot_total(MAIN) * 100),
        "totals": totals,
        "totalsHot": totals_hot,
    }

    data = {
        "meta": {
            "source": "Pavanello et al. (2021), Nature Communications 12, 6460 — replication output data",
            "doi": "10.1038/s41467-021-26592-2",
            "repo": "https://github.com/Energy-a/comparative_paper_natcomms",
            "commit": "69a012536c17f47ad0235257241c64a9ade8a9d8",
            "license": "GPL-3.0 (replication repository); paper CC BY 4.0",
            "updated": date.today().isoformat(),
            "projectionYear": PROJECTION_YEAR,
            "mainScenario": MAIN,
            "hotThresholdCdd": HOT_CDD,
            "cddNote": "Cooling degree days, wet-bulb temperature, 24 °C base; state means 1970–2016 (today) and 2021–2060 (projection)",
            "spendNote": "Household expenditure in 2011 US dollars",
        },
        "states": [
            {
                "country": row.country,
                "state": row.state3,
                "surveyYear": int(row.year),
                "cdd": r1(row.mean_CDD_wb),
                "spendPc": int(round(row.exp_cap_usd_2011)),
                "ac": r1(row.ac_sh_state_wgt),
                "householdsM": r1(row.hh_state / 1e6, 3),
                "hot": bool(row.hot),
                "rich": bool(row.rich),
            }
            for row in states.sort_values(["country", "state3"]).itertuples()
        ],
        "heatCurve": build_heat_curve(),
        "heatEffect": build_heat_effect(),
        "deciles": deciles,
        "electricity": electricity,
        "withoutAc": without,
        "stats": stats,
    }

    OUT.write_text(json.dumps(data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {OUT.relative_to(ROOT)}")
    w = stats["without_ac"]
    print(
        f"  without AC: today {w['today_m']}M of {w['households_today_m']}M "
        f"({w['today_share']}%); {PROJECTION_YEAR} {MAIN} {w['main_m']}M "
        f"[{w['min_m']}–{w['max_m']}M]; hot states {w['hot_main_m']}M [{w['hot_min_m']}–{w['hot_max_m']}M]"
    )
    print(f"  regression: {stats['regression']}")
    print(f"  quadrants: {stats['quadrants']}")


if __name__ == "__main__":
    main()
