classdef AircraftState
%AIRCRAFTSTATE  Immutable ISA atmosphere state at a given altitude and Mach.
%
%   s = AircraftState(altitude_ft, mach) builds the flight condition passed
%   into every discipline method in this framework. All outputs are English
%   units: lbf, ft, slug, ft/s, deg R.
%
%   VALUE class (not handle): properties are set once in the constructor.
%
%   Atmosphere: International Standard Atmosphere, implemented directly
%   (no toolbox dependency) to the 1976 US Standard Atmosphere troposphere
%   and lower stratosphere break points (valid to ~65,000 ft, the whole
%   envelope a carrier-based CCA needs).
%   Ratios: [Mattingly, Aircraft Engine Design, 2nd ed., Eq. 2.52]
%   Viscosity: Sutherland's law, used for Reynolds-number skin-friction
%   calculations in the aerodynamics model.

    properties (Constant, Access = private)
        T_STD_R   = 518.67;    % deg R  -- standard sea-level static temperature
        P_STD_PSF = 2116.22;   % lbf/ft^2 -- standard sea-level static pressure
        RHO_STD   = 0.0023769; % slug/ft^3 -- standard sea-level density
        R_AIR     = 1716.49;   % ft*lbf/(slug*R) -- specific gas constant, air
        GAMMA     = 1.4;       % -- ratio of specific heats, air
    end

    properties (SetAccess = private)
        altitude_ft (1,1) double   % ft        -- geometric pressure altitude (input)
        mach        (1,1) double   % --        -- flight Mach number (input)
        T_atm       (1,1) double   % deg R     -- static temperature
        P_atm       (1,1) double   % lbf/ft^2  -- static pressure
        rho         (1,1) double   % slug/ft^3 -- air density
        sigma       (1,1) double   % --        -- density ratio rho/rho_sealevel
        a           (1,1) double   % ft/s      -- speed of sound
        V           (1,1) double   % ft/s      -- true airspeed (= mach * a)
        q           (1,1) double   % lbf/ft^2  -- dynamic pressure (= 0.5*rho*V^2)
        mu          (1,1) double   % slug/(ft*s) -- dynamic viscosity, Sutherland's law
        theta       (1,1) double   % --        -- T_atm / T_std   [Mattingly Eq. 2.52a]
        delta       (1,1) double   % --        -- P_atm / P_std   [Mattingly Eq. 2.52b]
    end

    methods
        function obj = AircraftState(altitude_ft, mach)
            arguments
                altitude_ft (1,1) double {mustBeNonnegative}
                mach        (1,1) double {mustBeNonnegative}
            end

            obj.altitude_ft = altitude_ft;
            obj.mach        = mach;

            % --- 1976 US Standard Atmosphere, troposphere + lower stratosphere ---
            h  = altitude_ft;
            T0 = AircraftState.T_STD_R;
            P0 = AircraftState.P_STD_PSF;
            g0 = 32.17405;      % ft/s^2
            R  = AircraftState.R_AIR;
            L  = 0.0035662;     % deg R / ft, tropospheric lapse rate (= 6.5 K/km)

            h_tropo = 36089;    % ft, troposphere -> isothermal layer break
            h_strat = 65617;    % ft, isothermal -> second lapse layer break

            if h <= h_tropo
                T = T0 - L*h;
                P = P0 * (T/T0)^(g0/(R*L));
            elseif h <= h_strat
                T_11 = T0 - L*h_tropo;
                P_11 = P0 * (T_11/T0)^(g0/(R*L));
                T = T_11;
                P = P_11 * exp(-g0*(h - h_tropo)/(R*T_11));
            else
                T_11  = T0 - L*h_tropo;
                P_11  = P0 * (T_11/T0)^(g0/(R*L));
                P_20  = P_11 * exp(-g0*(h_strat - h_tropo)/(R*T_11));
                L2    = -0.00054864; % deg R/ft above 65,617 ft (-3.0 K/km of ascent, i.e. warming)
                T     = T_11 - L2*(h - h_strat);
                P     = P_20 * (T/T_11)^(g0/(R*L2));
            end

            obj.T_atm = T;
            obj.P_atm = P;
            obj.rho   = P/(R*T);
            obj.sigma = obj.rho/AircraftState.RHO_STD;
            obj.a     = sqrt(AircraftState.GAMMA*R*T);
            obj.V     = mach*obj.a;
            obj.q     = 0.5*obj.rho*obj.V^2;

            % Sutherland's law, English units: mu0 at T0=518.67 R is
            % 3.7373e-7 slug/(ft*s), Sutherland constant S=198.72 R.
            mu0 = 3.7373e-7; S = 198.72;
            obj.mu = mu0 * (T/T0)^1.5 * (T0 + S)/(T + S);

            obj.theta = obj.T_atm / T0;
            obj.delta = obj.P_atm / P0;
        end

        function Re = reynolds(obj, length_ft)
        %REYNOLDS  Reynolds number over a reference length [-].
            arguments
                obj
                length_ft (1,1) double {mustBePositive}
            end
            Re = obj.rho * obj.V * length_ft / obj.mu;
        end
    end
end
