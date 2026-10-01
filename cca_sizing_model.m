<<<<<<< HEAD
%% GOBBLEWORKS_OEW.m -- OEW(W_TO) for the CCA, your design parameters, one graph.
clear; close all; clc;

%% ---- design parameters ----
d.WS_TO = 100; d.AR = 4.0; d.taper = 0.25; d.sweep_c4 = 35;      % geometry
d.tc_root = 0.10; d.Sct_frac = 0.14; d.Sht_ratio = 0.18; d.Svt_ratio = 0.14;
d.Nvt = 2; d.Lt = 18; d.L_fus = 46; d.D_fus = 6.0; d.W_fus = 8.5;
d.k_fus_wet = 0.80; d.bay_door_ft2 = 60; d.L_mlg_in = 60; d.L_nlg_in = 55;
d.N_gear_limit = 5.0; d.L_duct = 20; d.K_duct = 2.5;

d.Nz_limit = 5.0; d.FoS = 1.5;                                   % loads

d.T_max_SL = 22000; d.W_dry = 2445; d.D_ft = 2.92; d.L_ft = 12.9; % F414-GE-400
d.sfc_max = 1.6;                                                 % 1/hr @ SL static, max power

d.W_avionics = 1000; d.W_autonomy = 300; d.Rkva = 120;           % systems
d.N_fc_sys = 4; d.N_hyd_func = 12; d.N_tanks = 4; d.protected_frac = 0.5;
d.growth = 0.10;

d.f_wing = 0.85; d.f_tail = 0.83; d.f_fus = 0.90; d.f_gear = 0.95; d.f_inlet = 0.85;
d.k_bay_fus = 1.08; d.door_lb_ft2 = 4.0; d.RAM_lb_ft2 = 0.15;
d.k_carrier_fus = 1.07; d.k_carrier_gear = 1.20; d.wing_fold_frac = 0.05;
d.W_hook = 350; d.n_hardpoints = 4; d.W_hardpoint = 60;

W_energy = 9923;              % lb  mission fuel (fixed estimate, from the sizing model)
W_payload = 2000;             % lb  internal stores -- [TEAM] 2k cap
W_TO_target = 45000;          % lb  [TEAM] planned target TOGW

%% ---- sweep W_TO and plot ----
W_TO_vec = linspace(20000, 50000, 80);
OEW_vec  = arrayfun(@(w) oew(d, w, W_energy), W_TO_vec);
req_vec  = W_TO_vec - W_energy - W_payload;    % closure: W_TO = OEW + energy + payload

idx = find(diff(sign(OEW_vec - req_vec)) ~= 0, 1);
W_TO_solved = interp1(OEW_vec(idx:idx+1)-req_vec(idx:idx+1), W_TO_vec(idx:idx+1), 0);
OEW_solved  = oew(d, W_TO_solved, W_energy);
fprintf('Closure: W_TO = %.0f lb, OEW = %.0f lb  (planned target: %.0f lb)\n', W_TO_solved, OEW_solved, W_TO_target);

figure; hold on; grid on;
plot(W_TO_vec/1000, OEW_vec/1000, 'b-', 'LineWidth', 2);
plot(W_TO_vec/1000, req_vec/1000, 'r--', 'LineWidth', 2);
plot(W_TO_solved/1000, OEW_solved/1000, 'kp', 'MarkerSize', 16, 'MarkerFaceColor', 'y');
yl = ylim;
plot([1 1]*W_TO_target/1000, yl, 'k:', 'LineWidth', 1.8);
xlabel('Candidate W_{TO} (1000 lb)'); ylabel('OEW (1000 lb)');
legend('OEW(W_{TO})', 'Required: W_{TO} - energy - payload', 'Closure point', '45k target', 'Location', 'northwest');
title(sprintf('GobbleWorks CCA: closes at %.0f lb TOGW, %.0f lb OEW (target %.0f lb)', W_TO_solved, OEW_solved, W_TO_target));
saveas(gcf, 'oew_vs_wto.png');

%% ---- OEW function ----
function OEW = oew(d, W_TO, W_fuel)
    Sw = W_TO / d.WS_TO; b = sqrt(d.AR*Sw); cr = 2*Sw/(b*(1+d.taper));
    Scsw = d.Sct_frac*Sw; Sht = d.Sht_ratio*Sw; Svt = d.Svt_ratio*Sw/d.Nvt;
    Swet = d.k_fus_wet*pi*0.5*(d.D_fus+d.W_fus)*d.L_fus + 2.04*(Sw-min(cr*d.W_fus,0.6*Sw)) + 2.04*(Sht+d.Nvt*Svt);

    Nz = d.Nz_limit*d.FoS;
    Wdg = W_TO - 0.5*W_fuel;             % mid-mission weight [approx]
    Wl  = W_TO - 0.75*W_fuel;            % landing weight [approx]
    Nl  = 1.5*d.N_gear_limit;

    W_wing = 0.0103*(Wdg*Nz)^0.5*Sw^0.622*d.AR^0.785*d.tc_root^-0.4*(1+d.taper)^0.05/cosd(d.sweep_c4)*Scsw^0.04*d.f_wing;
    W_ht   = 3.316*(1+0.5*d.W_fus/sqrt(3.5*Sht))^-2*(Wdg*Nz/1000)^0.260*Sht^0.806*d.f_tail;
    W_vt   = d.Nvt*0.452*(Wdg*Nz)^0.488*Svt^0.718*0.90^0.341/d.Lt*1.25^0.348*1.3^0.223*1.4^0.25/cosd(40)^0.323*d.f_tail;
    W_fus  = 0.499*Wdg^0.35*Nz^0.25*d.L_fus^0.5*d.D_fus^0.849*d.W_fus^0.685*d.f_fus;
    W_lg   = ((Wl*Nl)^0.25*d.L_mlg_in^0.973 + (Wl*Nl)^0.290*d.L_nlg_in^0.5*2^0.525)*d.f_gear;

    Te = d.T_max_SL;
    W_eng_install = 0.013*Te^0.579*Nz + 1.13*pi*d.D_ft*0.5*d.L_ft + 0.01*d.W_dry^0.717*Nz ...
                  + 3.5*d.D_ft*8 + 4.55*d.D_ft*d.L_ft + 37.82 + 10.5*20^0.222 + 0.025*Te^0.760;
    W_inlet = 13.29*d.L_duct^0.643*d.K_duct^0.182*d.D_ft*d.f_inlet;
    Vt = W_fuel/6.8; Vp = d.protected_frac*Vt;
    W_fs = 7.45*Vt^0.47*2^-0.095*(1+Vp/Vt)*d.N_tanks^0.066*(Te*d.sfc_max/1000)^0.249;

    Scs = Scsw + 0.3*Sht + 0.25*Svt*d.Nvt;
    W_flt_ctrl = 36.28*0.90^0.003*Scs^0.489*d.N_fc_sys^0.484;
    W_instr    = 8.0 + 36.37*d.N_tanks^0.237;
    W_hyd      = 37.23*d.N_hyd_func^0.664;
    W_elec     = 172.2*1.45*d.Rkva^0.152*40^0.10*2^0.091;
    W_av       = d.W_avionics + d.W_autonomy;
    W_ecs      = 201.6*(W_av/1000)^0.735;

    structure  = W_wing + W_ht + W_vt + W_fus + W_lg + d.n_hardpoints*d.W_hardpoint;
    stealth    = W_fus*(d.k_bay_fus-1) + d.bay_door_ft2*d.door_lb_ft2 + d.RAM_lb_ft2*Swet;
    carrier    = d.wing_fold_frac*W_wing + W_fus*d.k_bay_fus*(d.k_carrier_fus-1) + W_lg*(d.k_carrier_gear-1) + d.W_hook;
    propulsion = d.W_dry + W_eng_install + W_inlet + W_fs;
    systems    = W_flt_ctrl + W_instr + W_hyd + W_elec + W_av + W_ecs + 3.2e-4*W_TO;

    raw = structure + stealth + carrier + propulsion + systems;
    OEW = raw * (1 + d.growth);
