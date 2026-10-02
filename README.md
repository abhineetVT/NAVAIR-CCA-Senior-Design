# NAVAIR CCA Senior Design – Team 11 (GobbleWorks)

Code for our NAVAIR Collaborative Combat Aircraft (CCA) design project. This repository holds the requirements file and every script used for the sizing and trade studies conducted for this CCA.

Course TAs with access: Krish Bhatt (`Krishbhatt01`) and Quinn McIver (`qmciver`).

## Who did what

Each row maps a team member to their files and to the figures those files produce.

| Team member | GitHub | File | What it does | Figures it produces | Report fig. |
|---|---|---|---|---|---|
| Abhineet Srivastava | `abhineetVT` | `AVD012_Requirements.slreqx` | Requirements set | none | |
| Abhineet Srivastava | `abhineetVT` | `missionanalysis.py` | Monte Carlo comparison of the air-to-air and strike missions | `1_pillar_results.png`, `2_weighted_decision.png`, `3_weight_sensitivity.png`, `4_strike_package_size.png` | |
| Lukas Sonnleitner | `lsonnlei` | `trade_payload.m` | Strike payload trade: takeoff weight and unit cost vs. payload | `fig_payload_trade_lsonnleitner.png` | |
| Lukas Sonnleitner | `lsonnlei` | `sizeTOGW.m` | Function: sizes takeoff gross weight | none (used by other scripts) | |
| Lukas Sonnleitner | `lsonnlei` | `unitCostDAPCA.m` | Function: unit cost from the DAPCA IV model | none (used by other scripts) | |
| Harisankar Murugavel | `Harisankar-M05` | `EWtrade.m` | Internal vs. external carriage trade, and electronic warfare (EW) capability tiers | `fig_carriage_trade_hari.png`, `fig_ew_trade_hari.png`, `fig_ew_pareto_hari.png` | |
| Aditya Chatterjee | | `cca_sizing_model.m` | Empty weight buildup and takeoff weight closure | `oew_vs_wto.png` | |
| Kapil Kulkarni, Aditya Chatterjee | | `stores_carriage_cost.m` | Added cost and radar signature of internal, hybrid and external stores carriage | `fig_incremental_cost_matlab.png` | |
| Adam Osterhout | `adamo05-web` | `aerodynamic_model.m` | Drag, maximum lift, and stall and takeoff speed vs. wing sweep | 3 figures (shown on screen) | |
| Harrison Tracy | `harrisontracy123-commits` | `drag_estimator.m` | Drag polar and lift-to-drag ratio | 1 figure (shown on screen) | |
| Harrison Tracy | `harrisontracy123-commits` | `aero_range_sweep.m` | Combat radius vs. aerodynamics for random configurations and comparator aircraft | 1 figure (shown on screen), `aero_configs.csv` | |
| Charles Hughes | `Chughes36` | `propulsion_model.m` | Thrust required and fuel flow at cruise and loiter | none (values only) | |
| Anthony Viselli | `anthonyv07-afk` | `Propulsion_Graphs.m` | Takeoff weight vs. combat radius and vs. fuel consumption | 2 figures (shown on screen) | |

## How to reproduce the figures

**What you need**

- MATLAB R2018b or newer. No extra toolboxes are needed for the scripts. Opening `AVD012_Requirements.slreqx` needs the Requirements Toolbox.
- Python 3 with `numpy` and `matplotlib`.

**Steps**

1. Clone the repository and keep all files in one folder.
2. In MATLAB, open that folder and run the script for the figure you want, for example:
   ```matlab
   trade_payload
   ```
3. For the mission analysis, run from a terminal:
   ```
   python3 missionanalysis.py
   ```

Figures are saved as `.png` files in the same folder, or shown on screen where the table says so.

**Notes**

- `trade_payload.m` and `EWtrade.m` call `sizeTOGW.m` and `unitCostDAPCA.m`, so those two files must be in the same folder.
- Every other script runs on its own.
- `missionanalysis.py` and `aero_range_sweep.m` use fixed random seeds, so they give the same results on every run.

## AI use

Where AI tools helped write code, a comment in that file says so (see `trade_payload.m` and `unitCostDAPCA.m`).
