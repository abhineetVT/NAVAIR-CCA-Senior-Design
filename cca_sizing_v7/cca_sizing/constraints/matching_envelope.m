function env = matching_envelope(WS_vec, TW_curves, WS_max_landing)
%MATCHING_ENVELOPE  Combine every constraint curve into the feasible
%   region and pick the design point -- this is where the T/W-vs-W/P
%   sign-convention correction for a jet aircraft is actually applied.
%
%   SIGN CONVENTION.  Every TW_curves{k} is a LOWER bound on (SL static)
%   T/W (see level_flight_TW_required.m / constraint_climb.m /
%   constraint_takeoff.m): the aircraft needs AT LEAST that much T/W to
%   satisfy that one condition. To satisfy ALL conditions simultaneously
%   the aircraft needs AT LEAST the LARGEST of them -- so the combined
%   requirement is the point-wise MAX across curves, and the FEASIBLE
%   region is everything ON OR ABOVE that envelope. This is the opposite
%   combination rule from the reference propeller-aircraft code, whose
%   constraints were each an UPPER bound on W/P and so combined with a
%   point-wise MIN. Using MIN here (or porting the old code unchanged)
%   would silently pick a smaller, infeasible envelope and under-size the
%   engine -- this function exists specifically to get that right.
%
%   WS_max_landing caps the OTHER axis (a vertical line, from
%   constraint_landing.m, not a T/W curve) -- feasible W/S must also be
%   <= WS_max_landing.
%
%   DESIGN POINT.  Thrust (and therefore engine weight, cost, and often
%   drag) grows with T/W at fixed W/S, and wing weight/wetted area/spot-
%   factor span grow as W/S falls, so the minimum-T/W point on the
%   feasible boundary is taken at the LARGEST feasible W/S, i.e. right at
%   WS_max_landing -- the standard matching-diagram "corner point" choice
%   [Raymer 6th ed. Ch. 5].

    arguments
        WS_vec (1,:) double
        TW_curves cell
        WS_max_landing (1,1) double {mustBePositive}
    end

    n = numel(WS_vec);
    n_curves = numel(TW_curves);
    stacked = zeros(n_curves, n);
    for k = 1:n_curves
        stacked(k,:) = TW_curves{k}(:)';
    end
    TW_envelope = max(stacked, [], 1);

    feasible_WS = WS_vec <= WS_max_landing;
    if ~any(feasible_WS)
        error('matching_envelope:NoFeasibleWS', ...
            'No swept wing-loading point is below the landing wing-loading cap (%.2f psf).', ...
            WS_max_landing);
    end

    % Place the design point EXACTLY at the landing cap (interpolating the
    % envelope there) -- snapping to the nearest grid point could land on
    % the infeasible side of the cap.
    env.WS_vec = WS_vec;
    env.TW_envelope = TW_envelope;
    env.WS_max_landing = WS_max_landing;
    env.WS_design = WS_max_landing;
    env.TW_design = interp1(WS_vec, TW_envelope, WS_max_landing, 'linear', 'extrap');
    env.n_curves = n_curves;
end
