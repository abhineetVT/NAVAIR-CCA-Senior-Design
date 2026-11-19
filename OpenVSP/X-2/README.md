# Concept X-2 – OpenVSP model

Single-engine (F414) carrier CCA: conventional swept wing with a fold hinge,
horizontal stabilizers with twin canted vertical fins (F-35 style), ventral inlet,
two SDB-II on wing pylons (two more internal).

## Files

| File | What it is |
| --- | --- |
| `X2_build.vspscript` | Builds the model from the sizing outputs and prints the CompGeom wetted areas |
| `X2.vsp3` | The model the script writes (open in OpenVSP) |
| `X2_CompGeom.txt` | Command-prompt output of the last run (wetted areas) |
| `images/` | Shaded top, side, front and 3/4 views |

## How to run

1. Put `X2_build.vspscript` in the OpenVSP folder (next to `vspscript.exe`).
2. In that folder, open a command prompt and run:
   `vspscript.exe -script X2_build.vspscript`
3. The window prints the geometry check and the wetted area of each part,
   and writes `X2.vsp3`. Open it with `vsp.exe` → File → Open.

Switches at the top of the script:
- `FOLDED = true` – outer wing panels folded up 90° (deck-parked shape).
- `F35_TAIL = false` – the original V-tail instead of the horizontal
  stabilizers + twin fins; writes `X2_Vtail.vsp3`.

## Where the dimensions come from

All dimensions (ft) are the converged X-2 outputs of the team sizing code
(`cca_sizing`, X-2 inputs): wing 144.5 ft², span 24.0 ft, AR 4.0, taper 0.30,
35° LE sweep, NACA 65A210, fold hinge at 65% semi-span; fuselage
43 × 5.5 × 5.0 ft. Tail: horizontal stabilizers 21.2 ft² (AR 4, volume
coefficient 0.45) and two fins canted 20° outward, 4.3 ft² each (vertical
projection 0.85 × the 9.5 ft² required, the team code's twin-fin rule), both
at a 20.2 ft tail arm. The matching sizing case is `tail_type =
"twin_vertical"` in the X-2 inputs (TOGW 15,287 lbf, wing 144.3 ft²).
The V-tail alternative is 30.7 ft² at 33.7° cant (NACA Report 823).
If the sizing changes, edit only the constants block at the top of the script
and rerun.

CompGeom note: the fuselage, inlet and store ends are closed with flat caps
so CompGeom can trim the intersections; subtract the nozzle cap (5.3 ft²) and
inlet-face cap (3.8 ft²) from the fuselage and inlet areas, since those are
not wetted surfaces.
