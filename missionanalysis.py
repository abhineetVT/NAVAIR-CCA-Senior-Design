"""
CCA CONOPS Trade Study — Air-to-Air vs Strike Mission Simulation
==================================================================

Purpose
-------
Monte Carlo trade-study tool to help decide whether a carrier-based
Collaborative Combat Aircraft (CCA) should be optimized around the
Air-to-Air (Counter-Air Fighter Sweep) mission or the Strike mission,
per the 2026-2027 Navy UG Team CCA RFP.

The tool scores each mission type (and force-package variants of each)
against the four pillars called out in the RFP / design review:

    1. LETHALITY       - probability of achieving a mission kill
    2. SURVIVABILITY    - probability the CCA (and any manned wingman)
                          returns from the sortie
    3. SUSTAINABILITY   - sortie generation rate the air wing can sustain,
                          given turnaround time, reliability, and attrition
    4. AFFORDABILITY    - cost per mission kill / cost per campaign,
                          including attrition replacement

IMPORTANT — ABOUT THE NUMBERS IN THIS SCRIPT
----------------------------------------------
Every probability, rate, and cost figure below (kill-chain stage Pk,
threat engagement rates, MMH/FH, unit costs, etc.) is a NOTIONAL,
UNCLASSIFIED placeholder chosen only to make the simulation runnable
end-to-end. They are not derived from any weapon performance data,
threat system data, or classified source. Before you use this for your
design review, replace them with numbers you can defend:
    - Kill-chain stage probabilities  -> your ISR/sensor trade study
    - Threat engagement rates          -> unclassified open-literature
                                          IADS/threat-ring assumptions
                                          your team defines for the RFP's
                                          "contested airspace" scenario
    - Weapon unit costs                -> your team's cost-estimating
                                          relationship (CER) / cited
                                          open-source weapon cost data
    CCA unit flyaway cost is NO LONGER a placeholder: it now uses Team 11's
    own PRM 2 cost-basis figures ($15M Navy target / $30M USAF-anchored
    threshold) instead of an assumed discount off a crewed jet. See the
    CostModel class below for the sourcing.
Everything that IS fixed by the RFP (combat radius, ordnance load,
dash speed, combat duration, Nz, MTOW, etc.) is pulled directly from
the RFP text and flagged as such in comments.

Kill chain model
-----------------
Uses the classic F2T2EA chain (Find - Fix - Track - Target - Engage -
Assess). Mission success requires all six stages to succeed; Engage
success itself depends on number of weapons carried and single-shot Pk,
so multiple ordnance = multiple looks at the Engage stage (shoot-look-
shoot logic), not a single roll.

Usage
-----
    python3 missionanalysis.py

Outputs (written next to this script):
    trade_study_results.csv      - summary metrics per mission/package
    trade_study_radar.png        - 4-pillar radar chart, A2A vs Strike
    trade_study_sensitivity.png  - lethality/survivability vs package size
"""

from __future__ import annotations

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from dataclasses import dataclass, field
from typing import Dict, List

RNG = np.random.default_rng(seed=30)  # reproducible runs; change/remove seed for fresh draws


# ===========================================================================
# 1. RFP-DERIVED MISSION PARAMETERS  (values taken from the RFP where noted)
# ===========================================================================

@dataclass
class MissionProfile:
    name: str
    combat_radius_nm_threshold: float      # RFP minimum
    combat_radius_nm_desired: float        # RFP desired (stretch)
    dash_speed_mach_threshold: float
    dash_speed_mach_desired: float
    combat_duration_min: float             # RFP: time on station at max thrust
    weapon_name: str
    weapon_qty: int
    weapon_pk_single_shot: float           # NOTIONAL - replace with team value
    sensor_weight_lb: float = 1000         # RFP: avionics/sensor weight, both missions
    ingress_profile: str = "high_altitude" # "high_altitude" or "sea_level_dash"
    # Kill-chain stage probabilities (F2T2EA), excluding Engage (computed from
    # weapon_qty x weapon_pk_single_shot). NOTIONAL placeholders.
    p_find: float = 0.90
    p_fix: float = 0.85
    p_track: float = 0.85
    p_target: float = 0.90
    p_assess: float = 0.90
    # Threat exposure model (NOTIONAL): expected number of hostile engagement
    # opportunities the CCA faces during ingress/combat/egress, and the
    # probability any single engagement results in an aircraft loss once it
    # occurs (already net of self-protection / EW / maneuvering).
    threat_encounters_expected: float = 1.0
    p_loss_given_engagement: float = 0.12


