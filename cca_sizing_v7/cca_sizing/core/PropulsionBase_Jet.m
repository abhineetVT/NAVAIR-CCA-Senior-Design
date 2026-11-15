classdef (Abstract) PropulsionBase_Jet < handle
%PROPULSIONBASE_JET  Tier-1 abstract enforcer for jet propulsion models.
%
%   The thrust-based analogue of a power-based propulsion interface: a
%   sizing/constraint framework built around (T/W) and (W/S) instead of
%   (W/P) and (W/S). Concrete classes (e.g. CcaProp) determine how
%   available thrust, TSFC and engine size are computed for a specific
%   engine type (turbofan, turbojet, adaptive-cycle, ...).
%
%   Inheritance: PropulsionBase_Jet -> CcaProp

    properties (Abstract)
        engine_type   % string; identifies the engine type
        T_SL          % scalar; rated static sea-level installed thrust, ALL
                       % engines [lbf]. A STATE of the sizing loop.
        n_engines     % scalar; number of engines [-]
    end

    methods (Abstract)

        % THRUST_LAPSE
        %   Available installed thrust at the given state and rating,
        %   divided by T_SL (all engines) [-].
        alpha = thrust_lapse(obj, state, rating)

        % TSFC
        %   Thrust-specific fuel consumption [1/hr] at the given state and
        %   rating.
        c = TSFC(obj, state, rating)

        % THRUST_RATIO
        %   Thrust available at a constraint/mission condition, divided by
        %   T_SL (all engines) [-]. Collects altitude/Mach lapse, one-engine-
        %   inoperative, and throttle setting into one referral factor, the
        %   thrust-loading analogue of a power_ratio.
        kT = thrust_ratio(obj, state, con)

        % ENGINE_WEIGHT
        %   Bare weight of all engines [lbf].
        [W_total, W_each] = engine_weight(obj)

        % ENGINE_LENGTH
        %   Length of one engine [ft].
        L = engine_length(obj)

    end

end
