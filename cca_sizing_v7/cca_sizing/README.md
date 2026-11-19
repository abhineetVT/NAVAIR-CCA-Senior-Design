# CCA Sizing Framework

A multidisciplinary conceptual-sizing tool for a carrier-based, autonomous
0.8-spot-factor Collaborative Combat Aircraft (CCA): aerodynamics,
propulsion, weights, mission analysis and constraint analysis closed in a
single fixed-point TOGW loop, plus two standalone (not sizing-integrated)
cross-check tools: a NACA panel-method airfoil solver and a purely
geometric RCS estimator.

Builds on the architecture of the reference TTPA sizing framework and its
IHW2 constraint-analysis predecessor (shared, injected discipline objects;
`Dependent` properties that recompute on every read instead of caching;
one mutable state per discipline -- `S_ref` for geometry, `thrust_scale`
for propulsion -- that the sizing loop actually iterates on), redesigned
for a **jet**, **carrier-based**, **store-configurable** aircraft instead
of the reference's piston/propeller, land-based one. The user's own
`aero_drag.m` VLM + Korn/Lock wave-drag + area-rule pipeline was the
starting point for `CcaAero`'s drag build-up, reconstructed here at the
same stage-by-stage structure (geometry -> CD0 -> lift -> induced ->
wave -> store increment -> polar) with Reynolds-number-driven skin
friction and a real 3D lift-curve-slope correction added for the "higher
fidelity" ask.

## Run it

```matlab
run_demo
```

from this folder (it `addpath(genpath(pwd))`s itself). This closes TOGW,
prints the converged sizing point, re-plots the matching diagram with a
per-constraint pass/fail check, runs the standalone RCS sweep, and runs
the airfoil robustness sweep.

## Folder layout

```
cca_requirements.json   ALL numeric inputs: geometry, propulsion, weights,
                        constraint conditions, mission profile. Edit this
                        file to re-run a design study -- no code changes
                        needed for a parametric trade.
cca_disciplines.m       Wires every object up from the JSON, in the
                        right construction order.
run_demo.m              End-to-end example.

core/            Abstract base classes (GeometryBase, AerodynamicsBase,
                 PropulsionBase_Jet, WeightsBase), AircraftState (self-
                 contained ISA atmosphere + Sutherland viscosity, no
                 toolbox dependency), get_state/get_con/get_miss_seg
                 (JSON -> normalized-field structs), the JSON readers.
models/          CcaGeom, CcaAero, CcaProp, CcaWeights -- the four
                 concrete discipline classes.
mission/         run_mission.m sequencer + one file per segment type
                 (climb, cruise/dash, loiter, takeoff/landing).
constraints/     One file per constraint type (cruise, dash, climb,
                 takeoff, landing) + matching_envelope.m (the T/W-vs-W/S
                 combination logic) + the plot/driver/design-point-check.
sizing/          sizing_pass.m (one fixed-point iteration) +
                 sizing_mainloop.m (the iteration itself) +
                 spot_factor_check.m (the hard carrier gate).
airfoil/         NACA 4-digit panel-method solver (napm_solve.m),
                 public wrapper (naca_panel_method.m), and the multi-
                 section robustness sweep -- a cross-check on the thin-
                 airfoil section assumption CcaAero's lift model uses,
                 NOT the sizing-loop's own lift calculation.
rcs/             Standalone, purely-geometric flat-facet RCS estimator
                 -- NOT called anywhere in sizing/, mission/ or
                 constraints/. A user-run trade-study tool only.
```

## Requirements this framework enforces or exposes

- **Carrier spot factor <= 0.80, HARD CONSTRAINT.** `spot_factor_check.m`
  errors out (does not silently resize) if
  `(span x fold_fraction) / fuselage_length` exceeds
  `geometry.spot_factor_max` in the requirements JSON. See its docstring
  for what to change when it fires.
- **Mach 0.85 dash.** `geometry.dash_mach`/`dash_CL`/`dash_margin_required`
  drive `CcaGeom.Mdd`/`dash_feasible` (Korn/Lock), and `constraint_dash.m`
  exercises it as an actual thrust requirement on the matching diagram.
  `CcaGeom.required_sweep_deg` (static method) inverts the Korn/Lock
  relation to tell you the minimum sweep for a given kappaA/t-c/CL if you
  want to resize sweep by hand for a trade study.
- **Internal vs. external stores.** `geometry.stores.configuration` is
  `"internal"` or `"external"`. This one switch changes: cruise drag
  (`CcaAero.store_drag`, zero for internal, a flat-plate drag-area sum
  for external), empty weight (`CcaWeights.OEW_breakdown`: bay structure
  weight vs. pylon weight), and the geometric RCS estimate (adds small
  external-store facets only in the external case). Mid-mission weapon
  release (`releases_stores: true` on a mission segment) drops both the
  weight and, for external carriage, the drag for the rest of the
  mission.
- **Tail type and engine count.** `geometry.tail_type` is one of
  `"conventional"`, `"t_tail"`, `"v_tail"`, `"twin_vertical"`, `"none"`;
  `propulsion.n_engines` is any positive integer. Both are read straight
  through to every downstream discipline (geometry, drag build-up,
  engine-out climb, the RCS facet model).
- **Airfoil robustness.** The wing section is assumed transonic/
  supercritical (characterised only by `kappaA` and `t/c` in the Korn/
  Lock relation -- its exact camber is not modeled). `airfoil/` lets you
  run the real panel-method solver over a family of NACA 4-digit
  sections to see how much `Cl_alpha`/`alpha0`/`Cm_c4` would move if a
  conventional section were used instead, as a sensitivity check on that
  assumption -- it is a cross-check tool, not part of the sizing loop.
- **Geometric RCS.** `rcs_estimate.m` gives a purely geometric (physical-
  optics flat-plate facets; no materials, no cavity/duct diffraction, no
  edge-wave terms), horizontal-plane-only RCS-vs-azimuth estimate, so
  tail-type and store-carriage choices can be compared on a fourth axis
  besides drag/weight/spot-factor. It is explicitly NOT wired into
  `sizing_pass.m` or `run_constraints.m`, per scope.

## Explicitly out of scope (by design, not oversight)

- Catapult/arresting-gear **mechanics** (energy absorption, hook loads,
  shuttle dynamics). `constraint_takeoff.m`/`constraint_landing.m` and
  `segment_takeoff_landing.m` use simple, standard field-length/approach-
  speed/fixed-fuel-fraction relations with a couple of carrier-specific
  knobs (`cat_credit`, `V_app_kts`) rather than modeling the gear itself.
- RCS **materials, coatings, and ducting/diffraction** effects --
  `rcs/` is geometry-only.
- Stability & control sizing for the tailless (`tail_type = "none"`)
  case -- that configuration zeroes tail area/weight/wetted-area here but
  does not size control-surface area for it.

## Units and conventions

English engineering units throughout (ft, lbf, deg R, lbf/ft^2 for both
pressure and wing loading, 1/hr for TSFC) -- the same convention the
reference TTPA framework used. Every citation in the code comments names
its source (Raymer, Mattingly, Katz & Plotkin, etc.) at the equation it
backs; a few component-weight and thrust-lapse correlations are
explicitly flagged as representative/calibrated conceptual-design
approximations rather than a specific certified engine deck, since no
such deck exists yet for this aircraft.
