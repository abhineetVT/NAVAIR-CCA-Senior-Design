function pass = sizing_pass(geom, aero, prop, weights, W_TO, conditions, missions, WS_vec, enforce_spot)
%SIZING_PASS  One fixed-point iteration of the TOGW closure.
%
%   1. Constraint analysis at the CURRENT W_TO guess gives the (W/S, T/W)
%      design point (run_constraints.m, MAX-of-lower-bounds envelope).
%   2. Wing area is resized to hit that W/S at the current W_TO, and the
%      engine is rescaled (prop.thrust_scale) to hit that T/W -- both are
%      the mutable Dependent-property-driving state on CcaGeom/CcaProp,
%      so every OTHER Dependent property (spans, wetted areas, Mdd,
%      engine weight/length...) updates automatically on the next read.
%   3. The carrier spot-factor hard gate is checked (spot_factor_check.m)
%      -- this STOPS the pass, it is not folded into the W_TO update.
%   4. Mission analysis (run_mission.m) at the now-resized aircraft gives
%      the fuel burned (and exercises the store-release drag/weight
%      switch mid-mission).
%   5. Weights closes W_TO_new = OEW(W_TO) + payload + W_fuel_total.
%
%   The caller (sizing_mainloop.m) under-relaxes W_TO <- W_TO + ...
%   between calls; this function does not iterate itself.

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        weights (1,1) CcaWeights
        W_TO (1,1) double {mustBePositive}
        conditions (1,:) struct
        missions (1,:) struct
        WS_vec (1,:) double {mustBePositive} = linspace(40, 140, 100)
        enforce_spot (1,1) logical = true
    end

    env = run_constraints(geom, aero, prop, conditions, WS_vec, false);

    if ~isfinite(env.TW_design) || env.TW_design <= 0
        bad = env.names(~cellfun(@(c) all(isfinite(c)), env.TW_curves));
        error('sizing_pass:BadDesignPoint', ...
            ['Constraint analysis produced a non-finite T/W design point (%g). ', ...
             'Constraint curves with non-finite values: %s'], ...
            env.TW_design, strjoin(bad, ', '));
    end

    if prop.engine_mode == "fixed"
        % REAL ENGINE: thrust is whatever n_engines x T_SL_each gives. Pick
        % the LARGEST wing loading (smallest wing) at which the constraint
        % envelope is still met by that thrust, capped by the landing limit.
        prop.thrust_scale = 1.0;
        TW_avail = prop.T_SL / W_TO;
        WSv = env.WS_vec;  TWe = env.TW_envelope;
        ok = (WSv <= env.WS_max_landing) & (TWe <= TW_avail);
        if any(ok)
            TW_cap = interp1(WSv, TWe, env.WS_max_landing, 'linear', 'extrap');
            if TW_cap <= TW_avail
                WS_design = env.WS_max_landing;      % landing-limited, thrust to spare
            else
                idx = find(ok, 1, 'last');           % thrust-limited: find the crossing
                WS_design = WSv(idx);
                if idx < numel(WSv) && WSv(idx+1) <= env.WS_max_landing && TWe(idx+1) > TWe(idx)
                    WS_design = WSv(idx) + (TW_avail - TWe(idx))/(TWe(idx+1) - TWe(idx))*(WSv(idx+1) - WSv(idx));
                end
            end
            engine_ok = true;
        else
            feas = find(WSv <= env.WS_max_landing);
            [~, j] = min(TWe(feas));
            WS_design = WSv(feas(j));                % best effort; flagged below
            engine_ok = false;
        end
        T_SL_required = interp1(WSv, TWe, WS_design, 'linear', 'extrap') * W_TO;
    else
        WS_design = env.WS_design;
        T_SL_required = env.TW_design * W_TO;
        prop.thrust_scale = T_SL_required / (prop.n_engines * prop.T_SL_each);
        engine_ok = true;
    end
    geom.S_ref = W_TO / WS_design;

    % Hard error on violation. sizing_mainloop passes enforce_spot = false
    % for its intermediate iterates (a far-off W_TO guess sizes a
    % transiently huge wing that says nothing about the final design) and
    % enforces the gate on the CONVERGED design instead.
    if enforce_spot
        spot_factor_check(geom);
    end

    if ~geom.dash_feasible
        warning('sizing_pass:DashNotFeasible', ...
            ['Current sweep/t-c/kappaA gives Mdd = %.3f, short of the dash ', ...
             'requirement (Mach %.2f + %.3f margin) by %.3f. Increase sweep ', ...
             '(see CcaGeom.required_sweep_deg) or raise kappaA.'], ...
            geom.Mdd, geom.dash_mach, geom.dash_margin_required, ...
            geom.dash_margin_required - geom.dash_margin_actual);
    end

    miss = run_mission(geom, aero, prop, weights, W_TO, missions);

    OEW_val = weights.OEW(W_TO);
    W_payload = weights.payload();
    W_burned = miss.W_fuel_total;
    W_loaded = weights.fuel_loaded(W_burned);     % burned + reserve
    W_TO_new = OEW_val + W_payload + W_loaded;

    pass.W_TO = W_TO;
    pass.W_TO_new = W_TO_new;
    pass.OEW = OEW_val;
    pass.W_payload = W_payload;
    pass.W_fuel_total = W_loaded;
    pass.W_fuel_burned = W_burned;
    pass.W_fuel_reserve = W_loaded - W_burned;
    pass.radius_nm = miss.radius_nm;
    pass.fuel_capacity_lb = geom.fuel_capacity_lb;
    pass.fuel_ok = W_loaded <= geom.fuel_capacity_lb;
    pass.env = env;
    pass.mission = miss;
    pass.S_ref = geom.S_ref;
    pass.b = geom.b;
    pass.spot_factor = geom.spot_factor;
    pass.T_SL = prop.T_SL;
    pass.T_SL_required = T_SL_required;
    pass.engine_ok = engine_ok;
    pass.WS_design = WS_design;
    pass.dash_feasible = geom.dash_feasible;
end
