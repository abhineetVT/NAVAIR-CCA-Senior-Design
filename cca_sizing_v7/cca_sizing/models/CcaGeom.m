classdef CcaGeom < GeometryBase
%CCAGEOM  Carrier Collaborative Combat Aircraft geometry model.
%
%   Parametric planform + fuselage + nacelle + stores geometry for a
%   tailless-to-conventional, single- or twin-engine, carrier-based CCA,
%   written in the same "one mutable state, everything else Dependent"
%   style as the TTPA reference framework: S_ref is the ONLY property the
%   sizing loop writes, and every span, chord, tail area, wetted area and
%   derived check (spot factor, dash-Mach drag-divergence margin) is a
%   Dependent property recomputed from it on every read.
%
%   INJECTED PROPULSION
%   CcaGeom(json_path, prop) -- the nacelle count and length follow the
%   engine, which is propulsion data, exactly as in the reference TtpaGeom.
%
%   TAIL CONFIGURATIONS (J.geometry.tail_type)
%     "conventional"    separate horizontal + vertical tail, volume-
%                       coefficient sized [Raymer Eqs. 6.28-6.29]
%     "t_tail"          same area method; HT moved clear of the VT wake,
%                       carries a small weight/interference penalty only
%                       (captured in CcaWeights, not here)
%     "v_tail"          two canted ruddervator panels replacing both HT and
%                       VT. Combined area from a single tail-volume
%                       relation [Raymer Eq. 6.30-ish practice: size for the
%                       LARGER of the two conventional-equivalent volume
%                       requirements, then split into two panels], cant
%                       angle from J.geometry.v_tail.cant_deg.
%     "twin_vertical"   conventional horizontal tail, TWO vertical fins
%                       (each half the conventional single-fin area, at
%                       +/- butt-line offset) -- common on a twin-engine,
%                       low-RCS carrier-based layout (splits the fin RCS
%                       return and allows toe-in for yaw-stability tuning).
%     "none"            tailless / flying-wing. Zero tail area; pitch and
%                       yaw control assumed to come from wing-trailing-edge
%                       elevons and drag-rudders/split ailerons. This class
%                       does not model control-surface SIZING for that
%                       case (a stability & control problem out of this
%                       aero/weights/mission scope) -- it only zeroes the
%                       tail's area, weight and wetted-area contributions.
%
%   STORES: INTERNAL VS EXTERNAL (J.geometry.stores.configuration)
%   This is the trade the whole framework is built to expose:
%     "internal"   stores sit in a weapons bay carved out of the fuselage.
%                  Zero store drag area in cruise (CcaAero never adds a
%                  store Dq for this configuration); the bay itself costs
%                  fuselage wetted area (bay doors/lips) and OEW (bay
%                  structure), both read by CcaWeights/CcaAero from the
%                  bay dimensions here.
%     "external"   stores hang on pylons. Zero bay-structure weight, but
%                  CcaAero adds each store's drag area (J...Dq_each) as an
%                  aero_drag.m "store" item, and CcaWeights adds a pylon
%                  weight per store. This is the configuration whose drag
%                  penalty the mission analysis can switch off mid-mission
%                  when a segment marks releases_stores = true.
%
%   SPOT FACTOR -- HARD CONSTRAINT
%   The carrier-deck "spot factor" this framework enforces is the simple
%   geometric ratio the RFP defines it as:
%       spot_factor = (b_effective * L_fuselage) / spot_reference_area
%   where b_effective is the span with wings folded (b * fold_fraction,
%   fold_fraction = 1 if J.geometry.folding.fold_fraction is not given, i.e.
%   no fold credit). spot_factor_max (0.80 per the requirement) is read
%   from J.geometry.spot_factor_max. spot_factor_ok is a Dependent logical;
%   sizing_pass.m stops with an error, not a silent re-size, when it reads
%   false -- see spot_factor_check.m.
%
%   DASH-SPEED SWEEP SIZING (Korn/Lock drag-divergence equation)
%   The assumed transonic supercritical section is characterised ONLY by
%   its Korn technology factor kappaA (0.95 is typical for a modern
%   supercritical section; 0.87 for a conventional one -- see CcaAero) and
%   its t/c. Given those, [Raymer 6th ed. Eq. 12.30, rearranged]
%       Mdd = kappaA/cos(Lambda_c4) - (t/c)/cos(Lambda_c4)^2
%             - CL / (10 cos(Lambda_c4)^3)
%   relates drag-divergence Mach to quarter-chord sweep. CcaGeom.Mdd is a
%   Dependent property evaluating this at the CURRENT sweep/t-c/kappaA and
%   a representative cruise CL; CcaGeom.required_sweep_deg (static) inverts
%   it by bisection, so a sizing study can ask "what sweep do I need for
%   Mdd >= dash_mach + margin" directly, instead of hand-iterating sweep.

    properties
        S_ref = NaN
        % Wing reference area [ft^2]. THE sizing-loop state.
    end

    properties (SetAccess = immutable)
        prop                     % injected CcaProp, for the nacelle

        % --- wing shape ---
        AR
        taper
        sweep_c4_deg             % quarter-chord sweep actually flown
        tc_root
        tc_tip
        kappaA                   % Korn technology factor of the assumed
                                  % transonic supercritical section
        twist_deg
        incidence_deg
        dihedral_deg
        dash_mach
        dash_CL
        dash_margin_required     % Mdd must exceed dash_mach by at least this

        % --- tail ---
        tail_type string
        V_ht, L_ht, AR_ht, taper_ht, tc_ht, sweep_c4_ht_deg
        V_vt, L_vt, AR_vt, taper_vt, tc_vt, sweep_c4_vt_deg
        vtail_cant_deg
        twin_vt_toe_deg

        % --- fuselage, fixed ---
        w_fus, h_fus, l_nose, l_cabin, l_cone, w_cone_end, h_cone_end

        % --- nacelle ---
        d_nacelle
        k_nacelle_length

        % --- landing gear ---
        l_n_over_l_d
        l_m_over_l_d

        % --- stores ---
        store_config string      % "internal" | "external"
        n_stores
        store_Dq_each             % ft^2, external only
        bay_L, bay_W, bay_D       % ft, internal only (bay envelope)

        % --- carrier spot factor ---
        spot_factor_max
        fold_fraction             % effective-span multiplier, folded
        spot_reference_area       % ft^2, reference deck footprint the factor is normalized to

        % --- fuel tankage (ASSUMPTIONS -- set in geometry.fuel) ---
        fuel_density_lb_ft3       % JP-8 ~ 50.1 lb/ft^3 (6.7 lb/gal)
        wing_tank_fraction        % fraction of the wing-box estimate usable for fuel
        fuselage_tank_fraction    % fraction of net fuselage volume usable for fuel
    end

    properties (Dependent)
        b, c_root, c_tip, MAC, y_MAC, tc_mean, S_exposed_wing
        S_ht, S_vt_total, n_vtail_panels
        l_fus, fineness_ratio, S_wet_fuselage
        l_engine, l_nacelle, S_wet_nacelle
        S_wet_wing, S_wet_ht, S_wet_vt, S_wet, S_wet_over_S_ref
        Mdd, dash_margin_actual, dash_feasible
        b_effective, spot_factor, spot_factor_ok
        bay_volume, is_internal_stores
        V_wing_ft3, V_fus_ft3, fuel_volume_ft3, fuel_capacity_lb
    end

    methods

        %% Constructor
        function obj = CcaGeom(json_path, prop)
            arguments
                json_path {mustBeTextScalar, mustBeNonzeroLengthText}
                prop (1,1) PropulsionBase_Jet
            end

            obj.prop = prop;
            J = jsondecode(fileread(json_path));
            G = J.geometry;

            obj.AR            = G.AR;
            obj.taper         = G.taper_ratio;
            obj.sweep_c4_deg  = G.sweep_c4_deg;
            obj.tc_root       = G.thickness_ratio_root;
            obj.tc_tip        = G.thickness_ratio_tip;
            obj.kappaA        = G.kappaA;
            obj.twist_deg     = G.twist_deg;
            obj.incidence_deg = G.incidence_deg;
            obj.dihedral_deg  = G.dihedral_deg;
            obj.dash_mach     = G.dash_mach;
            obj.dash_CL       = G.dash_CL;
            obj.dash_margin_required = G.dash_margin_required;

            obj.tail_type = string(G.tail_type);

            if isfield(G, 'horizontal_tail')
                H = G.horizontal_tail;
                obj.V_ht = H.volume_coefficient; obj.L_ht = H.arm_ft;
                obj.AR_ht = H.AR; obj.taper_ht = H.taper_ratio;
                obj.tc_ht = H.thickness_ratio; obj.sweep_c4_ht_deg = H.sweep_c4_deg;
            end
            if isfield(G, 'vertical_tail')
                V = G.vertical_tail;
                obj.V_vt = V.volume_coefficient; obj.L_vt = V.arm_ft;
                obj.AR_vt = V.AR; obj.taper_vt = V.taper_ratio;
                obj.tc_vt = V.thickness_ratio; obj.sweep_c4_vt_deg = V.sweep_c4_deg;
            end
            if isfield(G, 'v_tail')
                obj.vtail_cant_deg = G.v_tail.cant_deg;
            end
            if isfield(G, 'twin_vertical')
                obj.twin_vt_toe_deg = G.twin_vertical.toe_deg;
            end

            F = G.fuselage;
            obj.w_fus = F.width_ft; obj.h_fus = F.height_ft;
            obj.l_nose = F.nose_length_ft; obj.l_cabin = F.constant_length_ft;
            obj.l_cone = F.tailcone_length_ft;
            obj.w_cone_end = F.tailcone_end_width_ft;
            obj.h_cone_end = F.tailcone_end_height_ft;

            N = G.nacelle;
            obj.d_nacelle = N.diameter_ft;
            obj.k_nacelle_length = N.length_over_engine_length;

            L = G.landing_gear;
            obj.l_n_over_l_d = L.l_n_over_l_d;
            obj.l_m_over_l_d = L.l_m_over_l_d;

            S = G.stores;
            obj.store_config = string(S.configuration);
            obj.n_stores = S.n_stores;
            obj.store_Dq_each = getdef(S, 'Dq_each_ft2', 0);
            obj.bay_L = getdef(S, 'bay_length_ft', 0);
            obj.bay_W = getdef(S, 'bay_width_ft', 0);
            obj.bay_D = getdef(S, 'bay_depth_ft', 0);

            obj.spot_factor_max = G.spot_factor_max;
            obj.fold_fraction   = getdef(G, 'fold_fraction', 1.0);
            obj.spot_reference_area = G.spot_reference_area_ft2;

            if isfield(G, 'fuel'), FU = G.fuel; else, FU = struct(); end
            obj.fuel_density_lb_ft3    = getdef(FU, 'density_lb_per_ft3', 50.1);
            obj.wing_tank_fraction     = getdef(FU, 'wing_tank_fraction', 0.7);
            obj.fuselage_tank_fraction = getdef(FU, 'fuselage_tank_fraction', 0.2);
        end


        %% ---------------- Abstract interface ----------------
        function val = get_S_ref(obj), val = obj.S_ref; end
        function val = get_S_wet(obj), val = obj.S_wet;  end


        %% ---------------- Wing planform ----------------
        function val = get.b(obj)
            val = GeometryBase.compute_span(obj.AR, obj.S_ref);
        end
        function val = get.c_root(obj)
            val = GeometryBase.compute_root_chord(obj.S_ref, obj.b, obj.taper);
        end
        function val = get.c_tip(obj)
            val = GeometryBase.compute_tip_chord(obj.c_root, obj.taper);
        end
        function val = get.MAC(obj)
            val = GeometryBase.compute_mac(obj.c_root, obj.taper);
        end
        function val = get.y_MAC(obj)
            val = GeometryBase.compute_y_mac(obj.b, obj.taper);
        end
        function val = get.tc_mean(obj)
            val = 0.5*(obj.tc_root + obj.tc_tip);
        end
        function val = get.S_exposed_wing(obj)
            S_covered = GeometryBase.planform_buried_in_fuselage(obj.c_root, obj.taper, obj.w_fus, obj.b);
            val = obj.S_ref - S_covered;
        end


        %% ---------------- Tail, by configuration ----------------
        function val = get.S_ht(obj)
        %GET.S_HT  Horizontal-tail-EQUIVALENT area [ft^2].
        %   "conventional"/"t_tail": volume-coefficient method [Raymer 6.29].
        %   "v_tail": half of the combined ruddervator area (see S_vt_total).
        %   "twin_vertical": a conventional HT is still carried.
        %   "none": zero.
            switch obj.tail_type
                case {"conventional","t_tail","twin_vertical"}
                    val = obj.V_ht * obj.S_ref * obj.MAC / obj.L_ht;
                case "v_tail"
                    val = 0.5 * obj.combined_vtail_area();
                case "none"
                    val = 0;
                otherwise
                    error('CcaGeom:UnknownTailType', 'Unknown tail_type "%s".', obj.tail_type);
            end
        end

        function val = get.S_vt_total(obj)
        %GET.S_VT_TOTAL  TOTAL vertical-tail-EQUIVALENT area [ft^2], summed
        %   over however many fin panels this tail_type has (one for
        %   conventional/t_tail, two for twin_vertical, two canted panels
        %   for v_tail which carry BOTH roles).
            switch obj.tail_type
                case {"conventional","t_tail"}
                    val = obj.V_vt * obj.S_ref * obj.b / obj.L_vt;
                case "twin_vertical"
                    % Each fin is sized smaller than a single-fin airplane
                    % would need (twin fins are more effective per unit
                    % area at the same arm because of endplating / reduced
                    % fuselage blanking), captured with a 0.85 efficiency
                    % factor on the two-fin total relative to a single fin
                    % sized to the same volume coefficient -- a standard
                    % conceptual-design approximation, not a citation.
                    val = 0.85 * obj.V_vt * obj.S_ref * obj.b / obj.L_vt;
                case "v_tail"
                    val = 0.5 * obj.combined_vtail_area();
                case "none"
                    val = 0;
                otherwise
                    error('CcaGeom:UnknownTailType', 'Unknown tail_type "%s".', obj.tail_type);
            end
        end

        function n = get.n_vtail_panels(obj)
            switch obj.tail_type
                case {"conventional","t_tail"}, n = 1;
                case "twin_vertical", n = 2;
                case "v_tail", n = 2;
                case "none", n = 0;
            end
        end

        function Sv = combined_vtail_area(obj)
        %COMBINED_VTAIL_AREA  Total ruddervator area for a V-tail [ft^2].
        %   Sized to satisfy BOTH the pitch (horizontal-tail-equivalent)
        %   and yaw (vertical-tail-equivalent) volume requirements
        %   simultaneously: each panel's area projects cos(cant) of itself
        %   into the horizontal plane and sin(cant) into the vertical
        %   plane, so the panel area needed for each role is the
        %   conventional area divided by that projection, and the DESIGN
        %   driver is whichever role demands the larger total panel area.
            S_ht_needed_as_vtail = (obj.V_ht*obj.S_ref*obj.MAC/obj.L_ht) / cosd(obj.vtail_cant_deg);
            S_vt_needed_as_vtail = (obj.V_vt*obj.S_ref*obj.b/obj.L_vt)   / sind(obj.vtail_cant_deg);
            Sv = max(S_ht_needed_as_vtail, S_vt_needed_as_vtail);
        end


        %% ---------------- Fuselage, fixed ----------------
        function val = get.l_fus(obj)
            val = obj.l_nose + obj.l_cabin + obj.l_cone;
        end
        function val = get.fineness_ratio(obj)
            val = obj.l_fus / max(obj.w_fus, obj.h_fus);
        end
        function val = get.S_wet_fuselage(obj)
        %GET.S_WET_FUSELAGE  Fuselage wetted area [ft^2].  [Raymer Eq. 7.13]
        %   A small, fixed addition is made for internal-bay doors/lips
        %   (extra wetted perimeter where the bay breaks the smooth OML),
        %   proportional to the bay's plan-view perimeter; zero for the
        %   external-carriage configuration, which cuts no bay.
            A_top = 0.5*obj.w_fus*obj.l_nose + obj.w_fus*obj.l_cabin ...
                  + 0.5*(obj.w_fus + obj.w_cone_end)*obj.l_cone;
            A_side = 0.5*obj.h_fus*obj.l_nose + obj.h_fus*obj.l_cabin ...
                   + 0.5*(obj.h_fus + obj.h_cone_end)*obj.l_cone;
            S_smooth = 3.4 * (A_top + A_side) / 2;

            if obj.is_internal_stores
                S_bay_doors = 0.10 * 2*(obj.bay_L + obj.bay_W);   % door-seam wetted-area penalty
            else
                S_bay_doors = 0;
            end
            val = S_smooth + S_bay_doors;
        end


        %% ---------------- Nacelles ----------------
        function val = get.l_engine(obj)
            val = obj.prop.engine_length();
        end
        function val = get.l_nacelle(obj)
            val = obj.k_nacelle_length * obj.l_engine;
        end
        function val = get.S_wet_nacelle(obj)
            val = obj.prop.n_engines * pi * obj.d_nacelle * obj.l_nacelle;
        end


        %% ---------------- Wetted areas ----------------
        function val = get.S_wet_wing(obj)
            val = GeometryBase.wetted_from_exposed(obj.S_exposed_wing, obj.tc_mean);
        end
        function val = get.S_wet_ht(obj)
        %GET.S_WET_HT  For "v_tail", the two ruddervator panels' wetted
        %   area is booked ENTIRELY under S_wet_vt (below) -- S_ht and
        %   S_vt_total for a v_tail are two role-projections of the SAME
        %   physical panels (see combined_vtail_area), so computing a
        %   separate wetted area from each and summing would double-count
        %   the physical surface. This getter returns 0 for that case.
            switch obj.tail_type
                case {"none","v_tail"}
                    val = 0;
                otherwise
                    val = GeometryBase.wetted_from_exposed(obj.S_ht, obj.tc_ht);
            end
        end
        function val = get.S_wet_vt(obj)
            switch obj.tail_type
                case "none"
                    val = 0;
                case "v_tail"
                    val = GeometryBase.wetted_from_exposed(obj.combined_vtail_area(), obj.tc_vt);
                otherwise
                    val = obj.n_vtail_panels * GeometryBase.wetted_from_exposed( ...
                        obj.S_vt_total/obj.n_vtail_panels, obj.tc_vt);
            end
        end
        function val = get.S_wet(obj)
            val = obj.S_wet_wing + obj.S_wet_ht + obj.S_wet_vt ...
                + obj.S_wet_fuselage + obj.S_wet_nacelle;
        end
        function val = get.S_wet_over_S_ref(obj)
            val = obj.S_wet / obj.S_ref;
        end


        %% ---------------- Dash-Mach sweep sizing (Korn/Lock) ----------------
        function val = get.Mdd(obj)
        %GET.MDD  Drag-divergence Mach of the CURRENT sweep/t-c/kappaA, at
        %   the design dash lift coefficient.  [Raymer 6th ed. Eq. 12.30]
            cl = cosd(obj.sweep_c4_deg);
            val = obj.kappaA/cl - obj.tc_mean/cl^2 - obj.dash_CL/(10*cl^3);
        end
        function val = get.dash_margin_actual(obj)
            val = obj.Mdd - obj.dash_mach;
        end
        function val = get.dash_feasible(obj)
            val = obj.dash_margin_actual >= obj.dash_margin_required;
        end


        %% ---------------- Carrier spot factor (HARD CONSTRAINT) ----------------
        function val = get.b_effective(obj)
            val = obj.b * obj.fold_fraction;
        end
        function val = get.spot_factor(obj)
            % footprint = folded span x overall length, normalized by the
            % reference footprint in the requirements JSON
            val = obj.b_effective * obj.l_fus / obj.spot_reference_area;
        end
        function val = get.spot_factor_ok(obj)
            val = obj.spot_factor <= obj.spot_factor_max;
        end


        %% ---------------- Stores ----------------
        function val = get.is_internal_stores(obj)
            val = (obj.store_config == "internal");
        end
        function val = get.bay_volume(obj)
            val = obj.bay_L * obj.bay_W * obj.bay_D;
        end

        %% ---------------- Fuel volume (conceptual estimate) ----------------
        function val = get.V_wing_ft3(obj)
            % Raymer wing-tank estimate (gross wing-box volume, ft^3):
            %   V = 0.54 (S_exp^2/b) (t/c)_root (1 + lam*sqrt(tau) + lam^2*tau)/(1+lam)^2
            lam = obj.taper;  tau = obj.tc_tip/obj.tc_root;
            val = 0.54 * obj.S_exposed_wing^2/obj.b * obj.tc_root * ...
                  (1 + lam*sqrt(tau) + lam^2*tau)/(1 + lam)^2;
        end
        function val = get.V_fus_ft3(obj)
            % Elliptical-section fuselage: cone nose + constant section +
            % frustum tailcone, minus the internal weapons bay if present.
            A0 = pi/4*obj.w_fus*obj.h_fus;
            A1 = pi/4*obj.w_cone_end*obj.h_cone_end;
            val = A0*obj.l_nose/3 + A0*obj.l_cabin ...
                + obj.l_cone/3*(A0 + A1 + sqrt(A0*A1));
            if obj.is_internal_stores
                val = val - obj.bay_volume;
            end
            val = max(val, 0);
        end
        function val = get.fuel_volume_ft3(obj)
            val = obj.wing_tank_fraction*obj.V_wing_ft3 ...
                + obj.fuselage_tank_fraction*obj.V_fus_ft3;
        end
        function val = get.fuel_capacity_lb(obj)
            val = obj.fuel_volume_ft3 * obj.fuel_density_lb_ft3;
        end

    end


    methods (Static)

        function sweep_deg = required_sweep_deg(M_dash, margin, kappaA, tc, CL)
        %REQUIRED_SWEEP_DEG  Quarter-chord sweep [deg] needed so that
        %   Mdd(sweep) >= M_dash + margin, by bisection on the Korn/Lock
        %   relation [Raymer Eq. 12.30]. Errors if even 70 deg of sweep
        %   (a practical upper bound for a tactical-aircraft wing) is not
        %   enough -- that is a real design result (pick a higher-kappaA
        %   section, accept a thicker wave-drag penalty, or lower the dash
        %   requirement), not a bug to iterate past.
            arguments
                M_dash (1,1) double {mustBePositive}
                margin (1,1) double {mustBeNonnegative}
                kappaA (1,1) double {mustBePositive}
                tc     (1,1) double {mustBePositive}
                CL     (1,1) double {mustBeNonnegative}
            end
            Mdd_needed = M_dash + margin;
            f = @(sweep_deg) kappaA/cosd(sweep_deg) - tc/cosd(sweep_deg)^2 ...
                - CL/(10*cosd(sweep_deg)^3) - Mdd_needed;

            lo = 0; hi = 70;
            if f(hi) < 0
                error('CcaGeom:SweepInfeasible', ...
                    ['No leading-edge sweep up to 70 deg gives Mdd >= %.3f with ', ...
                     'kappaA = %.3f and t/c = %.3f. Raise kappaA (a more modern ', ...
                     'supercritical section), reduce t/c, or lower the dash ', ...
                     'requirement.'], Mdd_needed, kappaA, tc);
            end
            if f(lo) >= 0
                sweep_deg = 0; return;
            end
            for iter = 1:60
                mid = 0.5*(lo+hi);
                if f(mid) < 0, lo = mid; else, hi = mid; end
            end
            sweep_deg = 0.5*(lo+hi);
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
