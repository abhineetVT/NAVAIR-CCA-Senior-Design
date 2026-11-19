classdef CcaAero < AerodynamicsBase
%CCAAERO  Aerodynamics module: lift, drag-polar build-up for the CCA.
%
%   Reconstructs, inside this OOP framework, the same eight-stage pipeline
%   structure used for the aero_drag.m tool this project started from
%   (geometry -> CD0 -> lift -> induced -> wave/area-rule -> store
%   increment -> polar assembly -> post-processing), at the fidelity level
%   discussed for this build: a real finite-wing lift-curve-slope
%   correction instead of a flat Cfe regression, a Raymer component
%   skin-friction CD0 build-up using actual Reynolds numbers from
%   AircraftState, and the Korn/Lock transonic wave-drag relation driving
%   both the dash-feasibility check (via CcaGeom.Mdd) and the drag polar
%   itself above drag-divergence.
%
%   geom is a CcaGeom (injected); every call re-reads geom's CURRENT
%   S_ref/sweep/tail areas, so a sizing-loop re-size is picked up
%   automatically -- no stale cached geometry.
%
%   STAGE 1 -- mod_lift: 3D lift-curve slope
%       Section (2D) lift-curve slope comes from the assumed transonic
%       supercritical section's thin-airfoil value (2*pi/rad, the
%       standard inviscid flat-plate limit used for a first-pass
%       supercritical section with unknown exact camber -- see the
%       airfoil_robustness_sweep tool for how much a real NACA section's
%       CLa differs from this). That 2D slope is corrected to a 3D,
%       swept, finite-AR wing with HELMBOLD'S EQUATION [Phillips,
%       "Mechanics of Flight", Eq. 1.8.26; also Raymer 6th ed. Eq. 12.6]:
%           CLa_3D = (2*pi*AR) / ( 2 + sqrt(4 + (AR*beta/kappa)^2 *
%                     (1 + (tan(sweep_c4)/beta)^2) ) )
%       where beta = sqrt(1-M^2) (Prandtl-Glauert) and kappa = CLa_2D/(2pi)
%       is the section-efficiency factor. Helmbold's relation is the
%       standard low/moderate-AR, swept-wing generalization of the
%       classical Prandtl lifting-line result and is the right fidelity
%       level for a conceptual-design polar (full VLM circulation solve
%       is not needed to get CLa and e to engineering accuracy here).
%
%   STAGE 2 -- mod_induced: induced drag
%       CDi = CL^2 / (pi*AR*e), with Oswald efficiency e from
%       [Raymer 6th ed. Eq. 12.61, "cambered-and-twisted" straight/swept
%       wing fit]:
%           e = 4.61*(1-0.045*AR^0.68)*(cos(sweep_LE))^0.15 - 3.1   (sweep>30deg)
%           e = 1.78*(1-0.045*AR^0.68) - 0.64                        (sweep<=30deg)
%
%   STAGE 3 -- mod_cd0: Raymer component skin-friction build-up
%       Each component (wing, HT, VT panel(s), fuselage, nacelles) gets a
%       turbulent flat-plate Cf from the Schlichting correlation
%       [Raymer 6th ed. Eq. 12.27]: Cf = 0.455/(log10(Re)^2.58 *
%       (1+0.144*M^2)^0.65), a form factor FF [Raymer Eqs. 12.22-12.24],
%       and is summed as sum(Cf*FF*Q*Swet)/S_ref, Q=1.0 (no interference
%       factor assumed at this stage). A fixed miscellaneous/leakage drag
%       fraction [Raymer Sec. 12.5] is added for gear doors, antennas, gaps.
%
%   STAGE 4 -- mod_wave: Korn/Lock transonic wave drag
%       Below geom.Mdd, CDwave = 0. Above it, Lock's empirical quartic
%       [Raymer 6th ed. Eq. 12.31]: CDwave = 20*(M - Mdd)^4 for M>=Mdd (the
%       same relation geom.Mdd itself is inverted from), evaluated at the
%       CURRENT flight CL via a local Mdd(CL) re-evaluation (Mdd falls as
%       CL rises, exactly as in geom.Mdd, just swept over the polar's CL
%       range instead of only the single dash design point).
%
%   STAGE 5 -- mod_stores: internal vs external drag increment
%       "external": CDstores = n_stores*Dq_each / S_ref, a flat-plate
%       equivalent drag area per store (pylon + exposed-store interference
%       drag lumped together), ADDED FOR EVERY STORE STILL CARRIED -- see
%       n_stores_present in drag_polar's con argument, which a mission
%       segment or constraint condition can set below geom.n_stores once
%       stores have been released (releases_stores in get_miss_seg.m /
%       stores_present in get_con.m).
%       "internal": CDstores = 0 always (the bay's cost is wetted area,
%       already folded into geom.S_wet_fuselage, and OEW, in CcaWeights --
%       NOT a cruise drag increment).
%
%   STAGE 6 -- mod_polar / mod_post: assembly
%       CD(CL) = CD0 + CDi(CL) + CDwave(CL,M) + CDstores ; CL/CD, CLmax.

    properties (SetAccess = immutable)
        geom              % CcaGeom
        CLa_2D_per_rad = 2*pi   % thin-airfoil section lift-curve slope
        FF_wing  = 1.35   % form factors [Raymer 12.22], supercritical-ish t/c
        FF_tail  = 1.30
        FF_fus             % computed from fineness ratio, see below
        FF_nacelle = 1.25  % [Raymer 12.24], flow-through nacelle
        Q_interference = 1.0
        misc_drag_frac = 0.03   % leakage/protuberance allowance [Raymer 12.5-ish]
        CLmax_clean = 1.35      % swept/transonic wing, no HLDs, cruise config
        CLmax_flaps_le = 0.45   % additional CLmax from TE flaps/LE devices, if modeled
    end

    methods
        function obj = CcaAero(geom)
            arguments
                geom (1,1) CcaGeom
            end
            obj.geom = geom;
        end

        %% ---------------- 3D lift-curve slope (Helmbold) ----------------
        function CLa = lift_curve_slope(obj, state, sweep_deg, AR)
            if nargin < 3, sweep_deg = obj.geom.sweep_c4_deg; end
            if nargin < 4, AR = obj.geom.AR; end
            M = state.mach;
            beta = sqrt(max(1 - M^2, 0.05));
            kappa = obj.CLa_2D_per_rad / (2*pi);
            CLa = (2*pi*AR) / ( 2 + sqrt(4 + (AR*beta/kappa)^2 * ...
                  (1 + (tand(sweep_deg)/beta)^2) ) );
        end

        %% ---------------- Oswald efficiency [Raymer 12.61] ---------------
        function e = oswald_efficiency(obj)
            AR = obj.geom.AR;
            lambda = obj.geom.taper;
            % Invert GeometryBase.convert_sweep's LE->x-fraction relation
            % (tan(Lambda_x) = tan(Lambda_LE) - (4/AR)*x*(1-lambda)/(1+lambda))
            % to get LEADING-EDGE sweep back out of the quarter-chord sweep
            % this class stores (x=0.25):
            tan_LE = tand(obj.geom.sweep_c4_deg) + (1/AR)*(1-lambda)/(1+lambda);
            sweep_le = atand(tan_LE);
            if sweep_le > 30
                e = 4.61*(1-0.045*AR^0.68)*(cosd(sweep_le))^0.15 - 3.1;
            else
                e = 1.78*(1-0.045*AR^0.68) - 0.64;
            end
            e = min(max(e, 0.55), 0.92);  % sane clamp
        end

        %% ---------------- CD0 build-up [Raymer Ch. 12] -------------------
        function CD0 = cd0_buildup(obj, state)
            g = obj.geom;
            M = state.mach;

            schlichting_cf = @(Re) 0.455 / ( (log10(Re))^2.58 * (1+0.144*M^2)^0.65 );

            FF_fus_local = 1 + 60/(g.fineness_ratio^3) + g.fineness_ratio/400;

            Re_wing = state.atm.reynolds(g.MAC);
            Re_fus  = state.atm.reynolds(g.l_fus);
            Re_nac  = state.atm.reynolds(g.l_nacelle);

            f_wing = schlichting_cf(Re_wing) * obj.FF_wing * obj.Q_interference * g.S_wet_wing;
            f_fus  = schlichting_cf(Re_fus)  * FF_fus_local * obj.Q_interference * g.S_wet_fuselage;
            f_nac  = schlichting_cf(Re_nac)  * obj.FF_nacelle * obj.Q_interference * g.S_wet_nacelle;

            if g.tail_type == "none"
                f_tail = 0;
            else
                Re_tail_h = state.atm.reynolds(max(g.MAC*0.6, 1));
                f_tail = schlichting_cf(Re_tail_h) * obj.FF_tail * obj.Q_interference * ...
                         (g.S_wet_ht + g.S_wet_vt);
            end

            f_total = f_wing + f_fus + f_nac + f_tail;
            CD0_clean = f_total / g.S_ref;
            CD0 = CD0_clean * (1 + obj.misc_drag_frac);
        end

        %% ---------------- Wave drag [Korn/Lock, Raymer 12.30-12.31] ------
        function CDwave = wave_drag(obj, state, CL)
            g = obj.geom;
            M = state.mach;
            cl4 = cosd(g.sweep_c4_deg);
           Mdd_at_CL = g.kappaA/cl4 - g.tc_mean/cl4^2 - CL/(10*cl4^3);
           Mcr_at_CL = Mdd_at_CL - (0.1/80)^(1/3);     % add this line
           if M <= Mcr_at_CL                           % was: if M < Mdd_at_CL
              CDwave = 0;
           else
              CDwave = 20*(M - Mcr_at_CL)^4;          % was: 20*(M - Mdd_at_CL)^4
           end
        end

        %% ---------------- Store drag increment ---------------------------
        function CDstores = store_drag(obj, n_stores_present)
            g = obj.geom;
            if nargin < 2, n_stores_present = g.n_stores; end
            if g.is_internal_stores
                CDstores = 0;
            else
                CDstores = n_stores_present * g.store_Dq_each / g.S_ref;
            end
        end

        %% ---------------- Full polar [AerodynamicsBase interface] --------
        function polar = drag_polar(obj, state, con)
        %DRAG_POLAR  polar = drag_polar(obj, state, con)
        %
        %   Satisfies AerodynamicsBase's declared K-convention contract
        %   (CD = CD0 + K1*CL^2 + K2*CL [Mattingly Eq. 2.9]: polar.CD0,
        %   polar.K1 = 1/(pi*AR*e), polar.K2 = 0 -- this CCA's section has
        %   no deliberate camber-drag linear term at this fidelity level)
        %   for any caller that wants the classic closed-form constraint-
        %   equation style. Wave drag and the store-drag increment are
        %   NOT representable as a clean K1*CL^2+K2*CL term (Lock's
        %   relation is quartic in CL through Mdd(CL); store drag is a
        %   flat CL-independent increment folded into CD0 instead), so
        %   this framework's OWN constraint/mission code does not use
        %   K1/K2 at all -- it calls compute_CD_at (below) for a direct,
        %   point-evaluated CD(CL) that includes wave and store drag
        %   exactly, at whatever CL the condition actually needs. The
        %   swept CL/CD vectors and L/D-max below are for inspection/
        %   plotting the full, correctly-combined polar at one flight
        %   condition, not for the constraint equations themselves.
        %
        %   con (optional) may carry .stores_present (logical) and/or
        %   .n_stores_present (numeric) to drop store drag mid-mission
        %   after a release event; defaults to all stores still aboard.
            if nargin < 3, con = struct(); end
            g = obj.geom;

            n_present = g.n_stores;
            if isfield(con, 'n_stores_present')
                n_present = con.n_stores_present;
            elseif isfield(con, 'stores_present') && ~con.stores_present
                n_present = 0;
            end

            CL_sweep = linspace(-0.2, obj.CLmax_clean, 25);
            CLa = obj.lift_curve_slope(state);
            e   = obj.oswald_efficiency();
            CD0 = obj.cd0_buildup(state);
            CDstores = obj.store_drag(n_present);

            CDi    = CL_sweep.^2 / (pi*g.AR*e);
            CDwave = arrayfun(@(cl) obj.wave_drag(state, cl), CL_sweep);
            CD     = CD0 + CDi + CDwave + CDstores;

            polar.CL = CL_sweep;
            polar.CD = CD;
            polar.CD0 = CD0 + CDstores;   % K-convention CD0 absorbs the flat store increment
            polar.K1 = 1/(pi*g.AR*e);
            polar.K2 = 0;
            polar.CDstores = CDstores;
            polar.CDi_vector = CDi;
            polar.CDwave_vector = CDwave;
            polar.e = e;
            polar.CLa_per_rad = CLa;
            polar.LD = CL_sweep ./ CD;
            [polar.LD_max, idx] = max(polar.LD);
            polar.CL_at_LDmax = CL_sweep(idx);
            polar.Mdd_dash = g.Mdd;
            polar.dash_feasible = g.dash_feasible;
        end

        function CD = compute_CD_at(obj, state, CL, con)
        %COMPUTE_CD_AT  Point evaluation CD(CL) without building the whole
        %   swept polar -- what mission segments and constraint points
        %   actually call each time they need a drag number.
            if nargin < 4, con = struct(); end
            g = obj.geom;
            n_present = g.n_stores;
            if isfield(con, 'n_stores_present')
                n_present = con.n_stores_present;
            elseif isfield(con, 'stores_present') && ~con.stores_present
                n_present = 0;
            end
            e = obj.oswald_efficiency();
            CD0 = obj.cd0_buildup(state);
            CDi = CL^2/(pi*g.AR*e);
            CDwave = obj.wave_drag(state, CL);
            CDstores = obj.store_drag(n_present);
            CD = CD0 + CDi + CDwave + CDstores;
        end

        function CLmax = get_CLmax(obj, state, con)
        %GET_CLMAX  [AerodynamicsBase interface] con.config == "takeoff" or
        %   "landing" adds the flap/LE-device CLmax increment; "clean"
        %   (default) does not. No Mach/Re dependence modeled at this
        %   fidelity level.
            if nargin < 3 || ~isfield(con, 'config')
                config = "clean";
            else
                config = string(con.config);
            end
            if any(config == ["takeoff","landing"])
                CLmax = obj.CLmax_clean + obj.CLmax_flaps_le;
            else
                CLmax = obj.CLmax_clean;
            end
        end
    end
end
