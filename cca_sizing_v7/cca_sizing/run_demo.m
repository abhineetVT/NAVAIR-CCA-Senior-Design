%RUN_DEMO  End-to-end demonstration of the CCA sizing framework.
%
%   1. Wire up every discipline from cca_requirements.json.
%   2. Close TOGW with the fixed-point sizing loop (hard spot-factor gate
%      enforced every iteration).
%   3. Re-plot the converged matching diagram and report the design point.
%   4. Run the standalone geometric RCS estimate (NOT part of sizing).
%   5. Run the airfoil-robustness panel-method sweep (NOT part of sizing).
%
%   Run with: run_demo   (from the cca_sizing/ folder, with all
%   subfolders on the MATLAB path -- addpath(genpath(pwd)) below does this
%   automatically if run from that folder).

addpath(genpath(pwd));

% Pick the case to run:
%   strike:       'cca_requirements.json'  + 'carrier_strike'  (4x SDB-II)
%   counter-air:  'cca_counter_air.json'   + 'counter_air'     (2x AIM-120D)
req_json     = 'cca_requirements.json';
mission_name = 'carrier_strike';

fprintf('=== CCA sizing: fixed-point TOGW closure (%s) ===\n', mission_name);
disc = cca_disciplines(req_json, 5000, 70, mission_name);

opts.relax = 0.5;
opts.tol_rel = 1e-4;
opts.max_iter = 50;
opts.verbose = true;

result = sizing_mainloop(disc.geom, disc.aero, disc.prop, disc.weights, ...
    disc.conditions, disc.missions, disc.W_TO_guess, opts);

fprintf('\nConverged in %d iterations.\n', result.n_iter);
fprintf('  W_TO        = %8.1f lbf\n', result.W_TO);
fprintf('  OEW         = %8.1f lbf\n', result.final_pass.OEW);
fprintf('  W_payload   = %8.1f lbf\n', result.final_pass.W_payload);
fprintf('  W_fuel load = %8.1f lbf  (burned %.1f + reserve %.1f)\n', result.final_pass.W_fuel_total, ...
    result.final_pass.W_fuel_burned, result.final_pass.W_fuel_reserve);
fprintf('  fuel capacity = %6.1f lbf  (wing %.1f ft^3, fuselage %.1f ft^3, usable %.1f ft^3)\n', ...
    disc.geom.fuel_capacity_lb, disc.geom.V_wing_ft3, disc.geom.V_fus_ft3, disc.geom.fuel_volume_ft3);
fprintf('  combat radius = %6.1f nm\n', result.final_pass.radius_nm);
fprintf('  S_ref       = %8.1f ft^2\n', result.final_pass.S_ref);
fprintf('  span b      = %8.1f ft\n', result.final_pass.b);
%% Aero numbers for the report
g = disc.geom;  aero = disc.aero;
state = get_state(30000, 0.70);                  % 30 kft, M0.7 cruise
polar = aero.drag_polar(state);

fprintf('\n--- Aero summary (30 kft, M0.70) ---\n');
fprintf('  CD0 (clean, incl. store increment) = %.4f\n', polar.CD0);
fprintf('  Oswald efficiency e                = %.3f\n', polar.e);
fprintf('  K1 = 1/(pi*AR*e)                   = %.4f\n', polar.K1);
fprintf('  Max L/D                            = %.2f at CL = %.2f\n', polar.LD_max, polar.CL_at_LDmax);
fprintf('  CLmax clean                        = %.2f\n', aero.get_CLmax(state, struct('config','clean')));
fprintf('  CLmax takeoff                      = %.2f\n', aero.get_CLmax(state, struct('config','takeoff')));
fprintf('  CLmax landing                      = %.2f\n', aero.get_CLmax(state, struct('config','landing')));
fprintf('  footprint   = %8.1f ft^2 (folded span x length)\n', disc.geom.b_effective*disc.geom.l_fus);
fprintf('  spot factor = %8.3f   (limit %.2f, reference %.0f ft^2)\n', result.final_pass.spot_factor, disc.geom.spot_factor_max, disc.geom.spot_reference_area);
fprintf('  engine mode = %s  (%d x %s)\n', disc.prop.engine_mode, disc.prop.n_engines, disc.prop.engine_type);
fprintf('  T_SL total  = %8.0f lbf (dry, sea-level static); required by constraints = %.0f lbf\n', ...
    result.final_pass.T_SL, result.final_pass.T_SL_required);
if disc.prop.engine_mode == "fixed"
    if result.final_pass.engine_ok
        fprintf('  [ OK ] engine is large enough; wing loading chosen = %.1f psf\n', result.final_pass.WS_design);
    else
        fprintf('  [FAIL] fixed engine cannot meet the constraint set at any allowed wing loading (short by %.0f lbf)\n', ...
            result.final_pass.T_SL_required - result.final_pass.T_SL);
    end
