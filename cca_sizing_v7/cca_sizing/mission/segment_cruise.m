function [W_fuel_burn, dt_sec, dd_ft, used_ab] = segment_cruise(geom, aero, prop, W_start, alt_ft, mach, dist_nm, con_like)
%SEGMENT_CRUISE  Level, constant-altitude/Mach cruise OR dash leg.
%
%   Used for BOTH "cruise" and "dash" segment types -- a dash leg is just
%   a cruise segment flown at mach = 0.85 (or whatever dash Mach is set in
%   the mission JSON), so the physics are identical and are not
%   duplicated into a separate file. This is also where the Mach-0.85
%   dash requirement actually gets EXERCISED in the mission (as opposed
%   to CcaGeom.Mdd/dash_feasible, which checks it can be reached
%   aerodynamically at all): if prop.thrust_ratio at this condition can't
%   supply the required thrust, fuel burn is still computed (so the
%   mission doesn't crash), but D > T_available is flagged.
%
%   Weight is held constant at W_start for the whole leg at this fidelity
%   level EXCEPT that the leg is internally split into N_SUB sub-legs so a
%   long cruise still sees its own weight decrease as fuel burns
%   (level, unaccelerated flight: thrust = drag, so fuel flow = D * TSFC;
%   this is exactly the quantity integrated by the classical Breguet range
%   equation, just evaluated by direct sub-stepping here instead of in
%   closed form, so the SAME drag-polar call aero.compute_CD_at used
%   everywhere else in this framework is reused rather than needing a
%   separate closed-form L/D at one design point).

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        W_start (1,1) double {mustBePositive}
        alt_ft (1,1) double {mustBeNonnegative}
        mach (1,1) double {mustBePositive}
        dist_nm (1,1) double {mustBePositive}
        con_like struct = struct()
    end

    % con_like.rating: "max" (dry, default), "ab" (always afterburner) or
    % "auto" (afterburner only on sub-legs where drag exceeds dry thrust).
    rating_req = "max";
    if isfield(con_like, 'rating'), rating_req = string(con_like.rating); end
    used_ab = false;

    N_SUB = 4;
    dist_ft_total = dist_nm * 6076.12;
    state = get_state(alt_ft, mach);
    V = state.V;

    W = W_start;
    dt_total = 0;
    fuel_total = 0;
    dd_per_sub = dist_ft_total / N_SUB;

    for k = 1:N_SUB
        CL = W / (state.q * geom.S_ref);
        CD = aero.compute_CD_at(state, CL, con_like);
        D  = CD * state.q * geom.S_ref;             % = required thrust, level flight

        con_dry = con_like;  con_dry.rating = "max";
        con_ab  = con_like;  con_ab.rating  = "ab";
        use_ab = false;
        if rating_req == "ab"
            use_ab = true;
        elseif rating_req == "auto" && D > prop.thrust_ratio(state, con_dry) * prop.T_SL
            use_ab = true;
        end
        if use_ab
            kT = prop.thrust_ratio(state, con_ab);
            used_ab = true;
        else
            kT = prop.thrust_ratio(state, con_dry);
        end
        T_avail = kT * prop.T_SL;
        if D > T_avail
            warning('segment_cruise:ThrustLimited', ...
                ['Required thrust %.0f lbf exceeds available %.0f lbf at ', ...
                 'M=%.2f, alt=%.0f ft, W=%.0f lbf -- this cruise/dash leg is ', ...
                 'not sustainable at the current sizing point.'], D, T_avail, mach, alt_ft, W);
        end

        dt_sub = dd_per_sub / V;
        if use_ab, c = prop.TSFC(state, "ab"); else, c = prop.TSFC(state, "max"); end
                                                     % [1/hr], same for every
                                                     % engine, so total fuel
                                                     % flow = (total thrust
                                                     % required) * c regardless
                                                     % of how many engines
                                                     % share that thrust
        fuel_sub = D * c * (dt_sub/3600);

        W = W - fuel_sub;
        dt_total = dt_total + dt_sub;
        fuel_total = fuel_total + fuel_sub;
    end

    W_fuel_burn = fuel_total;
    dt_sec = dt_total;
    dd_ft = dist_ft_total;
end