end
=======
%% CCA_SIZING_MODEL.m  --  GobbleWorks carrier-based CCA: OEW / sizing / requirements trades
%  ONE FILE. Run top to bottom (MATLAB R2016b+; local functions live at the bottom).
%  Edit numbers ONLY in section 1. Figures are saved to ./figs/
%
%  ======================= WHAT THIS SCRIPT DOES =======================
%  Given requirements (radius, dash Mach, stores, Nz...) and a guessed configuration
%  (W/S, AR, sweep, fuselage size...), it finds the take-off weight W0 that closes:
%       W0 = OEW(W0) + stores + mission_fuel(W0)
%  by fixed-point iteration, then checks RFP constraints, estimates unit cost, and
%  sweeps requirements to show which ones move weight and cost.
%
%  Flow inside one iteration:
%    geometry_from_W0 -> aero_setup -> mission_fuel (segment integration)
%       -> oew_buildup (Raymer-style component weights) -> new W0 -> repeat
%
%  ======================= WHAT IS PHYSICS vs REGRESSION vs GUESS =======================
%  PHYSICS (textbook, low risk):  std_atmos, Breguet-style segment fuel integration,
%      induced drag K = 1/(pi*AR*e), lift/stall-speed relations, constraint-diagram equation.
%  REGRESSION (fit to old manned aircraft; +-10-30% per component, extrapolated to
%      unmanned/stealth/composite):  every line in oew_buildup, Oswald e, Korn wave drag,
%      CLmax build-up, thrust lapse, TSFC model, DAPCA IV cost.
%  GUESS (no data behind it -- YOU must defend or replace):  see GUESS LEDGER below.
%
%  ======================= GUESS LEDGER (biggest first) =======================
%   1. Avionics cost $/lb (cost.avionics_per_lb_2012) -- swings unit cost by several $M
%   2. Growth margin (10%), autonomy-stack weight (300 lb) -- directly add to OEW
%   3. Engine deck: F414 thrust/TSFC are approximate public numbers; part-throttle TSFC
%      penalty (eng.k_part) is a guess
%   4. Drag: Cfe = 0.0040, fuselage wetted-area factor, Korn kappa_A = 0.87, stealth
%      shaping penalties ignored (real LO shapes have MORE drag)
%   5. Configuration: W/S = 100 psf, AR = 4, sweep 35 deg, t/c, tail sizes, fuselage
%      L/D/W, fuselage fuel volume (160 ft^3) -- none of these come from OpenVSP yet
%   6. Stealth/carrier adders: bay penalty 8%, doors 4 lb/ft^2, RAM 0.15 lb/ft^2,
%      carrier fuselage 1.07 / gear 1.20, hook 350 lb, hardpoints 60 lb each
%   7. Composite factors (0.83-0.95): from memory of Raymer; structure is assumed
%      composite but nothing here models composite cost/cure/tooling explicitly
%   8. CLmax inputs: airfoil Clmax 1.5, flap delta 1.3, stealth knock 0.92
%   9. Stores: GBU-53 208 lb, rack 320 lb, AIM-120D 356 lb, launchers 150 lb [VERIFY]
%  10. Spot factor: folded-box ratio vs an F/A-18C footprint -- definition NOT confirmed
%
%  ======================= VERIFICATION STATUS =======================
%  * DAPCA IV coefficients + wrap rates: cross-checked against AeroSandbox's open-source
%    implementation (SI units -> converted back) -- all match.
%  * Raymer fighter/attack weight coefficients: implemented from memory of Raymer Table
%    15.2; hand re-computation confirms the CODE matches that recollection, but I could
%    NOT find an open listing to confirm the coefficients themselves. CHECK EACH ONE
%    AGAINST YOUR EDITION before using numbers in a report.
%  * Oswald e now uses LEADING-EDGE sweep (earlier version wrongly used c/4 sweep).
%  * Part-throttle TSFC penalty added (earlier version used full-throttle TSFC at
%    ~45% throttle, which was optimistic).
%  * One-point validation on an approximate F/A-18E is printed below -- a sanity check,
%    not a calibration of the stealth/unmanned/composite assumptions.

clear; close all; clc;
if ~exist('figs','dir'), mkdir('figs'); end

%% ============================== 1. INPUTS ==============================
% Tags: [RFP] from the Navy RFP | [TEAM] team decision | [ASSUME] engineering assumption
%       [VERIFY] approximate public value -- confirm before citing

% ---- requirements / targets ----
p.req.W0_target      = 45000;   % lb   [TEAM] target TOGW
p.req.MTOW_max       = 60000;   % lb   [RFP]
p.req.cost_target    = 22e6;    % $    [TEAM] unit recurring cost target (2026$)
p.req.cost_max       = 30e6;    % $    [TEAM] ceiling
p.req.span_max       = 60;      % ft   [RFP] unfolded
p.req.span_fold_max  = 35;      % ft   [RFP] folded
p.req.length_max     = 51.4;    % ft   [RFP] F-35C length [VERIFY 51.4-51.5 ft]
p.req.height_max     = 18.5;    % ft   [RFP] wings folded (not checked -- needs 3-view)
p.req.spot_max       = 0.8;     % -    [RFP]
p.req.Vapp_max_kts   = 145;     % kts  [RFP]
p.req.Nz_limit       = 5.0;     % g    [RFP] at MID-MISSION weight
p.req.FoS            = 1.5;     % -    ultimate = 1.5 x limit

% ---- strike sizing mission ----
p.mis.radius_nm      = 750;     % nm   [TEAM] (RFP: 500 req / 700 desired)
p.mis.M_dash         = 0.90;    % -    [TEAM] SL dash, intermediate thrust (RFP: 0.8 req / 0.9 des)
p.mis.dash_nm        = 50;      % nm   [RFP] each way (ingress + egress)
p.mis.M_cruise       = 0.80;    % -    [ASSUME] transit Mach
p.mis.h_cruise       = 35000;   % ft   [ASSUME]
p.mis.t_attack_min   = 0;       % min  [ASSUME] extra mil-power time at target (RFP strike combat = the dashes)
p.mis.h_loiter       = 10000;   % ft   [RFP]
p.mis.t_loiter_min   = 10;      % min  [RFP] reserve loiter
p.mis.n_land_attempt = 2;       % -    [RFP]
p.mis.frac_warmup    = 0.980;   % -    [ASSUME] deck ops + catapult (historical)
p.mis.frac_climb     = 0.985;   % -    [ASSUME] per climb (historical)
p.mis.frac_descent   = 0.990;   % -    [ASSUME] no range credit for descent
p.mis.frac_attempt   = 0.995;   % -    [ASSUME] per landing attempt / bolter
p.mis.trapped_frac   = 0.01;    % -    [ASSUME] trapped/unusable fuel

% ---- strike stores (internal). RFP load = 4x GBU-53/B SDB-II ----
p.store.W_drop       = 4*208;   % lb   [VERIFY] used only if size_to_cap = false
p.store.W_rack       = 320;     % lb   [VERIFY] 4-pack rack, retained after release
p.store.cap_internal = 2000;    % lb   [TEAM] internal payload capacity incl. rack
p.store.size_to_cap  = true;    % true = size mission carrying the FULL 2,000 lb, drop all but rack

% ---- A2A check mission (RFP): 2x AIM-120D on external wing stations ----
p.a2a.n_msl          = 2;
p.a2a.W_msl          = 356;     % lb   [VERIFY] AIM-120D
p.a2a.W_launcher     = 150;     % lb   [ASSUME] pylon + launcher each
p.a2a.Dq_station     = 1.0;     % ft^2 [ASSUME] D/q per loaded external station
p.a2a.t_combat_min   = 2;       % min  [RFP] 2 req / 5 desired at max thrust
p.a2a.h_combat       = 10000;   % ft   [RFP]
p.a2a.M_combat       = 0.60;    % -    [ASSUME] best-turn-rate speed (aero lead refine)
p.a2a.fire_missiles  = false;   % RFP: carrying for whole mission desired
p.a2a.radius_req_nm  = 500;     % nm   [RFP]
p.a2a.radius_des_nm  = 700;     % nm   [RFP]

% ---- geometry (wing/tails scale with W0; fuselage is FIXED) ----
p.geo.WS_TO          = 100;     % psf  [ASSUME] takeoff wing loading -> Sw = W0/WS
p.geo.AR             = 4.0;     % -    [ASSUME]
p.geo.taper          = 0.25;    % -    [ASSUME]
p.geo.sweep_c4       = 35;      % deg  [ASSUME] quarter-chord sweep
p.geo.tc_root        = 0.10;    % -    [ASSUME] thick root for bay/fuel volume
p.geo.tc_tip         = 0.06;    % -    [ASSUME]
p.geo.tc_avg         = 0.07;    % -    [ASSUME] used for drag divergence
p.geo.fold_frac      = 0.60;    % -    [ASSUME] folded span / unfolded span
p.geo.Sct_frac       = 0.14;    % -    [ASSUME] wing control-surface area / Sw
p.geo.Sht_ratio      = 0.18;    % -    [ASSUME] Sht/Sw (set 0 for tailless)
p.geo.Svt_ratio      = 0.14;    % -    [ASSUME] total Svt/Sw
p.geo.Nvt            = 2;       % -    [ASSUME] twin canted verticals
p.geo.Lt             = 18;      % ft   [ASSUME] tail moment arm
p.geo.L_fus          = 46;      % ft   [TEAM] overall length (spot factor!)
p.geo.D_fus          = 6.0;     % ft   [ASSUME] structural depth
p.geo.W_fus          = 8.5;     % ft   [ASSUME] structural width
p.geo.k_fus_wet      = 0.80;    % -    [ASSUME] fuselage Swet = k*pi*avg(D,W)*L (-> OpenVSP)
p.geo.V_fus_fuel_ft3 = 160;     % ft^3 [ASSUME] fuselage tank volume (-> OpenVSP)
p.geo.bay_door_ft2   = 60;      % ft^2 [ASSUME] total weapons-bay door area
p.geo.L_mlg_in       = 60;      % in   [ASSUME] main gear strut length
p.geo.L_nlg_in       = 55;      % in   [ASSUME]
p.geo.N_gear_limit   = 5.0;     % g    [ASSUME] carrier-landing limit load factor
p.geo.L_duct         = 20;      % ft   [ASSUME] serpentine duct length
p.geo.K_duct         = 2.5;     % -    [VERIFY] Raymer duct-shape constant (read from Raymer figure)

% ---- aero (aero lead replaces) ----
p.aero.Cfe           = 0.0040;  % -    [ASSUME] equiv. skin friction (Raymer: Navy fighter ~0.0040)
p.aero.kappa_A       = 0.87;    % -    [ASSUME] Korn factor (0.87 conventional, 0.95 supercritical)
p.aero.Clmax_af      = 1.5;     % -    [ASSUME] airfoil Clmax
p.aero.dClmax_flap   = 1.3;     % -    [ASSUME] flap increment
p.aero.Sflap_frac    = 0.50;    % -    [ASSUME] flapped area / Sw
p.aero.stealth_CL_knock = 0.92; % -    [ASSUME] penalty for LO-compatible high-lift devices
p.aero.TO_flap_frac  = 0.80;    % -    [ASSUME] fraction of landing flap delta available at takeoff