# --- Air-to-Air (Counter-Air Fighter Sweep) --------------------------------
# RFP: 500 nm minimum / 700 nm desired combat radius; combat = 2 min
# (5 min desired) at max thrust, best-turn speed, 10,000 ft; Mach 0.8
# dash (0.95 desired) at 30,000 ft; ordnance = 2x AIM-120D; sensors 1000 lb.
AIR_TO_AIR = MissionProfile(
    name="Air-to-Air (Fighter Sweep)",
    combat_radius_nm_threshold=500,
    combat_radius_nm_desired=700,
    dash_speed_mach_threshold=0.80,
    dash_speed_mach_desired=0.95,
    combat_duration_min=2.0,
    weapon_name="AIM-120D",
    weapon_qty=2,
    weapon_pk_single_shot=0.75,          # NOTIONAL BVR single-shot Pk
    sensor_weight_lb=1000,
    ingress_profile="high_altitude",
    p_find=0.88, p_fix=0.82, p_track=0.78, p_target=0.85, p_assess=0.90,
    threat_encounters_expected=1.4,       # short, high-intensity merge
    p_loss_given_engagement=0.15,
)

# --- Strike ------------------------------------------------------------
# RFP: 500 nm minimum / 700 nm desired combat radius; mid-mission combat =
# 50 nm sea-level dashes (ingress + egress) at intermediate thrust, Mach
# 0.8 (0.90 desired); ordnance = 4x GBU-53/B SDB-II; sensors 1000 lb.
STRIKE = MissionProfile(
    name="Strike",
    combat_radius_nm_threshold=500,
    combat_radius_nm_desired=700,
    dash_speed_mach_threshold=0.80,
    dash_speed_mach_desired=0.90,
    combat_duration_min=None,             # driven by 50 nm dash legs instead
    weapon_name="GBU-53/B SDB-II",
    weapon_qty=4,
    weapon_pk_single_shot=0.85,           # NOTIONAL precision-guided Pk
    sensor_weight_lb=1000,
    ingress_profile="sea_level_dash",
    p_find=0.85, p_fix=0.90, p_track=0.90, p_target=0.92, p_assess=0.85,
    threat_encounters_expected=2.2,       # two IADS-transit legs (in/out)
    p_loss_given_engagement=0.10,
)

MISSIONS: Dict[str, MissionProfile] = {"AtA": AIR_TO_AIR, "Strike": STRIKE}


# ===========================================================================
# 2. COST MODEL
# ===========================================================================
# CCA unit cost is now GROUNDED in Team 11's own PRM 2 cost-basis slide
# (PRM_2_Slide_Deck.pptx, "Cost Basis & Market Research"), not an assumed
# discount off a crewed jet:
#   - Threshold: <=$30M/unit  -> anchored to USAF CCA Increment 1 funded
#     target of $25-30M, FY27 budget tracking under that ceiling.
#   - Target:     ~$15M/unit  -> the Navy's own public CCA cost goal, about
#     half the USAF figure, and the most directly applicable data point
#     since this RFP is the Navy variant of that program.
#   - Manned reference points carried for context only: F/A-18E/F
#     $67-73M, F-35C $110.8M (Lots 18-19) -> at $30M this design runs
#     ~40% of a Super Hornet and ~27% of an F-35C.
# Two scenarios are modeled below (COST_TARGET, COST_THRESHOLD) so you can
# show the Navy the affordability range rather than a single point.
#
# Weapon unit costs are STILL NOTIONAL open-source order-of-magnitude
# placeholders, not sourced to your deck -- flag these to Mission
# Operations to cite properly before this goes in front of a review board.

