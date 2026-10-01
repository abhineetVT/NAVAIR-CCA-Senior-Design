# CCA Trade Study - Strike vs Air-to-Air
# Team 11, Navy CCA RFP (2026-2027)
#
# Monte Carlo sim that runs both missions through the F2T2EA kill chain
# (Find, Fix, Track, Target, Engage, Assess) and scores them on our 5 pillars.
#
# the Pk's, threat numbers, and weapon costs are placeholder values
# we picked so the sim would run. They are NOT real data. Weapon loadouts are
# from the RFP and the $30M unit cost is from our PRM 2 cost basis slide.
#
# Run it with: python3 missionanalysis.py
# It saves 4 plots (1_ through 4_ .png) into the same folder.

import numpy as np
import matplotlib.pyplot as plt

# ---------------------------------------------------------------------------
# Inputs
# ---------------------------------------------------------------------------
N_TRIALS = 200_000     # how many packages we simulate per mission
PACKAGE_SIZE = 4       # number of CCA flying together
CAMPAIGN_DAYS = 30     # length of the campaign for the sustainability calc
CCA_COST = 30.0        # $M per CCA (our PRM 2 threshold number)

# Find, Fix, and Track all depend on the sensors, and both missions use the
# same airframe and avionics, so we gave them the same values.
P_SENSOR = 0.87 * 0.85 * 0.83

# Mission inputs. qty = number of weapons (from the RFP: 2x AIM-120D for A2A,
# 4x SDB-II for strike). pk = single shot Pk. w_cost = $M per weapon.
# Target ID is easier for strike (GPS target that isn't moving), but confirming
# the kill (assess) is easier for A2A since a destroyed jet is obvious.
# threats = avg number of times the CCA gets engaged, p_loss = chance each
# engagement shoots it down.
MISSIONS = {
    "Air-to-Air": dict(qty=2, pk=0.75, w_cost=1.20, p_target=0.85, p_assess=0.90, threats=1.4, p_loss=0.15),
    "Strike":     dict(qty=4, pk=0.85, w_cost=0.15, p_target=0.92, p_assess=0.85, threats=2.2, p_loss=0.10),
}

# How much we care about each pillar (needs to add up to 1)
WEIGHTS = {
    "Lethality": 0.30,
    "Survivability": 0.10,
    "Sustainability": 0.20,
    "Cost-Effectiveness": 0.30,
    "Affordability": 0.10,
}

# For these pillars a smaller number is better
LOWER_IS_BETTER = {"Sustainability", "Cost-Effectiveness", "Affordability"}

rng = np.random.default_rng(42)  # fixed seed so we get the same results every time

# ---------------------------------------------------------------------------
# Monte Carlo
# ---------------------------------------------------------------------------
def simulate(mission, package_size=PACKAGE_SIZE, n_trials=N_TRIALS):
    # each row is one package, each column is one CCA in that package
    shape = (n_trials, package_size)

    # Find, Fix, Track, Target all have to work
    chain_works = rng.random(shape) < P_SENSOR * mission["p_target"]

    # Engage: shoot-look-shoot. geometric() gives us which shot hits first,
    # so if that's within our weapon count we got the target
    first_hit = rng.geometric(mission["pk"], shape)
    shots_fired = np.where(chain_works, np.minimum(first_hit, mission["qty"]), 0)

    # Assess: we only count it as a kill if we can confirm it
    killed = chain_works & (first_hit <= mission["qty"]) & (rng.random(shape) < mission["p_assess"])

    # Survivability: random number of engagements, any one of them can kill the CCA
    n_engagements = rng.poisson(mission["threats"], shape)
    lost = rng.binomial(n_engagements, mission["p_loss"]) > 0

    # package succeeds if at least one CCA gets a kill
    p_kill = killed.any(axis=1).mean()
    survival = 1 - lost.mean()

    # cost per kill = (weapons used + aircraft lost) / chance of a kill
    weapons_cost = shots_fired.sum(axis=1).mean() * mission["w_cost"]
    attrition_cost = lost.sum(axis=1).mean() * CCA_COST

    return {
        "Lethality": p_kill,
        "Survivability": survival,
        "Sustainability": package_size * (1 + (1 - survival) * CAMPAIGN_DAYS),  # fleet needed for 30 days
        "Cost-Effectiveness": (weapons_cost + attrition_cost) / p_kill,
        "Affordability": CCA_COST,  # same jet for both missions so this is always a tie
    }


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------
def score(results, weights):
    # divide each mission by the best one so the winner of each pillar gets 1.0,
    # then multiply by the weight
    scores = {}
    for mission in results:
        scores[mission] = {}
        for pillar, weight in weights.items():
            values = [results[m][pillar] for m in results]
            if pillar in LOWER_IS_BETTER:
                normalized = min(values) / results[mission][pillar]
            else:
                normalized = results[mission][pillar] / max(values)
            scores[mission][pillar] = normalized * weight
    return scores


results = {name: simulate(m) for name, m in MISSIONS.items()}
names = list(results)
colors = ["tab:blue", "tab:orange"]

