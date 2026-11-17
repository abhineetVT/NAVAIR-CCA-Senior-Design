function TW = constraint_cruise(geom, aero, prop, con, WS_vec)
%CONSTRAINT_CRUISE  Steady-level-cruise T/W lower bound. Thin wrapper over
%   level_flight_TW_required.m -- see that file for the physics and the
%   lower-bound sign convention this framework uses for every jet
%   constraint.
    TW = level_flight_TW_required(geom, aero, prop, con, WS_vec);
end