% ---- propulsion ----
p.eng = engine_data('F414-GE-400');   % propulsion lead: swap / refine
p.eng.N      = 1;                     % engines
p.eng.k_part = 0.20;                  % [ASSUME] TSFC rises by k_part*(1 - throttle) at part power

% ---- weights / technology ----
p.wt.W_avionics_rfp  = 1000;    % lb   [RFP] avionics/sensors, internal, carried in OEW
p.wt.W_autonomy_add  = 300;     % lb   [ASSUME] autonomy computers, JPALS, MD-5 + F-35 datalinks
p.wt.Rkva            = 120;     % kVA  [ASSUME]
p.wt.N_fc_sys        = 4;       % -    [ASSUME] flight-control functions
p.wt.N_hyd_func      = 12;      % -    [ASSUME] hydraulic utility functions
p.wt.N_tanks         = 4;       % -    [ASSUME]
p.wt.protected_frac  = 0.5;     % -    [ASSUME] self-sealing fraction of fuel volume
p.wt.growth          = 0.10;    % -    [ASSUME] empty-weight growth margin
p.wt.N_crew          = 0;       % -    0 = unmanned (1 only in validation run)

p.tech.f_wing        = 0.85;    % -    [VERIFY] Raymer advanced-composite factors
p.tech.f_tail        = 0.83;
p.tech.f_fus         = 0.90;
p.tech.f_gear        = 0.95;
p.tech.f_inlet       = 0.85;
p.tech.k_bay_fus     = 1.08;    % -    [ASSUME] internal weapons-bay cutout/frames on fuselage
p.tech.door_lb_ft2   = 4.0;     % -    [ASSUME] bay doors + actuators per ft^2
p.tech.RAM_lb_ft2    = 0.15;    % -    [ASSUME] RAM / edge treatment per ft^2 wetted
p.tech.k_carrier_fus = 1.07;    % -    [VERIFY] Raymer carrier-based fuselage factor
p.tech.k_carrier_gear= 1.20;    % -    [VERIFY] carrier-based gear factor
p.tech.wing_fold_frac= 0.05;    % -    [ASSUME] fold hinge/actuation as fraction of wing wt
p.tech.W_hook        = 350;     % lb   [ASSUME] hook + support for 200,000 lbf [RFP]
p.tech.n_hardpoints  = 4;       % -    [TEAM] wing/fuselage external stations
p.tech.W_hardpoint   = 60;      % lb   [ASSUME] provisions per station

% ---- cost (DAPCA IV, Raymer Ch.18, 2012$ -> 2026$) ----
p.cost.Q             = 500;     % [RFP] production run
p.cost.FTA           = 6;       % flight-test aircraft
p.cost.infl          = 1.44;    % [VERIFY] CPI ratio 2026/2012 (AeroSandbox uses 1.327 for mid-2023)
p.cost.R_eng = 115; p.cost.R_tool = 118; p.cost.R_qc = 108; p.cost.R_mfg = 98;  % 2012 $/hr
p.cost.f_eng         = 1.5;     % [ASSUME] composite/LO engineering hour multiplier
p.cost.f_tool        = 1.3;     % [ASSUME]
p.cost.f_mfg         = 1.25;    % [ASSUME] applies to mfg + QC hours
p.cost.f_mat         = 1.25;    % [ASSUME] materials multiplier
p.cost.avionics_per_lb_2012 = 5000;  % $/lb [ASSUME] Raymer range ~4k-8k -- BIGGEST cost lever
p.cost.engine_price  = p.eng.price_2026;

% ---- solver ----
p.W0_guess = 45000; p.tol = 1; p.max_iter = 100; p.relax = 0.6;

%% ============================== 2. BASELINE SIZING ==============================
r = size_aircraft(p);
if ~r.converged, warning('Baseline did not converge -- requirement set may not close.'); end

fprintf('================ BASELINE: STRIKE SIZING MISSION ================\n');
fprintf('Radius %d nm | SL dash M%.2f | %s x%d | stores %0.0f lb (%s)\n', p.mis.radius_nm, ...
    p.mis.M_dash, p.eng.name, p.eng.N, r.W_stores, ternary(p.store.size_to_cap,'sized to 2k cap','4xSDB-II'));
fprintf('Converged in %d iterations\n\n', r.iter);
fprintf('%-24s %9.0f lb\n','TOGW (required)', r.W0);
fprintf('%-24s %9.0f lb   (%.3f)\n','OEW (incl. growth)', r.OEW, r.OEW_frac);
fprintf('%-24s %9.0f lb   (%.3f)\n','Mission fuel', r.W_fuel, r.fuel_frac);
fprintf('%-24s %9.0f lb\n','Stores', r.W_stores);
fprintf('%-24s %9.0f lb\n','Mid-mission (Nz design)', r.W_mid);
fprintf('%-24s %9.0f lb\n','Arrestment weight', r.W_land);
fprintf('%-24s %9.0f ft^2  span %.1f ft  Swet/Sref %.2f\n','Wing area', r.g.Sw, r.g.b, r.g.Swet_Sref);
fprintf('%-24s %9.4f   e=%.3f  CLmax TO/land %.2f/%.2f\n','CD0 (clean)', r.aero.CD0, r.aero.e, r.aero.CLmax_TO, r.aero.CLmax_land);
fprintf('%-24s %9.2f\n','T/W (max, SL static)', r.TW);
fprintf('%-24s %9.1f lb (should be ~0)\n','Weight closure error', r.W0 - (r.OEW + r.W_stores + r.W_fuel));

grp = {'Structure','Stealth','Carrier','Propulsion','Systems'};
fprintf('\n--- Weight statement ---\n');
for k = 1:numel(grp)
    idx = find(strcmp(r.bd.group, grp{k}));
    fprintf('%s  (%0.0f lb, %.1f%% of OEW)\n', upper(grp{k}), sum(r.bd.W(idx)), 100*sum(r.bd.W(idx))/r.OEW);
    for ii = idx, fprintf('   %-48s %7.0f\n', r.bd.name{ii}, r.bd.W(ii)); end
end
fprintf('GROWTH MARGIN (%.0f%%)                               %7.0f\n', 100*p.wt.growth, r.bd.growth);
fprintf('OEW                                                  %7.0f\n', r.OEW);

c = r.cost;
fprintf('\n--- Unit cost, Q=%d (2026$, DAPCA IV) ---\n', p.cost.Q);
fprintf('   Airframe recurring   $%6.1fM\n   Avionics             $%6.1fM\n   Engine(s)            $%6.1fM\n', ...
    c.recurring_airframe/1e6, c.avionics/1e6, c.engines/1e6);
fprintf('   UNIT RECURRING       $%6.1fM   (target $%.0fM, cap $%.0fM)\n', c.unit_recurring/1e6, p.req.cost_target/1e6, p.req.cost_max/1e6);
fprintf('   Incl. RDT&E / Q      $%6.1fM\n', c.unit_program/1e6);

cons = check_constraints(p, r, true);
v = validate_fa18e(p);
breguet_check(p, r);

%% ============================== 3. BASELINE FIGURES ==============================
figure; plot(1:numel(r.hist), r.hist, 'o-', 'LineWidth', 1.5); grid on;
xlabel('Iteration'); ylabel('W_0 estimate (lb)'); title('Sizing convergence');
saveas(gcf, 'figs/01_convergence.png');

figure('Position',[100 100 900 650]);
[Ws, order] = sort(r.bd.W, 'ascend');
cols = [0.3 0.45 0.7; 0.55 0.3 0.6; 0.2 0.6 0.4; 0.85 0.45 0.2; 0.5 0.5 0.5];
hold on;
for ii = 1:numel(Ws)
    k = find(strcmp(grp, r.bd.group{order(ii)}));
    barh(ii, Ws(ii), 0.8, 'FaceColor', cols(k,:));
end
set(gca, 'YTick', 1:numel(Ws), 'YTickLabel', r.bd.name(order), 'FontSize', 8);
xlabel('Weight (lb)'); grid on;
title(sprintf('OEW breakdown  (OEW = %0.0f lb incl. %0.0f%% growth)', r.OEW, 100*p.wt.growth));
for k = 1:numel(grp), hh(k) = plot(NaN, NaN, 's', 'MarkerFaceColor', cols(k,:), 'MarkerEdgeColor', cols(k,:), 'MarkerSize', 10); end
legend(hh, grp, 'Location', 'southeast');
saveas(gcf, 'figs/02_oew_breakdown.png');

%% ============================== 4. TRADE: RADIUS x DASH MACH ==============================
R_vec = 500:50:1200;  M_vec = [0.80 0.85 0.90 0.95];
W0g = NaN(numel(M_vec), numel(R_vec)); Cg = W0g; Fmarg = W0g;
for ii = 1:numel(M_vec)
    for jj = 1:numel(R_vec)
        pp = p; pp.mis.M_dash = M_vec(ii); pp.mis.radius_nm = R_vec(jj);
        rr = size_aircraft(pp);
        if rr.converged
            W0g(ii,jj) = rr.W0; Cg(ii,jj) = rr.cost.unit_recurring;
            Fmarg(ii,jj) = rr.g.W_fuel_avail - rr.W_fuel;       % lb of tank volume left
        end
    end
end
iM = find(abs(M_vec - p.mis.M_dash) < 1e-6);
R_fuel_limit = NaN; kk = find(Fmarg(iM,:) < 0, 1, 'first');
if ~isempty(kk) && kk > 1
    R_fuel_limit = interp1(Fmarg(iM,kk-1:kk), R_vec(kk-1:kk), 0);
