function [W_fuel_burn, dt_sec, dd_ft] = segment_climb(geom, aero, prop, W_start, alt_start_ft, alt_end_ft, mach, con_like)
%SEGMENT_CLIMB  Energy-height (specific-excess-power) climb segment.
%
%   Climb rate comes from Ps = (T-D)*V/W [the standard specific-excess-
%   power relation, e.g. Mattingly/Raymer energy-state method], evaluated
%   at the climb Mach held constant and at level-flight trim CL (small-
%   flight-path-angle approximation -- adequate for a conceptual-design
%   climb segment; no credit or penalty for airspeed buildup during the
%   climb is modeled). Ps is evaluated at the START and END altitude and
%   trapezoidally averaged, then time = delta_h / Ps_avg -- a standard
%   conceptual-sizing simplification of the full energy-climb integral.
%
%   con_like   struct with .n_stores_present / .stores_present, passed
%              through to aero.compute_CD_at and prop.thrust_ratio so a
%              climb flown after weapons release correctly drops both the
%              store drag and the available-thrust accounting for it.

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        W_start (1,1) double {mustBePositive}
        alt_start_ft (1,1) double {mustBeNonnegative}
        alt_end_ft (1,1) double {mustBeNonnegative}
        mach (1,1) double {mustBePositive}
        con_like struct = struct()
    end

    function Ps = excess_power_at(alt_ft)
        state = get_state(alt_ft, mach);
        CL = W_start / (state.q * geom.S_ref);
        CD = aero.compute_CD_at(state, CL, con_like);
        D  = CD * state.q * geom.S_ref;
        kT = prop.thrust_ratio(state, con_like);
        T  = kT * prop.T_SL;
        Ps_raw = (T - D) * state.V / W_start;
        if Ps_raw < 5
            warning('segment_climb:ThrustLimited', ...
                ['Climb at M=%.2f, alt=%.0f ft has excess power %.1f ft/s (T=%.0f, D=%.0f lbf): ', ...
                 'engine is too small to climb here; clamped to 5 ft/s, so fuel burn will be large.'], ...
                mach, alt_ft, Ps_raw, T, D);
        end
        Ps = max(Ps_raw, 5);   % clamp: avoid div-by-~0/negative
    end

    Ps_1 = excess_power_at(alt_start_ft);
    Ps_2 = excess_power_at(alt_end_ft);
    Ps_avg = 0.5*(Ps_1 + Ps_2);

    dh = alt_end_ft - alt_start_ft;
    dt_sec = dh / Ps_avg;

    state_mid = get_state(0.5*(alt_start_ft+alt_end_ft), mach);
    dd_ft = state_mid.V * dt_sec;

    kT_mid = prop.thrust_ratio(state_mid, con_like);
    T_mid = kT_mid * prop.T_SL;
    c_mid = prop.TSFC(state_mid, "max");   % per-engine TSFC, 1/hr
    n_op = prop.n_engines - double(isfield(con_like,'oei') && con_like.oei);

    W_fuel_burn = n_op * (T_mid/prop.n_engines) * c_mid * (dt_sec/3600);
end