@dataclass
class CostModel:
    cca_unit_cost_musd: float = 30.0       # override per-scenario below
    weapon_cost_musd: Dict[str, float] = field(default_factory=lambda: {
        "AIM-120D": 1.2,          # NOTIONAL, open-source order-of-magnitude
        "GBU-53/B SDB-II": 0.15,  # NOTIONAL, open-source order-of-magnitude
    })
    mmh_per_fh: float = 8.0                # maintenance man-hours / flight hr, NOTIONAL
    sortie_duration_hr: float = 3.0        # NOTIONAL, ~ combat radius / cruise speed
    turnaround_hr: float = 4.0             # NOTIONAL deck/hangar turn time
    maintainer_cost_per_hr_musd: float = 0.00012  # NOTIONAL burdened labor rate

    # Manned baselines carried for reference/affordability framing only.
    fa18ef_flyaway_musd: float = 70.0      # PRM 2: F/A-18E/F $67-73M
    f35c_flyaway_musd: float = 110.8       # PRM 2: F-35C Lots 18-19


# Two cost scenarios from PRM 2: Navy target and USAF-anchored threshold.
COST_TARGET = CostModel(cca_unit_cost_musd=15.0)
COST_THRESHOLD = CostModel(cca_unit_cost_musd=30.0)
COST_SCENARIOS: Dict[str, CostModel] = {"target_15M": COST_TARGET, "threshold_30M": COST_THRESHOLD}

COST = COST_THRESHOLD  # default/conservative scenario used where a single CostModel is needed


# ===========================================================================
# 3. KILL-CHAIN / ATTRITION MONTE CARLO ENGINE
# ===========================================================================

def simulate_sortie(mission: MissionProfile, rng: np.random.Generator) -> dict:
    """
    Simulate one CCA sortie through the F2T2EA kill chain and a threat
    exposure model, returning mission-kill and aircraft-loss outcomes.
    """
    # --- F2T2EA chain up through Target ---
    chain_ok = (
        rng.random() < mission.p_find
        and rng.random() < mission.p_fix
        and rng.random() < mission.p_track
        and rng.random() < mission.p_target
    )

    # --- Engage: shoot-look-shoot across available ordnance ---
    engage_success = False
    shots_expended = 0
    if chain_ok:
        for _ in range(mission.weapon_qty):
            shots_expended += 1
            if rng.random() < mission.weapon_pk_single_shot:
                engage_success = True
                break  # target killed, no need for further shots

    # --- Assess ---
    mission_kill = chain_ok and engage_success and (rng.random() < mission.p_assess)

    # --- Survivability: Poisson-distributed threat engagements, each with
    #     independent probability of resulting in aircraft loss ---
    n_engagements = rng.poisson(mission.threat_encounters_expected)
    aircraft_lost = False
    for _ in range(n_engagements):
        if rng.random() < mission.p_loss_given_engagement:
            aircraft_lost = True
            break

    return {
        "mission_kill": mission_kill,
        "shots_expended": shots_expended,
        "aircraft_lost": aircraft_lost,
        "n_threat_engagements": n_engagements,
    }


def simulate_formation(mission: MissionProfile, package_size: int,
                        n_trials: int, rng: np.random.Generator) -> pd.DataFrame:
    """
    Simulate `n_trials` strike/fighter-sweep packages of `package_size` CCA,
    each flying `simulate_sortie` independently. Package-level lethality =
    probability at least one CCA achieves a mission kill (mutually
    supporting shooters); package-level survivability = fraction of CCA in
    the package that return.
    """
    records = []
    for t in range(n_trials):
        sorties = [simulate_sortie(mission, rng) for _ in range(package_size)]
        kills = sum(s["mission_kill"] for s in sorties)
        losses = sum(s["aircraft_lost"] for s in sorties)
        records.append({
            "package_kill": kills >= 1,
            "n_kills": kills,
            "n_losses": losses,
            "survival_rate": 1 - losses / package_size,
            "shots_expended": sum(s["shots_expended"] for s in sorties),
        })
    return pd.DataFrame(records)


# ===========================================================================
# 4. SUSTAINABILITY MODEL
# ===========================================================================

