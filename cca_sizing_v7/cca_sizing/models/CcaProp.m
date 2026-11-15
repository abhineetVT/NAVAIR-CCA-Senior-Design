classdef CcaProp < PropulsionBase_Jet
%CCAPROP  Jet propulsion module -- configurable engine count, thrust lapse,
%   TSFC, OEI/derate logic, engine weight and length.
%
%   Mirrors the reference TtpaProp's role (propulsion-state -> usable
%   thrust and fuel flow at any flight condition) but for a THRUST-based
%   (turbofan), not POWER-based (piston/prop), engine, and with n_engines
%   as a first-class configurable input instead of fixed at one.
%
%   THRUST LAPSE  [Mattingly/Heiser/Pratt-type simplified turbofan lapse
%   correlation, as tabulated for conceptual design in Raymer 6th ed.
%   Table 5.1/Eq. 5.1-class models]. The exact coefficients are a modern,
%   low-to-moderate-bypass MILITARY turbofan (F404/F414-class) shape:
%   thrust falls off with altitude as a density-ratio power law, and has
%   a mild ram-recovery RISE with Mach at low-moderate Mach before it
%   falls off again approaching the compressor's corrected-flow limit --
%   the familiar "bucket" shape of installed military-turbofan thrust
%   lapse. This is a representative conceptual-design correlation, not a
%   specific engine's certified deck; it is exposed on the class
%   (lapse_sigma_exp, lapse_mach_a / _b) so it can be recalibrated to a
%   real engine deck if one becomes available later in the design.
%
%   TSFC  rises mildly with Mach (ram drag / lower propulsive efficiency
%   at the engine, approximated linearly) and is otherwise altitude-
%   independent at this fidelity level [standard conceptual-design
%   assumption, e.g. Raymer 6th ed. Sec. 5.1].
%
%   ENGINE WEIGHT & LENGTH  from the engine's own sea-level static thrust
%   via a thrust-to-weight ratio and a thrust-to-length scaling constant,
%   both calibrated to modern fighter-class turbofans (F404/F414 order of
%   magnitude: ~8:1 T/W bare, ~14-15 ft length at ~13,000-22,000 lbf) --
%   again exposed as class properties so they are easy to recalibrate.

    properties
        engine_type = "low_bypass_turbofan"
        n_engines
        thrust_scale = 1.0
        % Mutable engine-size scale factor: THE sizing-loop state for this
        % class, exactly analogous to CcaGeom.S_ref. T_SL_each read from
        % the requirements JSON is the STARTING-GUESS engine size;
        % sizing_pass.m rescales thrust_scale each iteration so that
        % n_engines*T_SL_each*thrust_scale matches the current T/W design
        % point's required total sea-level static thrust, which is what
        % "sizing the engine" means in this fixed-point loop. Engine
        % WEIGHT (engine_weight) and LENGTH (engine_length) scale with it
        % too, exactly as a real engine of a different thrust class would
        % be heavier/longer -- i.e. re-engining, not just re-rating.
    end

    properties (SetAccess = immutable)
        T_SL_each          % sea-level static thrust, EACH engine [lbf]
        BPR                % bypass ratio (shape parameter, documentation only)
        c0_per_hr          % sea-level static TSFC [1/hr], dry rating
        c0_per_hr_ab       % TSFC with afterburner engaged, if used
        has_afterburner logical
        ab_thrust_ratio    % afterburner / dry thrust ratio (F414: ~22000/13000)
        engine_mode        % "scaled" (engine resized by the loop) or "fixed" (real engine)

        lapse_sigma_exp = 0.7
        lapse_mach_a    = 0.25   % ram-recovery rise coefficient
        lapse_mach_b    = 0.40   % high-Mach fall-off coefficient

        engine_TW_ratio = 8.0    % bare engine thrust-to-weight [lbf/lbf]
        engine_len_k    = 0.33   % L_ft = k * T_each^0.4
    end

    properties (Dependent)
        T_SL               % TOTAL sea-level static thrust, all engines [lbf]
    end

    methods
        function obj = CcaProp(json_path)
            arguments
                json_path {mustBeTextScalar, mustBeNonzeroLengthText}
            end
            J = jsondecode(fileread(json_path));
            P = J.propulsion;

            obj.engine_type   = string(getdef(P, 'engine_type', "low_bypass_turbofan"));
            obj.n_engines     = P.n_engines;
            obj.T_SL_each     = P.T_SL_each_lbf;
            obj.BPR           = getdef(P, 'bypass_ratio', 0.3);
            obj.c0_per_hr     = P.TSFC_sl_dry_per_hr;
            obj.has_afterburner = getdef(P, 'has_afterburner', false);
            obj.c0_per_hr_ab  = getdef(P, 'TSFC_sl_ab_per_hr', obj.c0_per_hr*1.9);
            obj.ab_thrust_ratio = getdef(P, 'ab_thrust_ratio', 1.5);
            obj.engine_mode   = lower(string(getdef(P, 'engine_mode', "scaled")));
            if ~any(obj.engine_mode == ["scaled","fixed"])
                error('CcaProp:BadEngineMode', 'propulsion.engine_mode must be "scaled" or "fixed".');
            end

            obj.lapse_sigma_exp = getdef(P, 'lapse_sigma_exp', 0.7);
            obj.lapse_mach_a    = getdef(P, 'lapse_mach_a', 0.25);
            obj.lapse_mach_b    = getdef(P, 'lapse_mach_b', 0.40);
            obj.engine_TW_ratio = getdef(P, 'engine_TW_ratio', 8.0);
            obj.engine_len_k    = getdef(P, 'engine_len_k', 0.33);
        end

        function val = get.T_SL(obj)
            val = obj.n_engines * obj.T_SL_each * obj.thrust_scale;
        end

        function T_each_current = T_SL_each_current(obj)
            T_each_current = obj.T_SL_each * obj.thrust_scale;
        end

        %% ---------------- PropulsionBase_Jet interface -------------------
        function alpha = thrust_lapse(obj, state, rating)
        %THRUST_LAPSE  alpha = T_available(alt,M) / T_SL, ONE engine,
        %   at dry or afterburner rating. "military"/"max" dry; "ab" if
        %   has_afterburner.
            if nargin < 3, rating = "max"; end
            sigma = state.sigma;
            M = state.mach;
            shape = 1 + obj.lapse_mach_a*M - obj.lapse_mach_b*M^2;
            alpha = (sigma^obj.lapse_sigma_exp) * max(shape, 0.3);
            if rating == "ab"
                if ~obj.has_afterburner
                    error('CcaProp:NoAfterburner', ...
                        'Rating "ab" requested but propulsion.has_afterburner is false.');
                end
                alpha = alpha * obj.ab_thrust_ratio;   % afterburner thrust boost
            end
        end

        function c = TSFC(obj, state, rating)
        %TSFC  [lb fuel / lb thrust / hr], one engine.
            if nargin < 3, rating = "max"; end
            M = state.mach;
            if rating == "ab" && obj.has_afterburner
                c = obj.c0_per_hr_ab * (1 + 0.10*M);
            else
                c = obj.c0_per_hr * (1 + 0.15*M);
            end
        end

        function kT = thrust_ratio(obj, state, con)
        %THRUST_RATIO  kT = T_available_this_condition / T_SL_total.
        %   Reads con.oei (logical, drop one engine), con.max_continuous
        %   (logical, same lapse model, documented separately only so a
        %   caller can distinguish the rating in logs), and
        %   con.thrust_setting (fraction of available thrust actually
        %   demanded, default 1.0 = full rating).
            oei = isfield(con,'oei') && con.oei;
            rating = "max";
            if isfield(con,'rating'), rating = con.rating; end
            thrust_setting = 1.0;
            if isfield(con,'thrust_setting'), thrust_setting = con.thrust_setting; end

            if oei && obj.n_engines < 2
                error('CcaProp:OeiSingleEngine', ...
                    ['A one-engine-inoperative condition was requested but ', ...
                     'n_engines = %d, which leaves zero thrust (required T/W would be ', ...
                     'infinite). Set "oei": false on that condition, or use n_engines >= 2.'], ...
                    obj.n_engines);
            end
            n_op = obj.n_engines - double(oei);

            alpha = obj.thrust_lapse(state, rating);
            kT = (n_op/obj.n_engines) * alpha * thrust_setting;
        end

        function [W_total, W_each] = engine_weight(obj)
            W_each = obj.T_SL_each_current() / obj.engine_TW_ratio;
            W_total = obj.n_engines * W_each;
        end

        function L = engine_length(obj)
            L = obj.engine_len_k * obj.T_SL_each_current()^0.4;
        end
    end
end


function v = getdef(s, name, default)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end
