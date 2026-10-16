"""
friday13_stats.py
──────────────────────────────────────────────────────────────────────
Comparison days, the effect and the month bootstrap for story #005 (pitch 005, §1b). The
pipeline and the notebook use the same procedure and the same random streams, so they produce
identical numbers.

For the months i with a Friday the 13th, y_i = collisions on the 13th and c_i = mean collisions
per comparison day in the same month:

    effect = 100 * (sum_i y_i / sum_i c_i - 1)        (per cent)

A bootstrap draw resamples the months with replacement and is stored as count weights. The 95%
confidence interval and p come from summarize(), the procedure of story #004 (moved here from
coach_firing_stats.py when #004 was ported to R).

  all_days:    every other day of the month
  fridays:     the 6th and the 20th (the Fridays a week before and after)
  friday_6th:  the 6th only (the design of Scanlon et al. 1993)

With holidays excluded, a 13th that is a holiday drops out, holidays are removed from the
comparison days, and a month without any comparison day left drops out.
"""

from __future__ import annotations

import calendar
import datetime as dt
import zlib
from dataclasses import dataclass

import numpy as np
import pandas as pd

ALPHA = 0.05
COMPARISONS = ("all_days", "fridays", "friday_6th")


def fridays_13th(first_year: int, last_year: int) -> list[dt.date]:
    return [dt.date(y, m, 13) for y in range(first_year, last_year + 1) for m in range(1, 13)
            if dt.date(y, m, 13).weekday() == calendar.FRIDAY]


def comparison_days(day13: dt.date, comparison: str) -> list[dt.date]:
    if comparison == "all_days":
        last = calendar.monthrange(day13.year, day13.month)[1]
        return [day13.replace(day=d) for d in range(1, last + 1) if d != 13]
    if comparison == "fridays":
        return [day13.replace(day=6), day13.replace(day=20)]
    if comparison == "friday_6th":
        return [day13.replace(day=6)]
    raise ValueError(comparison)


@dataclass(frozen=True)
class Design:
    """Arrays for one calculation path."""

    dates: tuple[dt.date, ...]  # the Fridays the 13th that count
    y: np.ndarray  # (n,) collisions on the 13th
    c: np.ndarray  # (n,) mean collisions per comparison day, same month

    @property
    def n(self) -> int:
        return len(self.y)


def build_design(counts: pd.Series, comparison: str, holidays: set[dt.date] | None) -> Design:
    """counts: collisions per day, indexed by datetime.date, every day of the period present."""
    first, last = counts.index.min(), counts.index.max()
    dates, y, c = [], [], []
    for d13 in fridays_13th(first.year, last.year):
        if holidays is not None and d13 in holidays:
            continue
        days = [d for d in comparison_days(d13, comparison)
                if holidays is None or d not in holidays]
        if not days:
            continue
        dates.append(d13)
        y.append(counts[d13])
        c.append(np.mean([counts[d] for d in days]))
    return Design(tuple(dates), np.asarray(y, float), np.asarray(c, float))


def effects(design: Design, u: np.ndarray) -> np.ndarray:
    """Effect in per cent for month weights u (b, n)."""
    return 100 * ((u @ design.y) / (u @ design.c) - 1)


def point_estimate(design: Design) -> float:
    return float(effects(design, np.ones((1, design.n)))[0])


def bootstrap(design: Design, rng: np.random.Generator, b: int) -> np.ndarray:
    u = np.empty((b, design.n))
    for r in range(b):
        u[r] = np.bincount(rng.integers(0, design.n, design.n), minlength=design.n)
    return effects(design, u)


def summarize(reps: np.ndarray, alpha: float = ALPHA) -> dict[str, float]:
    """95% confidence interval from order statistics and the matching two-sided bootstrap p-value.

    With m = alpha/2 * B, the interval is the m-th to the (B + 1 - m)-th smallest replicate and
    p = 2 * min(#{<= 0}, #{>= 0}) / B. Then p < alpha exactly when the interval excludes 0.
    """
    b = len(reps)
    m = round(alpha / 2 * b)
    assert abs(alpha / 2 * b - m) < 1e-9, "alpha/2 * B must be a whole number"
    s = np.sort(reps)
    lo, hi = float(s[m - 1]), float(s[b - m])
    p = min(1.0, 2 * min(int((reps <= 0).sum()), int((reps >= 0).sum())) / b)
    assert (p < alpha) == (lo > 0 or hi < 0), (p, lo, hi)
    return {"ci_low": lo, "ci_high": hi, "p": p}


def path_rng(seed: int, key: str) -> np.random.Generator:
    """An independent random stream per calculation path, stable across runs and machines."""
    return np.random.default_rng([seed, zlib.crc32(key.encode("utf-8"))])
