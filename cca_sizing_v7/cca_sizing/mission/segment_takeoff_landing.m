function [W_fuel_burn, dt_sec, dd_ft] = segment_takeoff_landing(type, W_start)
%SEGMENT_TAKEOFF_LANDING  Carrier takeoff/landing fuel allowance.
%
%   Per the project scope ("doesn't need to get too deep into the
%   specifics" of carrier launch/recovery), this segment does NOT model
%   catapult energy, hook-engagement loads, or approach speed/AoA -- those
%   belong to the constraint-analysis takeoff/landing-distance checks
%   (constraints/constraint_takeoff.m, constraint_landing.m), not to the
%   fuel/time/distance mission accounting done here. This segment only
%   books the historical fixed MISSION FUEL FRACTION for engine start,
%   taxi, takeoff and landing/taxi-in [Raymer 6th ed. Table 3.2-style
%   fuel-fraction allowances, fighter-class aircraft], since the sizing
%   loop's fuel closure needs SOME accounting for these phases even though
%   they are not separately time/distance-integrated.
%
%   type   "takeoff" or "landing"
%   Returns W_fuel_burn [lbf], dt_sec = 0, dd_ft = 0 (not distance/time
%   phases at this fidelity level).

    arguments
        type {mustBeTextScalar}
        W_start (1,1) double {mustBePositive}
    end

    switch string(type)
        case "takeoff"
            frac = 0.015;   % start, taxi, deck run, catapult stroke
        case "landing"
            frac = 0.010;   % approach, arrestment, taxi-in
        otherwise
            error('segment_takeoff_landing:UnknownType', ...
                'type must be "takeoff" or "landing", got "%s".', type);
    end

    W_fuel_burn = frac * W_start;
    dt_sec = 0;
    dd_ft = 0;
end