def sustainability_metrics(mission: MissionProfile, package_size: int,
                            survival_rate: float, cost: CostModel = COST) -> dict:
    """
    Max sustainable sorties/day per aircraft, and the fleet size needed to
    keep `package_size` CCA on the flight schedule every day for a
    `campaign_days`-long campaign given attrition. NOTIONAL turnaround /
    reliability inputs.
    """
    cycle_hr = cost.sortie_duration_hr + cost.turnaround_hr
    sorties_per_day_per_tail = 24 / cycle_hr
    daily_attrition_rate = 1 - survival_rate  # per-sortie loss rate applied daily

    campaign_days = 30  # NOTIONAL campaign horizon
    # Aircraft needed on day 1 to guarantee `package_size` available every
    # day for campaign_days, replacing losses from a notional depot/spares
    # pipeline is out of scope here -> report REQUIRED reserve fleet instead.
    expected_losses_over_campaign = package_size * daily_attrition_rate * campaign_days
    required_reserve_fleet = package_size + expected_losses_over_campaign

    return {
        "sorties_per_day_per_tail": sorties_per_day_per_tail,
        "expected_losses_30day_campaign": expected_losses_over_campaign,
        "required_fleet_for_30day_campaign": required_reserve_fleet,
        "mmh_per_fh": cost.mmh_per_fh,
    }


# ===========================================================================
# 5. AFFORDABILITY MODEL
# ===========================================================================

def affordability_metrics(mission: MissionProfile, df: pd.DataFrame,
                           package_size: int, cost: CostModel = COST) -> dict:
    p_kill = df["package_kill"].mean()
    mean_losses = df["n_losses"].mean()
    mean_shots = df["shots_expended"].mean()

    weapon_unit_cost = cost.weapon_cost_musd[mission.weapon_name]
    weapons_cost = mean_shots * weapon_unit_cost
    attrition_cost = mean_losses * cost.cca_unit_cost_musd
    package_flyaway_cost = package_size * cost.cca_unit_cost_musd

    cost_per_sortie_package = package_flyaway_cost * 0.0 + weapons_cost + attrition_cost
    # ^ flyaway cost is a sunk procurement cost, not a per-sortie operating
    # cost; kept at 0 contribution here and reported separately below.
    cost_per_mission_kill = (weapons_cost + attrition_cost) / p_kill if p_kill > 0 else float("inf")

    return {
        "cca_unit_flyaway_cost_musd": cost.cca_unit_cost_musd,
        "package_procurement_cost_musd": package_flyaway_cost,
        "expected_weapons_cost_musd_per_sortie": weapons_cost,
        "expected_attrition_cost_musd_per_sortie": attrition_cost,
        "cost_per_mission_kill_musd": cost_per_mission_kill,
    }


# ===========================================================================
# 6. RUN THE TRADE STUDY
# ===========================================================================

def run_trade_study(package_sizes: List[int] = (2, 4, 6), n_trials: int = 20_000) -> pd.DataFrame:
    """Runs every mission x package-size x cost-scenario combination, so the
    affordability pillar reflects both PRM 2 cost points ($15M target,
    $30M threshold) rather than a single assumed number."""
    rows = []
    for key, mission in MISSIONS.items():
        for pkg in package_sizes:
            df = simulate_formation(mission, pkg, n_trials, RNG)

            lethality = df["package_kill"].mean()
            survivability = df["survival_rate"].mean()
            sustain = sustainability_metrics(mission, pkg, survivability)

            for cost_key, cost_model in COST_SCENARIOS.items():
                afford = affordability_metrics(mission, df, pkg, cost=cost_model)

                rows.append({
                    "mission": mission.name,
                    "mission_key": key,
                    "package_size": pkg,
                    "cost_scenario": cost_key,
                    "lethality_Pkill": lethality,
                    "survivability_mean_return_rate": survivability,
                    "sorties_per_day_per_tail": sustain["sorties_per_day_per_tail"],
                    "required_fleet_30day_campaign": sustain["required_fleet_for_30day_campaign"],
                    "cca_unit_cost_musd": afford["cca_unit_flyaway_cost_musd"],
                    "cost_per_mission_kill_musd": afford["cost_per_mission_kill_musd"],
                    "pct_of_fa18ef_flyaway": afford["cca_unit_flyaway_cost_musd"] / cost_model.fa18ef_flyaway_musd,
                    "pct_of_f35c_flyaway": afford["cca_unit_flyaway_cost_musd"] / cost_model.f35c_flyaway_musd,
                    "combat_radius_nm_threshold": mission.combat_radius_nm_threshold,
                    "combat_radius_nm_desired": mission.combat_radius_nm_desired,
                })
    return pd.DataFrame(rows)