end
fprintf('  dash feasible (Mdd vs M=0.85+margin): %d\n', result.final_pass.dash_feasible);

fprintf('\n=== RFP geometry / weight limit checks ===\n');
g = disc.geom;
rfp_check('unfolded span <= 60 ft',            g.b,                 60);
rfp_check('folded span <= 35 ft',              g.b*g.fold_fraction, 35);
rfp_check('length <= F-35C (~51.5 ft, verify)', g.l_fus,            51.5);
rfp_check('TOGW <= 60,000 lbf',                result.W_TO,         60000);
rfp_check('spot factor <= 0.8 (footprint / reference)', g.spot_factor, 0.8);
rfp_check_min('combat radius >= 500 nm (threshold)', result.final_pass.radius_nm, 500);
rfp_check_min('combat radius >= 700 nm (objective)', result.final_pass.radius_nm, 700);
rfp_check_min('fuel capacity >= fuel loaded (lbf)', g.fuel_capacity_lb, result.final_pass.W_fuel_total);

thrust_report(disc, result);

fprintf('\n=== Converged matching diagram + design-point check ===\n');
WS_vec = linspace(40, 140, 100);
env = run_constraints(disc.geom, disc.aero, disc.prop, disc.conditions, WS_vec, true);
design_point_check(result.W_TO/disc.geom.S_ref, disc.prop.T_SL/result.W_TO, env.WS_vec, env.TW_curves, ...
    env.WS_max_landing, env.names);

fprintf('\n=== Standalone geometric RCS estimate (NOT wired into sizing) ===\n');
rcs_out = rcs_estimate(disc.geom, 0.03, 0:2:358, true); %#ok<NASGU>

fprintf('\n=== Airfoil panel-method robustness sweep (NOT wired into sizing) ===\n');
airfoil_table = airfoil_robustness_sweep(); %#ok<NASGU>

fprintf('\n=== Transonic foil estimate: NACA 65A210 ===\n');
airfoil_transonic('naca65a210'); %#ok<NASGU>

fprintf('\nDone.\n');


function rfp_check_min(label, value, minimum)
    if value >= minimum, tag = ' OK '; else, tag = 'FAIL'; end
    fprintf('[%s] %-48s %8.2f  (min %.2f)\n', tag, label, value, minimum);
end

function rfp_check(label, value, limit)
    if value <= limit, tag = ' OK '; else, tag = 'FAIL'; end
    fprintf('[%s] %-48s %8.2f  (limit %.2f)\n', tag, label, value, limit);
end


function thrust_report(disc, result)
%THRUST_REPORT  Dry vs afterburner thrust against drag at each cruise/dash
%   condition and at takeoff, at the converged aircraft.
    prop = disc.prop; geom = disc.geom; aero = disc.aero;
    W_TO = result.W_TO;
    fprintf('\n=== Thrust: dry vs afterburner (converged aircraft, W_TO = %.0f lbf) ===\n', W_TO);
    fprintf('SL static thrust: dry %.0f lbf, afterburner %.0f lbf  ->  T/W dry %.3f, AB %.3f\n', ...
        prop.T_SL, prop.T_SL*prop.ab_thrust_ratio*double(prop.has_afterburner) + prop.T_SL*double(~prop.has_afterburner), ...
        prop.T_SL/W_TO, prop.T_SL*(prop.ab_thrust_ratio*double(prop.has_afterburner) + double(~prop.has_afterburner))/W_TO);
    fprintf('%-28s %9s %10s %10s  %s\n', 'condition', 'drag lbf', 'dry avail', 'AB avail', 'needs AB?');
    for i = 1:numel(disc.conditions)
        con = get_con(i, disc.conditions);
        if ~any(con.type == ["cruise","dash"]), continue; end
        state = get_state(con.alt, con.mach);
        W = con.beta * W_TO;
        CL = W/(state.q*geom.S_ref);
        D = aero.compute_CD_at(state, CL, con) * state.q * geom.S_ref;
        cd = con; cd.rating = "max";
        T_dry = prop.thrust_ratio(state, cd)*prop.T_SL;
        if prop.has_afterburner
            ca = con; ca.rating = "ab";
            T_ab = prop.thrust_ratio(state, ca)*prop.T_SL;
        else
            T_ab = NaN;
        end
        if D <= T_dry, need = 'no (dry is enough)';
        elseif D <= T_ab, need = 'YES (afterburner)';
        else, need = 'NO MARGIN even with AB'; end
        fprintf('%-28s %9.0f %10.0f %10.0f  %s\n', con.name, D, T_dry, T_ab, need);
    end
    for k = 1:numel(result.final_pass.mission.log)
        L = result.final_pass.mission.log(k);
        if L.used_ab
            fprintf('mission segment %d (%s) burned fuel with afterburner (%.1f lbf in segment)\n', k, L.type, L.fuel_burn_lbf);
        end
    end
end