end

figure; hold on; grid on;
for ii = 1:numel(M_vec), plot(R_vec, W0g(ii,:)/1000, 'LineWidth', 1.8); end
plot(R_vec([1 end]), [1 1]*p.req.W0_target/1000, 'k--', R_vec([1 end]), [1 1]*p.req.MTOW_max/1000, 'r--');
plot(p.mis.radius_nm, r.W0/1000, 'kp', 'MarkerSize', 14, 'MarkerFaceColor', 'y');
yl = ylim; plot([500 500], yl, 'k:', [700 700], yl, 'k:');
if ~isnan(R_fuel_limit), plot([1 1]*R_fuel_limit, yl, 'm-.', 'LineWidth', 1.5); end
xlabel('Strike combat radius (nm)'); ylabel('Required TOGW (1000 lb)');
leg = [arrayfun(@(m) sprintf('SL dash M%.2f', m), M_vec, 'UniformOutput', false), {'45k target','60k MTOW limit','Design point'}];
if ~isnan(R_fuel_limit), leg{end+1} = 'Fixed-fuselage fuel-volume limit (guess)'; end
legend(leg, 'Location', 'northwest');
title('TOGW vs. radius (RFP: 500 req / 700 desired; dotted)');
saveas(gcf, 'figs/03_W0_vs_radius.png');

figure; hold on; grid on;
for ii = 1:numel(M_vec), plot(R_vec, Cg(ii,:)/1e6, 'LineWidth', 1.8); end
plot(R_vec([1 end]), [22 22], 'g--', R_vec([1 end]), [30 30], 'r--');
xlabel('Strike combat radius (nm)'); ylabel('Unit recurring cost ($M, 2026)');
legend([arrayfun(@(m) sprintf('M%.2f', m), M_vec, 'UniformOutput', false), {'$22M target','$30M cap'}], 'Location', 'northwest');
title('Unit cost vs. radius'); saveas(gcf, 'figs/04_cost_vs_radius.png');

ok = ~isnan(W0g(iM,:));
if any(W0g(iM,ok) >= p.req.W0_target)
    R45 = interp1(W0g(iM,ok), R_vec(ok), p.req.W0_target);
    fprintf('\n>> At W0 = %0.0f lb (M%.2f dash), the model gives ~%0.0f nm strike radius.\n', p.req.W0_target, p.mis.M_dash, R45);
else
    fprintf('\n>> Even at %d nm the sized TOGW stays below %0.0f lb -- 45k is not mission-driven.\n', R_vec(end), p.req.W0_target);
end
if ~isnan(R_fuel_limit)
    fprintf('>> With the FIXED %0.0f ft fuselage and %0.0f ft^3 fuselage tank guess, internal fuel volume runs out near %0.0f nm.\n', ...
        p.geo.L_fus, p.geo.V_fus_fuel_ft3, R_fuel_limit);
end

%% ============================== 5. CARPET PLOT ==============================
figure; hold on; grid on;
shift = 120;  Rc = 500:100:900;  jc = arrayfun(@(x) find(R_vec==x), Rc);
X = zeros(numel(M_vec), numel(Rc)); Y = X;
for ii = 1:numel(M_vec), X(ii,:) = R_vec(jc) + (ii-1)*shift; Y(ii,:) = W0g(ii,jc); end
plot(X', Y'/1000, 'b-', 'LineWidth', 1.3);
plot(X, Y/1000, 'r-', 'LineWidth', 1.3);
for ii = 1:numel(M_vec), text(X(ii,end)+15, Y(ii,end)/1000, sprintf('M%.2f', M_vec(ii)), 'Color', 'b'); end
for jj = 1:numel(Rc), text(X(1,jj)-20, Y(1,jj)/1000-0.3, sprintf('%d nm', Rc(jj)), 'Color', 'r', 'HorizontalAlignment','right'); end
set(gca, 'XTickLabel', []); ylabel('Required TOGW (1000 lb)');
title('Carpet plot: TOGW vs. strike radius and SL dash Mach');
saveas(gcf, 'figs/05_carpet.png');

%% ============================== 6. SENSITIVITY TORNADO ==============================
S = { % path                        low     high    label
 'mis.radius_nm',                  650,    850,    'Radius 650 / 850 nm';
 'mis.M_dash',                     0.80,   0.95,   'SL dash M0.80 / 0.95';
 'req.Nz_limit',                   5.0,    6.5,    'Nz limit 5.0 / 6.5 g';
 'store.cap_internal',             1152,   2500,   'Stores 1,152 (4xSDB-II) / 2,500 lb';
 'wt.W_autonomy_add',              150,    600,    'Autonomy adds 150 / 600 lb';
 'aero.Cfe',                       0.0035, 0.0045, 'Cfe 0.0035 / 0.0045';
 'eng.c0_mil',                     0.72,   0.88,   'TSFC -/+10%';
 'eng.k_part',                     0.0,    0.4,    'Part-throttle TSFC penalty 0 / 40%';
 'geo.WS_TO',                      85,     115,    'W/S 85 / 115 psf';
 'tech.k_bay_fus',                 1.04,   1.15,   'Bay penalty 4 / 15%';
 'tech.RAM_lb_ft2',                0.08,   0.30,   'RAM 0.08 / 0.30 lb/ft^2';
 'wt.growth',                      0.05,   0.15,   'Growth 5 / 15%';
 'cost.avionics_per_lb_2012',      3000,   8000,   'Avionics $3k / $8k per lb'};
nS = size(S,1); dW = zeros(nS,2); dC = dW;
for k = 1:nS
    for s = 1:2
        rr = size_aircraft(setp(p, S{k,1}, S{k,1+s}));
        dW(k,s) = rr.W0 - r.W0;  dC(k,s) = rr.cost.unit_recurring - c.unit_recurring;
    end
end
[~, o] = sort(max(abs(dW),[],2)); figure('Position',[100 100 1100 500]);
subplot(1,2,1); hold on; grid on;
barh(1:nS, dW(o,1), 'FaceColor', [0.3 0.5 0.8]); barh(1:nS, dW(o,2), 'FaceColor', [0.85 0.4 0.3]);
set(gca, 'YTick', 1:nS, 'YTickLabel', S(o,4), 'FontSize', 8);
xlabel('\Delta TOGW (lb)'); title(sprintf('TOGW sensitivity (base %0.0f lb)', r.W0)); legend('low','high','Location','southeast');
[~, o2] = sort(max(abs(dC),[],2));
subplot(1,2,2); hold on; grid on;
barh(1:nS, dC(o2,1)/1e6, 'FaceColor', [0.3 0.5 0.8]); barh(1:nS, dC(o2,2)/1e6, 'FaceColor', [0.85 0.4 0.3]);
set(gca, 'YTick', 1:nS, 'YTickLabel', S(o2,4), 'FontSize', 8);
xlabel('\Delta unit cost ($M)'); title(sprintf('Cost sensitivity (base $%.1fM)', c.unit_recurring/1e6));
saveas(gcf, 'figs/06_tornado.png');

fprintf('\n--- Sensitivity (low / high) ---\n');
fprintf('%-40s %9s %9s %9s %9s\n', 'Parameter', 'dW0 lo', 'dW0 hi', 'dC$M lo', 'dC$M hi');
for k = 1:nS, fprintf('%-40s %9.0f %9.0f %9.2f %9.2f\n', S{k,4}, dW(k,1), dW(k,2), dC(k,1)/1e6, dC(k,2)/1e6); end

%% ============================== 7. CONSTRAINT DIAGRAM ==============================
WS = linspace(50, 160, 120); aero = r.aero; eng = p.eng; Tref = eng.N*eng.T_max_SL;
TWc = @(M, h, beta, n, setting, dcd) arrayfun(@(ws) constraint_TW(ws, M, h, beta, n, setting, dcd, aero, eng, Tref), WS);
figure; hold on; grid on;
plot(WS, TWc(p.mis.M_dash, 0, 0.85, 1, 'mil', 0), 'LineWidth', 1.8);
plot(WS, TWc(p.mis.M_cruise, p.mis.h_cruise, 0.95, 1, 'mil', 0), 'LineWidth', 1.8);
dcd = p.a2a.n_msl*p.a2a.Dq_station/r.g.Sw;
plot(WS, TWc(0.80, 30000, 0.85, 1, 'max', dcd), 'LineWidth', 1.8);
plot(WS, TWc(p.a2a.M_combat, p.a2a.h_combat, 0.80, 4, 'max', dcd), 'LineWidth', 1.8);
[~,~,rho0] = std_atmos(0);
WS_app = 0.5*rho0*(p.req.Vapp_max_kts/0.592484/1.1)^2*aero.CLmax_land/(r.W_land/r.W0);
plot([WS_app WS_app], [0 1.4], 'k--', 'LineWidth', 1.8);
plot(p.geo.WS_TO, r.TW, 'kp', 'MarkerSize', 14, 'MarkerFaceColor', 'y');
ylim([0 1.4]); xlabel('W/S at takeoff (psf)'); ylabel('T/W at takeoff (max, SL static)');
legend(sprintf('SL dash M%.2f (mil)', p.mis.M_dash), 'Cruise M0.80 35k (mil)', 'A2A dash M0.80 30k (max)', ...
       'Sustained 4g @10k M0.6 (max) [ASSUME]', 'Approach <= 145 kt', 'Design point', 'Location', 'northwest');
title('Constraint diagram (feasible: above curves, left of dashed)');
saveas(gcf, 'figs/07_constraint_diagram.png');

