classdef (Abstract) AerodynamicsBase < handle
%AERODYNAMICSBASE  Tier-1 abstract enforcer for all aerodynamics discipline classes.
%
%   Declares the two-method contract orchestrators call (drag_polar,
%   get_CLmax), plus fidelity-independent utilities, plus the
%   per-configuration polar accessor (get_config_polar) the field-length
%   and climb constraints read.
%
%   K-convention: CD = CD0 + K1*CL^2 + K2*CL, K1 quadratic/induced and K2
%   linear/camber.  [Mattingly, Aircraft Engine Design, 2nd ed., Eq. 2.9]
%
%   Inheritance: AerodynamicsBase -> CcaAero

    methods (Abstract)

        %DRAG_POLAR  Clean drag polar at the given flight state.
        %   Returns struct with fields CD0, K1, K2.
        polar = drag_polar(obj, state)

        %GET_CLMAX  Maximum usable lift coefficient of a named configuration.
        CLmax = get_CLmax(obj, state, con)

    end

    methods

        function cfg = get_config_polar(obj, state, con)
        %GET_CONFIG_POLAR  Drag polar + CLmax for a named configuration.
        %   Default errors; a concrete class overrides this, building on its
        %   own clean drag_polar plus its flap/gear/store increments.
            error('AerodynamicsBase:configPolarNotImplemented', ...
                ['aero (class %s) does not implement get_config_polar.'], class(obj));
        end

        function CD = compute_CD(~, CD0, K1, K2, CL)
        %COMPUTE_CD  Drag coefficient.  [Mattingly Eq. 2.9]
            CD = CD0 + K1.*CL.^2 + K2.*CL;
        end

        function CL = compute_CL(~, L, q, S_ref)
        %COMPUTE_CL  Lift coefficient in steady level flight.  [Nicolai Eq. 2.1]
            arguments
                ~
                L     (1,1) double
                q     (1,1) double {mustBePositive}
                S_ref (1,1) double {mustBePositive}
            end
            CL = L/(q*S_ref);
        end

    end
end
