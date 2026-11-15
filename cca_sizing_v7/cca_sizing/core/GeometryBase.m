classdef (Abstract) GeometryBase < handle
%GEOMETRYBASE  Tier-1 abstract enforcer for all geometry discipline classes.
%
%   Declares the contract orchestrators call, plus the fidelity-independent
%   planform identities every concrete geometry level shares.
%
%   Inheritance: GeometryBase -> CcaGeom

    properties (Abstract)
        S_ref   % ft^2 -- wing reference area
        S_wet   % ft^2 -- total aircraft wetted area
    end

    methods (Abstract)
        val = get_S_ref(obj)
        val = get_S_wet(obj)
    end

    methods (Static)

        function c_root = compute_root_chord(S_ref, b, lambda)
        %COMPUTE_ROOT_CHORD  Root chord [ft].  [Raymer 7th ed. Eq. 7.6]
            arguments
                S_ref  (1,1) double {mustBePositive}
                b      (1,1) double {mustBePositive}
                lambda (1,1) double {mustBeNonnegative}
            end
            c_root = 2*S_ref/(b*(1 + lambda));
        end

        function c_tip = compute_tip_chord(c_root, lambda)
        %COMPUTE_TIP_CHORD  Tip chord [ft].  [Raymer 7th ed. Eq. 7.7]
            arguments
                c_root (1,1) double {mustBePositive}
                lambda (1,1) double {mustBeNonnegative}
            end
            c_tip = lambda*c_root;
        end

        function cbar = compute_mac(c_root, lambda)
        %COMPUTE_MAC  Mean aerodynamic chord [ft].  [Raymer 7th ed. Eq. 7.8]
            arguments
                c_root (1,1) double {mustBePositive}
                lambda (1,1) double {mustBeNonnegative}
            end
            cbar = (2/3)*c_root*(1 + lambda + lambda^2)/(1 + lambda);
        end

        function b = compute_span(AR, S_ref)
        %COMPUTE_SPAN  Span [ft] from aspect ratio and reference area.
        %   Definitional (AR = b^2/S_ref).
            arguments
                AR    (1,1) double {mustBePositive}
                S_ref (1,1) double {mustBePositive}
            end
            b = sqrt(AR*S_ref);
        end

        function y = compute_y_mac(b, lambda)
        %COMPUTE_Y_MAC  Spanwise station of the MAC [ft].
        %       y_mac = b (1 + 2 lambda) / ( 6 (1 + lambda) )
            arguments
                b      (1,1) double {mustBePositive}
                lambda (1,1) double {mustBeNonnegative}
            end
            y = b*(1 + 2*lambda)/(6*(1 + lambda));
        end

        function Lambda_x_deg = convert_sweep(Lambda_LE_deg, AR, lambda, x)
        %CONVERT_SWEEP  LE sweep -> sweep at chord fraction x [deg], MIRRORED
        %   surfaces (wing, conventional HT).
            arguments
                Lambda_LE_deg (1,1) double {mustBeGreaterThanOrEqual(Lambda_LE_deg,-90), mustBeLessThanOrEqual(Lambda_LE_deg,90)}
                AR            (1,1) double {mustBePositive}
                lambda        (1,1) double {mustBeNonnegative}
                x             (1,1) double {mustBeGreaterThanOrEqual(x,0), mustBeLessThanOrEqual(x,1)}
            end
            tan_Lambda_x = tand(Lambda_LE_deg) - (4/AR)*x*(1 - lambda)/(1 + lambda);
            Lambda_x_deg = atand(tan_Lambda_x);
        end

        function Lambda_x_deg = convert_sweep_panel(Lambda_LE_deg, AR, lambda, x)
        %CONVERT_SWEEP_PANEL  LE sweep -> sweep at chord fraction x [deg],
        %   SINGLE-PANEL surfaces (a vertical fin, one half of a V-tail).
            arguments
                Lambda_LE_deg (1,1) double {mustBeGreaterThanOrEqual(Lambda_LE_deg,-90), mustBeLessThanOrEqual(Lambda_LE_deg,90)}
                AR            (1,1) double {mustBePositive}
                lambda        (1,1) double {mustBeNonnegative}
                x             (1,1) double {mustBeGreaterThanOrEqual(x,0), mustBeLessThanOrEqual(x,1)}
            end
            tan_Lambda_x = tand(Lambda_LE_deg) - (2/AR)*x*(1 - lambda)/(1 + lambda);
            Lambda_x_deg = atand(tan_Lambda_x);
        end

        function S_wet = wetted_from_exposed(S_exposed, tc)
        %WETTED_FROM_EXPOSED  Wetted area of a lifting surface [ft^2].
        %       [Raymer Eq. 7.11]  t/c < 0.05 :  S_wet = 2.003 S_exposed
        %       [Raymer Eq. 7.12]  t/c > 0.05 :  S_wet = S_exposed*(1.977+0.52 t/c)
            arguments
                S_exposed (1,1) double
                tc        (1,1) double {mustBeNonnegative}
            end
            if tc < 0.05
                S_wet = 2.003*S_exposed;
            else
                S_wet = S_exposed*(1.977 + 0.52*tc);
            end
        end

        function S_covered = planform_buried_in_fuselage(c_root, taper, w_fus, b)
        %PLANFORM_BURIED_IN_FUSELAGE  Wing planform inside the fuselage [ft^2].
        %   Exact for a straight-tapered trapezoidal wing carried to the
        %   centreline, integrating chord from the centreline out to the
        %   fuselage side on both sides:
        %       S_covered = c_root * w_fus * (1 - (1-lambda) w_fus/(2 b))
            arguments
                c_root (1,1) double {mustBePositive}
                taper  (1,1) double {mustBeNonnegative}
                w_fus  (1,1) double {mustBeNonnegative}
                b      (1,1) double {mustBePositive}
            end
            S_covered = c_root*w_fus*(1 - (1 - taper)*w_fus/(2*b));
        end

    end
end