%% ============================== 8. PAYLOAD TRADE ==============================
Wp = 1000:250:2500; W0p = NaN(size(Wp));
for k = 1:numel(Wp)
    rr = size_aircraft(setp(p, 'store.cap_internal', Wp(k)));
    if rr.converged, W0p(k) = rr.W0; end
end
figure; plot(Wp, W0p/1000, 'o-', 'LineWidth', 1.8); grid on;
xlabel('Internal stores weight incl. rack (lb)'); ylabel('Required TOGW (1000 lb)');
title(sprintf('Payload trade @ %d nm, M%.2f dash', p.mis.radius_nm, p.mis.M_dash));
saveas(gcf, 'figs/08_payload_trade.png');
fprintf('\nGrowth factor dW0/dPayload ~ %.2f lb TOGW per lb of stores\n', (W0p(end)-W0p(1))/(Wp(end)-Wp(1)));
fprintf('\nFigures saved to ./figs/\n');

%% ====================================================================================
%% ============================== LOCAL FUNCTIONS (keep at bottom) =====================
%% ====================================================================================

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end

function p = setp(p, path, val)
% SETP  p = setp(p, 'mis.radius_nm', 700)
parts = strsplit(path, '.');
p = setfield(p, parts{:}, val);
end

function [T, pr, rho, a] = std_atmos(h_ft, dT_R)
% 1976 standard atmosphere (English), optional temperature offset [R].  T[R] pr[psf] rho[slug/ft^3] a[ft/s]
if nargin < 2, dT_R = 0; end
T0 = 518.67; p0 = 2116.22; g = 32.174; R = 1716.49; L = 0.00356616;
if h_ft <= 36089
    Tstd = T0 - L*h_ft;
    pr = p0*(Tstd/T0)^(g/(L*R));
else
    Tstd = 389.97;
    p11 = p0*(Tstd/T0)^(g/(L*R));
    pr = p11*exp(-g*(h_ft-36089)/(R*Tstd));
end
T = Tstd + dT_R;
rho = pr/(R*T);
a = sqrt(1.4*R*T);
end

function eng = engine_data(name)
% Existing production engines only (RFP). Approximate public numbers [VERIFY].
% TSFC = (c0 + c1*M)*sqrt(theta) [1/hr] (Mattingly-style); thrust lapse in engine_perf.
switch upper(name)
    case 'F414-GE-400'
        eng.name='F414-GE-400'; eng.T_mil_SL=13000; eng.T_max_SL=22000;
        eng.W_dry=2445; eng.D_ft=2.92; eng.L_ft=12.9;
        eng.c0_mil=0.80; eng.c1_mil=0.30; eng.c0_max=1.60; eng.c1_max=0.27;
        eng.has_AB=true;  eng.price_2026=4.5e6;
    case 'F404-GE-402'
        eng.name='F404-GE-402'; eng.T_mil_SL=11000; eng.T_max_SL=17700;
        eng.W_dry=2282; eng.D_ft=2.92; eng.L_ft=13.3;
        eng.c0_mil=0.81; eng.c1_mil=0.30; eng.c0_max=1.74; eng.c1_max=0.27;
        eng.has_AB=true;  eng.price_2026=3.5e6;
    case 'F118-GE-100'   % non-afterburning (B-2 heritage)
        eng.name='F118-GE-100'; eng.T_mil_SL=17300; eng.T_max_SL=17300;
        eng.W_dry=3200; eng.D_ft=3.9; eng.L_ft=8.3;
        eng.c0_mil=0.62; eng.c1_mil=0.30; eng.c0_max=0.62; eng.c1_max=0.30;
        eng.has_AB=false; eng.price_2026=6.0e6;
    otherwise
        error('Unknown engine %s', name);
end
eng.TR = 1.07;   % throttle ratio (Mattingly)
end

function [T_av, tsfc_hr] = engine_perf(eng, M, h_ft, setting)
% Thrust and FULL-THROTTLE TSFC per engine. Mattingly low-bypass mixed-flow lapse:
%   alpha = d0*(1 - k*(th0-TR)/th0) above the throttle break; k = 3.5 (max), 3.8 (mil).
% Part-throttle penalty is applied in the mission segments, not here.
[T, pr] = std_atmos(h_ft);
theta = T/518.67;  delta = pr/2116.22;
th0 = theta*(1 + 0.2*M^2);
de0 = delta*(1 + 0.2*M^2)^3.5;
if strcmpi(setting,'max') && eng.has_AB
    lapse = de0; if th0 > eng.TR, lapse = de0*(1 - 3.5*(th0-eng.TR)/th0); end
    T_av = eng.T_max_SL*lapse;
    tsfc_hr = (eng.c0_max + eng.c1_max*M)*sqrt(theta);
else
    lapse = de0; if th0 > eng.TR, lapse = de0*(1 - 3.8*(th0-eng.TR)/th0); end
    T_av = eng.T_mil_SL*lapse;
    tsfc_hr = (eng.c0_mil + eng.c1_mil*M)*sqrt(theta);
end
T_av = max(T_av, 0);
end

function aero = aero_setup(p, Sw, Swet)
% Low-fidelity drag polar + CLmax (aero lead replaces).
AR = p.geo.AR; L = p.geo.sweep_c4; lam = p.geo.taper;
aero.Sw   = Sw;
aero.CD0  = p.aero.Cfe * Swet/Sw;                          % clean, bay doors closed
% Oswald e (Raymer): uses LEADING-EDGE sweep; swept formula valid for LE sweep > 30 deg.
LE = atand(tand(L) + (1-lam)/(AR*(1+lam)));                % LE sweep from c/4 sweep
if LE > 30
    e = 4.61*(1 - 0.045*AR^0.68)*cosd(LE)^0.15 - 3.1;
else
    e = 1.78*(1 - 0.045*AR^0.68) - 0.64;
end
e = min(max(e, 0.6), 0.85);                                % typical jet range ~0.7-0.85
aero.e = e; aero.LE = LE; aero.K = 1/(pi*AR*e);
aero.tc = p.geo.tc_avg; aero.sweep = L; aero.kA = p.aero.kappa_A;
% CLmax (Raymer-style): 0.9*Clmax_airfoil*cos(sweep) + flap increment
CLmax_clean = 0.9*p.aero.Clmax_af*cosd(L);
dCL_land    = 0.9*p.aero.dClmax_flap*p.aero.Sflap_frac*cosd(L*0.8);
aero.CLmax_clean = CLmax_clean*p.aero.stealth_CL_knock;
aero.CLmax_land  = (CLmax_clean + dCL_land)*p.aero.stealth_CL_knock;
aero.CLmax_TO    = (CLmax_clean + p.aero.TO_flap_frac*dCL_land)*p.aero.stealth_CL_knock;
end

function CD = drag_coeff(aero, CL, M, dCD0)
% CD = CD0 + K*CL^2 + wave drag.  Korn equation for Mdd, Mcr = Mdd - (0.1/80)^(1/3), CDw = 20*(M-Mcr)^4.
if nargin < 4, dCD0 = 0; end
c = cosd(aero.sweep);
Mdd = aero.kA/c - aero.tc/c^2 - abs(CL)/(10*c^3);
Mcr = Mdd - (0.1/80)^(1/3);
CDw = 0; if M > Mcr, CDw = 20*(M - Mcr)^4; end
CD = aero.CD0 + dCD0 + aero.K*CL^2 + CDw;
end

function g = geometry_from_W0(p, W0)
% Wing/tails scale with W0 at fixed W/S; fuselage is fixed (set by bay + engine + inlet).
g.Sw   = W0/p.geo.WS_TO;
g.b    = sqrt(p.geo.AR*g.Sw);
g.b_fold = p.geo.fold_frac*g.b;
g.cr   = 2*g.Sw/(g.b*(1+p.geo.taper));
g.Scsw = p.geo.Sct_frac*g.Sw;
g.Sht  = p.geo.Sht_ratio*g.Sw;
g.b_ht = sqrt(3.5*g.Sht);
g.Svt_each = p.geo.Svt_ratio*g.Sw/max(p.geo.Nvt,1);
% Wetted area by component (fuselage fixed -> Swet/Sref rises as the wing shrinks)
S_buried   = min(g.cr*p.geo.W_fus, 0.6*g.Sw);
g.Swet_fus = p.geo.k_fus_wet*pi*0.5*(p.geo.D_fus + p.geo.W_fus)*p.geo.L_fus;
g.Swet     = g.Swet_fus + 2.04*(g.Sw - S_buried) + 2.04*(g.Sht + p.geo.Nvt*g.Svt_each);
g.Swet_Sref = g.Swet/g.Sw;
% Internal fuel volume: Raymer wing-tank estimate + fuselage tank guess
tau = p.geo.tc_tip/p.geo.tc_root; lam = p.geo.taper;
V_wing = 0.54*(g.Sw^2/g.b)*p.geo.tc_root*(1 + lam*sqrt(tau) + lam^2*tau)/(1+lam)^2;
V_wing = V_wing*0.85;                                      % [ASSUME] lose some to structure/fold
g.W_fuel_avail = 0.95*(V_wing + p.geo.V_fus_fuel_ft3)*6.8*7.4805;   % lb JP-5 (6.8 lb/gal)
end