# ---------------------------------------------------------------------------
# Plot 1: raw results for each pillar
# ---------------------------------------------------------------------------
units = {
    "Lethality": "P(package kill)",
    "Survivability": "Return rate",
    "Sustainability": "Fleet for 30-day campaign",
    "Cost-Effectiveness": "$M per mission kill",
}
fig, axes = plt.subplots(1, 4, figsize=(15, 4))
for ax, pillar in zip(axes, units):
    values = [results[n][pillar] for n in names]
    bars = ax.bar(names, values, color=colors)
    ax.bar_label(bars, fmt="%.3f" if values[0] < 2 else "%.1f")
    better = "lower" if pillar in LOWER_IS_BETTER else "higher"
    ax.set_title(f"{pillar}\n({better} is better)")
    ax.set_ylabel(units[pillar])
fig.suptitle(f"Pillar results, package of {PACKAGE_SIZE} CCA at ${CCA_COST:.0f}M/unit")
fig.tight_layout()
fig.savefig("1_pillar_results.png", dpi=150)

# ---------------------------------------------------------------------------
# Plot 2: weighted score, stacked so you can see which pillar helps the most
# ---------------------------------------------------------------------------
scores = score(results, WEIGHTS)
totals = {n: sum(scores[n].values()) for n in names}

fig, ax = plt.subplots(figsize=(7, 5))
bottom = np.zeros(len(names))
for pillar in WEIGHTS:
    heights = np.array([scores[n][pillar] for n in names])
    ax.bar(names, heights, bottom=bottom, label=f"{pillar} (w={WEIGHTS[pillar]:.2f})")
    bottom += heights
for i, n in enumerate(names):
    ax.text(i, totals[n] + 0.01, f"{totals[n]:.3f}", ha="center", fontweight="bold")
ax.set_ylim(0, 1.1)
ax.set_ylabel("Weighted score (1.0 = best on every pillar)")
ax.set_title(f"Weighted decision: margin {abs(totals['Strike'] - totals['Air-to-Air']):.3f}")
ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.08), ncol=2, fontsize=8)
fig.tight_layout()
fig.savefig("2_weighted_decision.png", dpi=150)

# ---------------------------------------------------------------------------
# Plot 3: does strike still win if we pick different weights?
# We try 10,000 random sets of weights and check who wins each time.
# ---------------------------------------------------------------------------
random_weights = rng.dirichlet(np.ones(len(WEIGHTS)), 10_000)  # random weights that add up to 1
score_diff = []
for w in random_weights:
    s = score(results, dict(zip(WEIGHTS, w)))
    score_diff.append(sum(s["Strike"].values()) - sum(s["Air-to-Air"].values()))
score_diff = np.array(score_diff)
strike_win_pct = 100 * (score_diff > 0).mean()

fig, ax = plt.subplots(figsize=(7, 4.5))
ax.hist(score_diff, bins=60, color="tab:orange", alpha=0.8)
ax.axvline(0, color="k", ls="--")  # right of this line = strike wins
ax.set_xlabel("Strike score minus Air-to-Air score")
ax.set_ylabel("Number of random weightings")
ax.set_title(f"Weight sensitivity: Strike wins {strike_win_pct:.0f}% of 10,000 random weightings")
fig.tight_layout()
fig.savefig("3_weight_sensitivity.png", dpi=150)

# ---------------------------------------------------------------------------
# Plot 4: how many CCA should be in a strike package?
# Run strike for 1 to 8 aircraft and compare P(kill) and cost per kill.
# ---------------------------------------------------------------------------
sizes = range(1, 9)
size_runs = [simulate(MISSIONS["Strike"], package_size=k, n_trials=50_000) for k in sizes]
p_kills = [r["Lethality"] for r in size_runs]
cost_per_kill = [r["Cost-Effectiveness"] for r in size_runs]

fig, ax1 = plt.subplots(figsize=(8, 4.5))
ax1.plot(sizes, p_kills, "o-", color="tab:orange", label="P(package kill)")
ax1.axhline(0.90, color="tab:orange", ls=":", lw=1)  # 90% success goal (placeholder, change if we get a real requirement)
ax1.set_xlabel("Strike package size (# CCA)")
ax1.set_ylabel("P(package achieves ≥1 kill)", color="tab:orange")
for k, p in zip(sizes, p_kills):
    ax1.annotate(f"{p:.2f}", (k, p), textcoords="offset points", xytext=(0, 8), ha="center", fontsize=8)

ax2 = ax1.twinx()  # second y axis for cost
ax2.plot(sizes, cost_per_kill, "s--", color="tab:gray", label="$M per mission kill")
ax2.set_ylabel("$M per mission kill (lower is better)", color="tab:gray")

ax1.set_title("Strike package sizing: lethality gain vs cost per kill")
fig.legend(loc="lower right", bbox_to_anchor=(0.88, 0.15))
fig.tight_layout()
fig.savefig("4_strike_package_size.png", dpi=150)

# ---------------------------------------------------------------------------
# Print results
# ---------------------------------------------------------------------------
print(f"Results for a {PACKAGE_SIZE}-ship package:")
for n in names:
    r = results[n]
    print(f"  {n:<11} P(kill)={r['Lethality']:.3f}  survival={r['Survivability']:.3f}  "
          f"fleet={r['Sustainability']:.1f}  $M/kill={r['Cost-Effectiveness']:.1f}  score={totals[n]:.3f}")
print(f"Strike wins {strike_win_pct:.1f}% of random weightings")

print("\nStrike package size:")
for k, p, c in zip(sizes, p_kills, cost_per_kill):
    print(f"  {k}-ship: P(kill)={p:.3f}  $M/kill={c:.1f}")