def normalize_for_radar(results: pd.DataFrame, package_size: int,
                         cost_scenario: str = "threshold_30M") -> pd.DataFrame:
    """Min-max normalize the 4 pillars to [0,1] (higher = better) for the
    radar chart, using a fixed package size AND cost scenario for an
    apples-to-apples compare. Affordability and required-fleet are
    cost-like, so they're inverted."""
    sub = results[(results["package_size"] == package_size)
                  & (results["cost_scenario"] == cost_scenario)].copy()

    def norm(series, invert=False):
        lo, hi = series.min(), series.max()
        if hi == lo:
            return pd.Series([1.0] * len(series), index=series.index)
        n = (series - lo) / (hi - lo)
        return 1 - n if invert else n

    sub["Lethality"] = norm(sub["lethality_Pkill"])
    sub["Survivability"] = norm(sub["survivability_mean_return_rate"])
    sub["Sustainability"] = norm(sub["required_fleet_30day_campaign"], invert=True)
    sub["Affordability"] = norm(sub["cost_per_mission_kill_musd"], invert=True)
    return sub


# ===========================================================================
# 7. PLOTS
# ===========================================================================

def plot_radar(sub: pd.DataFrame, out_path: str):
    pillars = ["Lethality", "Survivability", "Sustainability", "Affordability"]
    angles = np.linspace(0, 2 * np.pi, len(pillars), endpoint=False).tolist()
    angles += angles[:1]

    fig, ax = plt.subplots(figsize=(6, 6), subplot_kw=dict(polar=True))
    for _, row in sub.iterrows():
        values = [row[p] for p in pillars]
        values += values[:1]
        ax.plot(angles, values, linewidth=2, label=row["mission"])
        ax.fill(angles, values, alpha=0.15)

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(pillars)
    ax.set_ylim(0, 1)
    ax.set_title("CCA CONOPS Trade Study: Air-to-Air vs Strike\n"
                  f"(package size = {sub['package_size'].iloc[0]})", pad=20)
    ax.legend(loc="upper right", bbox_to_anchor=(1.3, 1.1))
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)


def plot_sensitivity(results: pd.DataFrame, out_path: str, cost_scenario: str = "threshold_30M"):
    """Lethality/survivability don't depend on cost scenario, but `results`
    now has one row per cost scenario per package size -> filter to one
    scenario so each line is plotted once, not doubled up."""
    sub_all = results[results["cost_scenario"] == cost_scenario]
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.5))
    for key in sub_all["mission_key"].unique():
        sub = sub_all[sub_all["mission_key"] == key]
        axes[0].plot(sub["package_size"], sub["lethality_Pkill"], marker="o", label=sub["mission"].iloc[0])
        axes[1].plot(sub["package_size"], sub["survivability_mean_return_rate"], marker="o", label=sub["mission"].iloc[0])

    axes[0].set_title("Lethality vs Formation Size")
    axes[0].set_xlabel("Package size (# CCA)")
    axes[0].set_ylabel("P(package achieves ≥1 mission kill)")
    axes[0].legend()

    axes[1].set_title("Survivability vs Formation Size")
    axes[1].set_xlabel("Package size (# CCA)")
    axes[1].set_ylabel("Mean fraction of package returned")
    axes[1].legend()

    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)