function [OEW, bd] = oew_buildup(p, g, W0, W_mid, W_land, W_fuel)
% Class II component buildup: Raymer fighter/attack statistical group weights (lb, ft, ft^2, gal),
% with unmanned deletions and composite / stealth / carrier factors.
% CROSS-CHECK every coefficient against your edition of Raymer (Table 15.2 in the 5th ed).
%   1. Wdg*Nz uses MID-MISSION weight and ULTIMATE load (1.5 x 5 g): RFP gives 5 g at mid-mission
%      weight. (Raymer's text says design gross weight -- this is a judgment call, state it.)
%   2. Crew items deleted (seat, furnishings, canopy, crew ECS/instruments).
%   3. RFP's 1,000 lb avionics is carried as installed OEW, not via the avionics regression.
Nz  = p.req.Nz_limit * p.req.FoS;
Wdg = W_mid;
Wl  = W_land;
Nl  = 1.5 * p.geo.N_gear_limit;
M   = p.mis.M_dash;
e   = p.eng;  Nen = e.N;
Nc  = 1;                               % crew exponent placeholder (keeps Nc^x terms finite)
items = cell(0,3);                     % {name, group, weight}

% ---- structures ----
Kdw = 1; Kvs = 1;                      % 0.768 delta wing; 1.19 variable sweep
W_wing = 0.0103*Kdw*Kvs*(Wdg*Nz)^0.5 * g.Sw^0.622 * p.geo.AR^0.785 ...
       * p.geo.tc_root^-0.4 * (1+p.geo.taper)^0.05 / cosd(p.geo.sweep_c4) * g.Scsw^0.04;
W_wing = W_wing * p.tech.f_wing;
items(end+1,:) = {'Wing', 'Structure', W_wing};
items(end+1,:) = {'Wing fold mechanism', 'Carrier', p.tech.wing_fold_frac*W_wing};
if g.Sht > 0
    Bh = sqrt(3.5*g.Sht);  Fw = 0.5*p.geo.W_fus;
    W_ht = 3.316*(1 + Fw/Bh)^-2 * (Wdg*Nz/1000)^0.260 * g.Sht^0.806;
    items(end+1,:) = {'Horizontal tail', 'Structure', W_ht*p.tech.f_tail};
end
if g.Svt_each > 0
    Krht=1; HtHv=0; SrSv=0.25; Avt=1.3; lam_vt=0.4; sw_vt=40;     % [ASSUME] tail details
    W_vt1 = 0.452*Krht*(1+HtHv)^0.5*(Wdg*Nz)^0.488*g.Svt_each^0.718*M^0.341 ...
          / p.geo.Lt * (1+SrSv)^0.348 * Avt^0.223 * (1+lam_vt)^0.25 / cosd(sw_vt)^0.323;
    items(end+1,:) = {'Vertical tails', 'Structure', p.geo.Nvt*W_vt1*p.tech.f_tail};
end
Kdwf = 1;                              % 0.774 delta wing
W_fus = 0.499*Kdwf*Wdg^0.35*Nz^0.25*p.geo.L_fus^0.5*p.geo.D_fus^0.849*p.geo.W_fus^0.685;
W_fus = W_fus * p.tech.f_fus;
items(end+1,:) = {'Fuselage (base)', 'Structure', W_fus};
items(end+1,:) = {'Fuselage: weapons-bay penalty', 'Stealth', W_fus*(p.tech.k_bay_fus-1)};
items(end+1,:) = {'Fuselage: carrier load paths', 'Carrier', W_fus*p.tech.k_bay_fus*(p.tech.k_carrier_fus-1)};
Kcb = 1; Ktpg = 1;                     % Kcb = cross-beam gear factor (NOT carrier), Ktpg = tripod
W_mlg = Kcb*Ktpg*(Wl*Nl)^0.25 * p.geo.L_mlg_in^0.973;
W_nlg = (Wl*Nl)^0.290 * p.geo.L_nlg_in^0.5 * 2^0.525;            % 2 nose wheels
W_lg  = (W_mlg + W_nlg)*p.tech.f_gear;
items(end+1,:) = {'Landing gear', 'Structure', W_lg};
items(end+1,:) = {'Landing gear: carrier (launch bar, holdback)', 'Carrier', W_lg*(p.tech.k_carrier_gear-1)};
items(end+1,:) = {'Arresting hook', 'Carrier', p.tech.W_hook};
items(end+1,:) = {'External hardpoint provisions', 'Structure', p.tech.n_hardpoints*p.tech.W_hardpoint};
items(end+1,:) = {'Weapons-bay doors + actuators', 'Stealth', p.geo.bay_door_ft2*p.tech.door_lb_ft2};
items(end+1,:) = {'RAM / edge treatments', 'Stealth', p.tech.RAM_lb_ft2*g.Swet};

% ---- propulsion (installed) ----
Te = e.T_max_SL;  De = e.D_ft;  Le = e.L_ft;
items(end+1,:) = {'Engine(s) dry', 'Propulsion', Nen*e.W_dry};
Wp = 0.013*Nen^0.795*Te^0.579*Nz ...                       % mounts
   + 1.13*(pi*De*0.5*Le) ...                                % firewall (area approximated)
   + 0.01*e.W_dry^0.717*Nen*Nz ...                           % engine section
   + 3.5*De*8*Nen ...                                        % tailpipe (8 ft)
   + 4.55*De*Le*Nen ...                                      % engine cooling
   + 37.82*Nen^1.023 ...                                     % oil cooling
   + 10.5*Nen^1.008*20^0.222 ...                             % engine controls (20 ft run)
   + 0.025*Te^0.760*Nen^0.72;                                % starter
items(end+1,:) = {'Engine installation (mounts, cooling, controls...)', 'Propulsion', Wp};
W_inlet = 13.29*1*p.geo.L_duct^0.643*p.geo.K_duct^0.182*Nen^1.498*1^-0.373*De;
items(end+1,:) = {'Air induction (serpentine duct)', 'Propulsion', W_inlet*p.tech.f_inlet};
Vt = W_fuel/6.8;  Vi = Vt;  Vp = p.wt.protected_frac*Vt;     % gal (JP-5)
[~, sfc_max] = engine_perf(e, 0, 0, 'max');
W_fs = 7.45*Vt^0.47*(1+Vi/Vt)^-0.095*(1+Vp/Vt)*p.wt.N_tanks^0.066*Nen^0.052 ...
     * (Nen*Te*sfc_max/1000)^0.249;
items(end+1,:) = {'Fuel system', 'Propulsion', W_fs};

% ---- systems (no crew) ----
Scs = g.Scsw + 0.3*g.Sht + 0.25*g.Svt_each*p.geo.Nvt;
items(end+1,:) = {'Flight controls', 'Systems', 36.28*M^0.003*Scs^0.489*p.wt.N_fc_sys^0.484*Nc^0.127};
items(end+1,:) = {'Instruments (non-crew)', 'Systems', 8.0 + 36.37*Nen^0.676*p.wt.N_tanks^0.237};
items(end+1,:) = {'Hydraulics', 'Systems', 37.23*1*p.wt.N_hyd_func^0.664};
items(end+1,:) = {'Electrical', 'Systems', 172.2*1.45*p.wt.Rkva^0.152*Nc^0.10*40^0.10*2^0.091};
W_av = p.wt.W_avionics_rfp + p.wt.W_autonomy_add;
items(end+1,:) = {'Avionics/sensors (RFP 1,000 lb)', 'Systems', p.wt.W_avionics_rfp};
items(end+1,:) = {'Autonomy/VMS/JPALS/datalinks', 'Systems', p.wt.W_autonomy_add};
items(end+1,:) = {'ECS / anti-ice (avionics cooling)', 'Systems', 201.6*(W_av/1000)^0.735};
items(end+1,:) = {'Handling gear', 'Systems', 3.2e-4*W0};
if p.wt.N_crew > 0      % validation runs only
    Ncr = p.wt.N_crew;
    items(end+1,:) = {'Crew: furnishings/seat', 'Systems', 217.6*Ncr};
    items(end+1,:) = {'Crew: instruments', 'Systems', 26.4*(1+Ncr)^1.356};
    items(end+1,:) = {'Crew: ECS increment', 'Systems', 201.6*((W_av+200*Ncr)/1000)^0.735 - 201.6*(W_av/1000)^0.735};
end

bd.name = items(:,1)'; bd.group = items(:,2)'; bd.W = cell2mat(items(:,3))';
bd.sum_raw = sum(bd.W);
bd.growth  = p.wt.growth*bd.sum_raw;
OEW = bd.sum_raw + bd.growth;
end

function [W, TDmin] = seg_cruise(W, dist_nm, M, h, setting, dcd, aero, e, S)
% Steady level segment, 20 steps. T = D; TSFC rises at part throttle (e.k_part).
[~,~,rho,aa] = std_atmos(h);
V = M*aa; q = 0.5*rho*V^2; n = 20; dt = dist_nm*6076.12/n/V;
[Tav, sfc] = engine_perf(e, M, h, setting); Tav = e.N*Tav;
TDmin = Inf;
for k = 1:n
    CL = W/(q*S); D = q*S*drag_coeff(aero, CL, M, dcd);
    TDmin = min(TDmin, Tav/D);
    thr = min(D/Tav, 1);
    W = W - sfc*(1 + e.k_part*(1-thr))/3600*D*dt;
end
end

function W = seg_loiter(W, h, tmin, dcd, aero, e, S)
% Loiter at CL for max L/D (CL = sqrt(CD0/K)), 10 steps.
[~,~,rho,aa] = std_atmos(h);
n = 10; dt = tmin*60/n;
CL = sqrt((aero.CD0 + dcd)/aero.K);
for k = 1:n
    V = sqrt(2*W/(rho*S*CL)); M = V/aa;
    D = 0.5*rho*V^2*S*drag_coeff(aero, CL, M, dcd);
    [Tav, sfc] = engine_perf(e, M, h, 'mil'); Tav = e.N*Tav;
    thr = min(D/Tav, 1);
    W = W - sfc*(1 + e.k_part*(1-thr))/3600*D*dt;
end
end

function ratio = td_point(W, M, h, setting, dcd, aero, e, S)
[~,~,rho,aa] = std_atmos(h); V = M*aa; q = 0.5*rho*V^2;
D = q*S*drag_coeff(aero, W/(q*S), M, dcd);
ratio = e.N*engine_perf(e, M, h, setting)/D;
end

function [W_fuel, info] = mission_fuel(p, W0, g, aero, type, radius_nm)
% Fuel for a mission starting at W0. type = 'strike' (sizing) | 'a2a' (check).
% Warm-up/climb/descent use historical fractions (replace with climb integration later).
% W_fuel includes trapped fuel. info carries thrust/drag margins.
if nargin < 6, radius_nm = p.mis.radius_nm; end
m = p.mis; e = p.eng; S = g.Sw;
info.dash_TD_min = Inf; info.cruise_TD_min = Inf;
switch lower(type)
    case 'strike'
        if p.store.size_to_cap, W_drop = p.store.cap_internal - p.store.W_rack;
        else,                   W_drop = p.store.W_drop; end
        dcd = 0;                                            % internal stores -> clean
        W = W0*m.frac_warmup*m.frac_climb;
        [W, td] = seg_cruise(W, radius_nm - m.dash_nm, m.M_cruise, m.h_cruise, 'mil', dcd, aero, e, S);
        info.cruise_TD_min = min(info.cruise_TD_min, td);
        W = W*m.frac_descent;
        [W, td] = seg_cruise(W, m.dash_nm, m.M_dash, 0, 'mil', dcd, aero, e, S);      % ingress
        info.dash_TD_min = min(info.dash_TD_min, td);
        if m.t_attack_min > 0
            [T, sfc] = engine_perf(e, m.M_dash, 0, 'mil');
            W = W - e.N*T*sfc/60*m.t_attack_min;
        end
        W = W - W_drop;                                      % weapons release
        [W, td] = seg_cruise(W, m.dash_nm, m.M_dash, 0, 'mil', dcd, aero, e, S);      % egress
        info.dash_TD_min = min(info.dash_TD_min, td);
        W = W*m.frac_climb;
        W = seg_cruise(W, radius_nm - m.dash_nm, m.M_cruise, m.h_cruise, 'mil', dcd, aero, e, S);
        W = W*m.frac_descent;
        W_before_res = W;
        W = seg_loiter(W, m.h_loiter, m.t_loiter_min, dcd, aero, e, S);
        W = W*m.frac_attempt^m.n_land_attempt;
        used = W0 - W - W_drop;
        info.W_stores_total = W_drop + p.store.W_rack;
    case 'a2a'
        a = p.a2a;
        Wst = a.n_msl*(a.W_msl + a.W_launcher);
        dcd = a.n_msl*a.Dq_station/S;                        % external stations
        W = W0*m.frac_warmup*m.frac_climb;
        W = seg_cruise(W, radius_nm, m.M_cruise, m.h_cruise, 'mil', dcd, aero, e, S);
        W = W*m.frac_descent;
        [T, sfc] = engine_perf(e, a.M_combat, a.h_combat, 'max');
        W = W - e.N*T*sfc/60*a.t_combat_min;                 % combat at max thrust
        W_fired = 0;
        if a.fire_missiles
            W_fired = a.n_msl*a.W_msl; W = W - W_fired;
            dcd = a.n_msl*0.4*a.Dq_station/S;
        end
        W = W*m.frac_climb;
        W = seg_cruise(W, radius_nm, m.M_cruise, m.h_cruise, 'mil', dcd, aero, e, S);
        W = W*m.frac_descent;
        W_before_res = W;
        W = seg_loiter(W, m.h_loiter, m.t_loiter_min, dcd, aero, e, S);
        W = W*m.frac_attempt^m.n_land_attempt;
        used = W0 - W - W_fired;
        info.W_stores_total = Wst;
        Wmid = W0 - 0.5*used;     % RFP point performance: M0.8 required / M0.95 desired at 30k ft
        info.a2a_dash_TD_080 = td_point(Wmid, 0.80, 30000, 'max', dcd, aero, e, S);
        info.a2a_dash_TD_095 = td_point(Wmid, 0.95, 30000, 'max', dcd, aero, e, S);
    otherwise
        error('mission type?');
end
info.W_end   = W;
info.reserve = W_before_res - W;                             % loiter + landing attempts
W_fuel = used*(1 + m.trapped_frac);
end

function r = size_aircraft(p)
% Fixed-point sizing: W0 = OEW(W0) + stores + fuel(W0) for the strike mission.
W0 = p.W0_guess; OEW = 0.5*W0; hist = [];
r.converged = false;
for it = 1:p.max_iter
    g    = geometry_from_W0(p, W0);
    aero = aero_setup(p, g.Sw, g.Swet);
    [Wf, mi] = mission_fuel(p, W0, g, aero, 'strike');
    Wst  = mi.W_stores_total;
    Wmid = W0 - 0.5*Wf;
    % RFP arrestment weight: OEW + max(reserve fuel, 25% of (mission = max) fuel) + 50% stores
    Wland = OEW + max(mi.reserve, 0.25*Wf) + 0.5*Wst;
    [OEW, bd] = oew_buildup(p, g, W0, Wmid, Wland, Wf);
    W0_new = OEW + Wst + Wf;
    hist(end+1) = W0_new; %#ok<AGROW>
    if abs(W0_new - W0) < p.tol && it > 2
        W0 = W0_new; r.converged = true; break;
    end
    W0 = W0 + p.relax*(W0_new - W0);
    if W0 > 2e5 || ~isfinite(W0), break; end
end
g = geometry_from_W0(p, W0); aero = aero_setup(p, g.Sw, g.Swet);
r.W0 = W0; r.OEW = OEW; r.W_fuel = Wf; r.W_stores = Wst;
r.W_mid = Wmid; r.W_land = Wland; r.bd = bd; r.g = g; r.aero = aero;
r.mis = mi; r.hist = hist; r.iter = it;
r.OEW_frac = OEW/W0; r.fuel_frac = Wf/W0;
r.TW = p.eng.N*p.eng.T_max_SL/W0;
r.cost = cost_dapca(p, OEW);
end

function c = cost_dapca(p, We)
% DAPCA IV (Raymer Ch.18; lb & knots; 2012$), inflated. Coefficients cross-checked against
% AeroSandbox's implementation (SI units converted back). RDT&E = engineering, tooling,
% development support, flight test. Recurring = (mfg + QC labor + materials)/Q + avionics + engines.
k = p.cost; Q = k.Q;
[~,~,~,a0] = std_atmos(0);
V = p.mis.M_dash*a0*0.592484;              % max speed, kts (SL dash)
HE = 4.86*We^0.777*V^0.894*Q^0.163;
HT = 5.99*We^0.777*V^0.696*Q^0.263;
HM = 7.37*We^0.820*V^0.484*Q^0.641;
HQ = 0.133*HM;                             % non-cargo aircraft
CD = 91.3*We^0.630*V^1.3;                  % development support
CF = 2498*We^0.325*V^0.822*k.FTA^1.21;     % flight test
CM = 22.1*We^0.921*V^0.621*Q^0.799;        % manufacturing materials
f = k.infl;
c.recurring_airframe = f*(HM*k.R_mfg*k.f_mfg + HQ*k.R_qc*k.f_mfg + CM*k.f_mat)/Q;
W_av = p.wt.W_avionics_rfp + p.wt.W_autonomy_add;
c.avionics = f*k.avionics_per_lb_2012*W_av;
c.engines  = p.eng.N*k.engine_price;
c.unit_recurring = c.recurring_airframe + c.avionics + c.engines;
c.RDTE = f*(HE*k.R_eng*k.f_eng + HT*k.R_tool*k.f_tool + CD + CF);
c.unit_program = c.unit_recurring + c.RDTE/Q;
c.V_kts = V;
end

function [W0a, Wf, info] = a2a_close(p, r, R)
% Solve W0 = OEW + stores + fuel(W0) for the A2A mission with the airframe FIXED.
W0a = r.OEW + 2000 + 0.3*r.W0;
for k = 1:60
    [Wf, info] = mission_fuel(p, W0a, r.g, r.aero, 'a2a', R);
    Wn = r.OEW + info.W_stores_total + Wf;
    if abs(Wn - W0a) < 1, W0a = Wn; break; end
    W0a = W0a + 0.7*(Wn - W0a);
end
end

function cons = check_constraints(p, r, do_print)
% RFP pass/fail on the sized aircraft. Catapult / arresting-gear speeds are computed but must be
% read against the C-13-2 and Mk7 Mod3 charts in RFP Section 5 (not digitized here).
g = r.g; a = r.aero; kts = 0.592484;
cons.span        = g.b;
cons.span_fold   = max(g.b_fold, g.b_ht);
cons.length      = p.geo.L_fus;
FA18C_footprint  = 27.5*56.0;          % ft^2 folded span x length [VERIFY spot-factor definition]
cons.spot        = cons.span_fold*cons.length/FA18C_footprint;
cons.fuel_avail  = g.W_fuel_avail;
cons.fuel_margin = g.W_fuel_avail - r.W_fuel;
cons.dash_TD     = r.mis.dash_TD_min;
[~,~,rho0] = std_atmos(0);
Vs_land          = sqrt(2*r.W_land/(rho0*g.Sw*a.CLmax_land));
cons.Vapp_kts    = 1.10*Vs_land*kts;                 % RFP: approach > 1.1 x stall
cons.Veng_kts    = 1.05*cons.Vapp_kts;               % RFP: engaging speed = 1.05 x approach
[~,~,rhoT]       = std_atmos(0, 89.8-59);            % tropical day
cons.Vcat_kts    = sqrt(2*r.W0/(rhoT*g.Sw*0.9*a.CLmax_TO))*kts;   % speed at 0.9 CLmax
fuel_cap = max(r.W_fuel, g.W_fuel_avail);
[cons.a2a_W0_req, cons.a2a_fuel_req, ia] = a2a_close(p, r, p.a2a.radius_req_nm);
[cons.a2a_W0_des, cons.a2a_fuel_des]     = a2a_close(p, r, p.a2a.radius_des_nm);
cons.a2a_req_ok = cons.a2a_fuel_req <= fuel_cap && cons.a2a_W0_req <= p.req.MTOW_max;
cons.a2a_des_ok = cons.a2a_fuel_des <= fuel_cap && cons.a2a_W0_des <= p.req.MTOW_max;
cons.a2a_dash080_TD = ia.a2a_dash_TD_080;
cons.a2a_dash095_TD = ia.a2a_dash_TD_095;
if do_print
    fprintf('\n================ RFP CONSTRAINT CHECK ================\n');
    pf = {'FAIL','pass'};
    fprintf('%-38s %9.0f lb  (target %0.0f)   %s\n','TOGW (sized)', r.W0, p.req.W0_target, pf{1+(r.W0<=p.req.MTOW_max)});
    fprintf('%-38s %9.1f ft  (<= %g)      %s\n','Span, unfolded', cons.span, p.req.span_max, pf{1+(cons.span<=p.req.span_max)});
    fprintf('%-38s %9.1f ft  (<= %g)      %s\n','Span, folded (max of wing, htail)', cons.span_fold, p.req.span_fold_max, pf{1+(cons.span_fold<=p.req.span_fold_max)});
    fprintf('%-38s %9.1f ft  (<= %g)    %s\n','Length', cons.length, p.req.length_max, pf{1+(cons.length<=p.req.length_max)});
    fprintf('%-38s %9.2f     (<= %g)     %s\n','Spot factor (box approx., UNCONFIRMED)', cons.spot, p.req.spot_max, pf{1+(cons.spot<=p.req.spot_max)});
    fprintf('%-38s %9.0f lb  (avail %0.0f, guess)   %s\n','Internal fuel required', r.W_fuel, cons.fuel_avail, pf{1+(cons.fuel_margin>=0)});
    fprintf('%-38s %9.2f     (>= 1.0)     %s\n', sprintf('SL dash M%.2f  T_mil/D', p.mis.M_dash), cons.dash_TD, pf{1+(cons.dash_TD>=1)});
    fprintf('%-38s %9.1f kts (< %g)     %s\n','Approach speed (1.1 Vs, land wt)', cons.Vapp_kts, p.req.Vapp_max_kts, pf{1+(cons.Vapp_kts<p.req.Vapp_max_kts)});
    fprintf('%-38s %9.1f kts (1.05 x Vapp); ship-relative with 15 kt WOD = %.1f kts -> read vs Mk7 Mod3 chart\n','Engaging speed', cons.Veng_kts, cons.Veng_kts-15);
    fprintf('%-38s %9.1f kts -> read vs C-13-2 chart @ %0.0f lb\n','Cat speed at 0.9 CLmax (tropical)', cons.Vcat_kts, r.W0);
    fprintf('%-38s %9.0f lb landing weight (hook load not checked)\n','Arrestment weight (RFP def.)', r.W_land);
    fprintf('%-38s %9.0f lb TOGW, %5.0f lb fuel  %s\n', sprintf('A2A @ %d nm (req)', p.a2a.radius_req_nm), cons.a2a_W0_req, cons.a2a_fuel_req, pf{1+cons.a2a_req_ok});
    fprintf('%-38s %9.0f lb TOGW, %5.0f lb fuel  %s\n', sprintf('A2A @ %d nm (desired)', p.a2a.radius_des_nm), cons.a2a_W0_des, cons.a2a_fuel_des, pf{1+cons.a2a_des_ok});
    fprintf('%-38s %9.2f     (>= 1.0)     %s\n','A2A dash M0.80 @30k  T_max/D', cons.a2a_dash080_TD, pf{1+(cons.a2a_dash080_TD>=1)});
    fprintf('%-38s %9.2f     (desired)    %s\n','A2A dash M0.95 @30k  T_max/D', cons.a2a_dash095_TD, pf{1+(cons.a2a_dash095_TD>=1)});
end
end

function v = validate_fa18e(p0)
% One-point sanity check: run the OEW buildup on an approximate F/A-18E. Inputs are approximate
% public values [VERIFY]; the point is a calibration RATIO, not a precise answer.
p = p0;
p.req.Nz_limit = 7.5;  p.mis.M_dash = 1.6;
p.eng = engine_data('F414-GE-400'); p.eng.N = 2; p.eng.k_part = 0;
p.geo.AR = 4.0; p.geo.taper = 0.35; p.geo.sweep_c4 = 20; p.geo.tc_root = 0.05; p.geo.tc_tip = 0.03;
p.geo.L_fus = 60.3; p.geo.D_fus = 7.0; p.geo.W_fus = 8.0; p.geo.Lt = 18;
p.geo.L_mlg_in = 70; p.geo.L_nlg_in = 60; p.geo.L_duct = 12; p.geo.K_duct = 1.5;
p.geo.bay_door_ft2 = 0; p.geo.Nvt = 2;
p.tech.f_wing = 0.95; p.tech.f_tail = 0.95; p.tech.f_fus = 1.0; p.tech.f_gear = 1.0; p.tech.f_inlet = 1.0;
p.tech.k_bay_fus = 1.0; p.tech.RAM_lb_ft2 = 0; p.tech.n_hardpoints = 11; p.tech.W_hook = 400;
p.wt.W_avionics_rfp = 2000; p.wt.W_autonomy_add = 0; p.wt.N_crew = 1; p.wt.growth = 0;
p.wt.protected_frac = 1.0;
g.Sw = 500; g.b = sqrt(p.geo.AR*g.Sw); g.b_fold = 0.6*g.b;
g.cr = 2*g.Sw/(g.b*(1+p.geo.taper)); g.Scsw = 0.15*g.Sw;
g.Sht = 120; g.b_ht = sqrt(3.5*g.Sht); g.Svt_each = 52; g.Swet = 0;
W_dg = 51000; W_land = 44000; W_fuel = 14400;              % [VERIFY]
[OEW, bd] = oew_buildup(p, g, W_dg, W_dg, W_land, W_fuel);
v.OEW_model = OEW; v.OEW_pub = 32081;                      % [VERIFY] Boeing-listed empty weight
v.ratio = v.OEW_pub/OEW; v.bd = bd;
fprintf('\n=========== VALIDATION: F/A-18E (approx. inputs, ONE data point) ===========\n');
fprintf('Model OEW      %8.0f lb\nPublished OEW  %8.0f lb  [VERIFY]\nRatio pub/model %7.3f\n', OEW, v.OEW_pub, v.ratio);
fprintf('(Unmodeled: gun, detailed pylon system, LEX, escape system. Says nothing about stealth/composite/unmanned factors.)\n');
end

function breguet_check(p, r)
% Independent hand check of the integrated mission fuel: one outbound cruise leg vs Breguet
% with L/D and TSFC evaluated at the average weight.
m = p.mis; e = p.eng; S = r.g.Sw; leg = m.radius_nm - m.dash_nm;
Wi = r.W0*m.frac_warmup*m.frac_climb;
Wf_int = seg_cruise(Wi, leg, m.M_cruise, m.h_cruise, 'mil', 0, r.aero, e, S);
[~,~,rho,aa] = std_atmos(m.h_cruise); V = m.M_cruise*aa; q = 0.5*rho*V^2;
Wavg = 0.5*(Wi + Wf_int); CL = Wavg/(q*S); D = q*S*drag_coeff(r.aero, CL, m.M_cruise, 0);
[Tav, sfc] = engine_perf(e, m.M_cruise, m.h_cruise, 'mil'); thr = D/(e.N*Tav);
c_eff = sfc*(1 + e.k_part*(1-thr));                            % 1/hr
LD = Wavg/D; V_kts = V*0.592484;
Wf_br = Wi*exp(-leg*c_eff/(V_kts*LD));
fprintf('\n--- Breguet cross-check, one %d nm cruise leg ---\n', leg);
fprintf('L/D %.1f | throttle %.2f | TSFC_eff %.3f/hr | fuel: integrated %.0f lb vs Breguet %.0f lb (%.1f%% apart)\n', ...
    LD, thr, c_eff, Wi - Wf_int, Wi - Wf_br, 100*abs((Wi-Wf_int)-(Wi-Wf_br))/(Wi-Wf_int));
end

function tw = constraint_TW(ws, M, h, beta, n, setting, dcd, aero, e, Tref)
% T_ref/W0 required at a flight condition (Mattingly master equation, Ps = 0).
[~,~,rho,aa] = std_atmos(h); V = M*aa; q = 0.5*rho*V^2;
CL = n*beta*ws/q;
D_over_S = q*drag_coeff(aero, CL, M, dcd);
alpha = e.N*engine_perf(e, M, h, setting)/Tref;
tw = D_over_S/(alpha*ws);
end
>>>>>>> c6da25be336ae9bbfd656526205a2b4cf031b254
