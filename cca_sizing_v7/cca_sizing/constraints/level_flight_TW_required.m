function TW = level_flight_TW_required(geom, aero, prop, con, WS_vec)
%LEVEL_FLIGHT_TW_REQUIRED  Shared physics for any steady, level, unaccelerated
%   flight constraint point (cruise, dash, loiter-speed, max-speed, etc.) --
%   constraint_cruise.m and constraint_dash.m are both thin wrappers around
%   this, since the only thing that differs between "cruise constraint"
%   and "dash constraint" is WHICH (alt, mach) condition con carries, not
%   the physics.
%
%   T/W REQUIRED, SIGN CONVENTION.  This returns a LOWER bound on SEA-LEVEL
%   STATIC thrust-to-weight: the aircraft needs AT LEAST this much T/W for
%   this condition to be flyable. That is the opposite sense from the
%   reference propeller-aircraft code's (W/P), where each constraint was an
%   UPPER bound -- so the combined feasible envelope here is built from the
%   MAX of these lower-bound curves (matching_envelope.m), not the min of
%   upper bounds. Getting this backwards would silently produce an
%   UNDER-sized, infeasible engine; this file and matching_envelope.m are
%   where that correctness point is actually implemented.
%
%   TW = (D/W) / kT
%   where D/W = CD(CL)/CL... actually computed directly as CD(CL)*q/(W/S)
%   (level flight: L=W so CL=(W/S)/q, D=CD(CL)*q*S => D/W = CD(CL)*q/(W/S)),
%   and kT = prop.thrust_ratio(state,con) converts the REQUIRED thrust at
%   this altitude/Mach back to an equivalent SEA-LEVEL STATIC T/W, so every
%   constraint curve is plotted on the SAME (SL static) T/W axis
%   [standard matching-diagram normalization, e.g. Raymer 6th ed. Ch. 5 /
%   Mattingly constraint-analysis method].

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        con (1,1) struct
        WS_vec (1,:) double {mustBePositive}
    end

    state = get_state(con.alt, con.mach);
    kT = prop.thrust_ratio(state, con);

    CL_vec = WS_vec / state.q;
    TW = zeros(size(WS_vec));
    for i = 1:numel(WS_vec)
        CD = aero.compute_CD_at(state, CL_vec(i), con);
        DW = CD * state.q / WS_vec(i);
        TW(i) = DW / kT;
    end
end