def plot_affordability(results: pd.DataFrame, out_path: str, package_size: int = 4):
    """New: cost-per-mission-kill under both PRM 2 cost scenarios ($15M
    Navy target vs $30M USAF-anchored threshold), plus unit cost shown as
    a % of the F/A-18E/F and F-35C flyaway cost for framing."""
    sub = results[results["package_size"] == package_size].copy()
    scenario_labels = {"target_15M": "$15M (Navy target)", "threshold_30M": "$30M (threshold)"}
    sub["scenario_label"] = sub["cost_scenario"].map(scenario_labels)

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.5))

    missions = sub["mission"].unique()
    x = np.arange(len(scenario_labels))
    width = 0.35
    for i, m in enumerate(missions):
        msub = sub[sub["mission"] == m].sort_values("cost_scenario", ascending=False)
        axes[0].bar(x + i * width, msub["cost_per_mission_kill_musd"], width, label=m)
    axes[0].set_xticks(x + width / 2)
    axes[0].set_xticklabels([scenario_labels["threshold_30M"], scenario_labels["target_15M"]])
    axes[0].set_ylabel("$M per mission kill")
    axes[0].set_title(f"Cost per Mission Kill by Cost Scenario\n(package size = {package_size})")
    axes[0].legend()

    # Unit cost as % of manned baselines (same for both missions, so one bar per scenario)
    one_mission = sub[sub["mission"] == missions[0]].sort_values("cost_scenario", ascending=False)
    axes[1].bar(x - width / 2, one_mission["pct_of_fa18ef_flyaway"] * 100, width, label="% of F/A-18E/F")
    axes[1].bar(x + width / 2, one_mission["pct_of_f35c_flyaway"] * 100, width, label="% of F-35C")
    axes[1].set_xticks(x)
    axes[1].set_xticklabels([scenario_labels["threshold_30M"], scenario_labels["target_15M"]])
    axes[1].set_ylabel("% of manned flyaway cost")
    axes[1].set_title("CCA Unit Cost vs Manned Baselines")
    axes[1].legend()

    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)


# ===========================================================================
# 8. WEIGHTED DECISION MATRIX  —  EDIT THE WEIGHTS BELOW TO MATCH YOUR TEAM
# ===========================================================================
#
# THIS IS THE PART YOU EDIT.
#
# The four numbers below say how much your team cares about each pillar,
# and they MUST add up to 1.0. Raise a number to make that pillar matter
# more to the final decision; lower it to make it matter less. Whatever
# number you pick, write one sentence in your report citing WHY — e.g.
# "Affordability weighted 0.30 because RFP Report Requirement (j) makes
# unit cost mandatory, and our PRM 2 stakeholder analysis found the Navy
# Program Office is cost-growth sensitive." A weight with no justification
# is just an opinion; a weight tied to an RFP section or stakeholder is a
# defensible design decision.
#
# Quick way to sanity-check your numbers: they should mirror how your team
# already weighted MoM-01..MoM-06 in PRM 2 (e.g. you weighted Unit Cost at
# 0.20 there — that's a signal for how much weight Affordability deserves
# here too).

PILLAR_WEIGHTS = {
    "Lethality":      0.50,   
    "Survivability":  0.30,   
    "Sustainability": 0.10,   
    "Affordability":  0.10,   
}                             


def _check_weights(weights: Dict[str, float]):
    total = sum(weights.values())
    if abs(total - 1.0) > 1e-6:
        raise ValueError(
            f"PILLAR_WEIGHTS must sum to 1.0 — right now they sum to {total:.3f}. "
            f"Go adjust the numbers in PILLAR_WEIGHTS so they add up to 1.0."
        )


def compute_weighted_scores(results: pd.DataFrame,
                             weights: Dict[str, float] = None) -> pd.DataFrame:
    """
    For every (package_size, cost_scenario) combination: normalize the 4
    pillars to [0,1] across the two missions (same method as the radar
    chart), multiply each pillar by its weight, and sum -> one weighted
    score per mission per scenario. Higher score = better fit to your
    team's stated priorities. Also flags the winner and the margin between
    missions, so you can see at a glance whether it's a close call or a
    clear win.

    Pass a custom `weights` dict to test different priorities without
    touching PILLAR_WEIGHTS, e.g.:
        compute_weighted_scores(results, weights={"Lethality": 0.4,
            "Survivability": 0.4, "Sustainability": 0.1, "Affordability": 0.1})
    """
    if weights is None:
        weights = PILLAR_WEIGHTS
    _check_weights(weights)

    rows = []
    for pkg in sorted(results["package_size"].unique()):
        for scenario in results["cost_scenario"].unique():
            sub = normalize_for_radar(results, package_size=pkg, cost_scenario=scenario)
            sub = sub.copy()
            sub["Weighted_Score"] = sum(sub[p] * w for p, w in weights.items())
            rows.append(sub[["mission", "mission_key", "package_size", "cost_scenario",
                              "Lethality", "Survivability", "Sustainability", "Affordability",
                              "Weighted_Score"]])
    scored = pd.concat(rows, ignore_index=True)

    # Mark winner + margin within each (package_size, cost_scenario) group.
    # (Using transform instead of groupby().apply() here — apply() silently
    # drops the group-by key columns from the returned frame in some pandas
    # versions, which breaks later filtering on package_size/cost_scenario.)
    group_cols = ["package_size", "cost_scenario"]
    group_max = scored.groupby(group_cols)["Weighted_Score"].transform("max")
    group_min = scored.groupby(group_cols)["Weighted_Score"].transform("min")
    scored["is_winner"] = scored["Weighted_Score"] == group_max
    scored["margin"] = group_max - group_min
    return scored


