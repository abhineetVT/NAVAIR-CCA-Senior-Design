function [W_fuel_burn, dt_sec, dd_ft] = segment_loiter(geom, aero, prop, W_start, alt_ft, mach, time_min, con_like)
%SEGMENT_LOITER  Constant-altitude endurance (holding) segment, TIME given
%   rather than distance. Same level-flight thrust=drag physics as
%   segment_cruise, just driven by dt instead of a target distance, and
%   normally flown at/near the best-L/D Mach (the caller sets mach; this
%   function does not search for L/D-max itself).

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        W_start (1,1) double {mustBePositive}
        alt_ft (1,1) double {mustBeNonnegative}
        mach (1,1) double {mustBePositive}
        time_min (1,1) double {mustBePositive}
        con_like struct = struct()
    end

    N_SUB = 4;
    dt_total_target = time_min * 60;
    state = get_state(alt_ft, mach);
    V = state.V;

    W = W_start;
    fuel_total = 0;
    dd_total = 0;
    dt_per_sub = dt_total_target / N_SUB;

    for k = 1:N_SUB
        CL = W / (state.q * geom.S_ref);
        CD = aero.compute_CD_at(state, CL, con_like);
        D  = CD * state.q * geom.S_ref;

        c = prop.TSFC(state, "max");
        fuel_sub = D * c * (dt_per_sub/3600);

        W = W - fuel_sub;
        fuel_total = fuel_total + fuel_sub;
        dd_total = dd_total + V*dt_per_sub;
    end

    W_fuel_burn = fuel_total;
    dt_sec = dt_total_target;
    dd_ft = dd_total;
end