def plot_weighted_decision(scored: pd.DataFrame, out_path: str,
                            package_size: int = 4, cost_scenario: str = "threshold_30M",
                            weights: Dict[str, float] = None):
    """Stacked bar showing each mission's weighted score, broken down by
    how much each pillar contributed — so you can see WHICH pillar is
    driving the decision, not just who won."""
    if weights is None:
        weights = PILLAR_WEIGHTS
    sub = scored[(scored["package_size"] == package_size)
                 & (scored["cost_scenario"] == cost_scenario)]

    pillars = ["Lethality", "Survivability", "Sustainability", "Affordability"]
    fig, ax = plt.subplots(figsize=(7, 5))

    missions = sub["mission"].tolist()
    bottoms = np.zeros(len(missions))
    for pillar in pillars:
        contributions = (sub[pillar] * weights[pillar]).to_numpy()
        ax.bar(missions, contributions, bottom=bottoms,
               label=f"{pillar} (weight={weights[pillar]:.2f})")
        bottoms += contributions

    for i, total in enumerate(bottoms):
        ax.text(i, total + 0.02, f"{total:.2f}", ha="center", fontweight="bold")

    ax.set_ylim(0, 1.15)
    ax.set_ylabel("Weighted Decision Score (higher = better fit to your priorities)")
    ax.set_title(f"Weighted Mission Decision — package size {package_size}, {cost_scenario}\n"
                 f"Margin between missions: {sub['margin'].iloc[0]:.3f}")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.12), ncol=2)
    fig.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)


# ===========================================================================
# MAIN
# ===========================================================================

if __name__ == "__main__":
    results = run_trade_study(package_sizes=[2, 4, 6], n_trials=20_000)

    print("\n=== CCA CONOPS Trade Study Summary ===\n")
    print(results.to_string(index=False, float_format=lambda x: f"{x:,.3f}"))

    results.to_csv("trade_study_results.csv", index=False)

    radar_sub = normalize_for_radar(results, package_size=4, cost_scenario="threshold_30M")
    plot_radar(radar_sub, "trade_study_radar.png")
    plot_sensitivity(results, "trade_study_sensitivity.png")
    plot_affordability(results, "trade_study_affordability.png", package_size=4)

    # --- Weighted decision matrix (uses PILLAR_WEIGHTS -- edit that dict above) ---
    scored = compute_weighted_scores(results)
    scored.to_csv("trade_study_weighted_decision.csv", index=False)
    plot_weighted_decision(scored, "trade_study_weighted_decision.png",
                            package_size=4, cost_scenario="threshold_30M")

    print("\n=== Weighted Decision (package size = 4, $30M threshold cost) ===")
    winner_row = scored[(scored["package_size"] == 4)
                         & (scored["cost_scenario"] == "threshold_30M")
                         & (scored["is_winner"])]
    print(scored[(scored["package_size"] == 4) & (scored["cost_scenario"] == "threshold_30M")]
          .to_string(index=False, float_format=lambda x: f"{x:,.3f}"))
    print(f"\nWeights used: {PILLAR_WEIGHTS}")
    if not winner_row.empty:
        margin = winner_row["margin"].iloc[0]
        call = "a close call — worth flagging assumption sensitivity in your report" if margin < 0.15 \
            else "a fairly clear win"
        print(f"Winner: {winner_row['mission'].iloc[0]}  (margin {margin:.3f} -> {call})")

    print("\nWrote: trade_study_results.csv, trade_study_radar.png, "
          "trade_study_sensitivity.png, trade_study_affordability.png, "
          "trade_study_weighted_decision.csv, trade_study_weighted_decision.png")