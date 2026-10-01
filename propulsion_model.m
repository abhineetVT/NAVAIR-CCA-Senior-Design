%% Propulsion Model
% Charles Hughes

%% Inputs

% Placeholder Values
LD_cruise = 5.5; % Historical value for fighter jet cruise L/D
LD_loiter = 7.5; % Historical value for fighter jet loiter L/D
M = 0.8; % From RFP
alt = 9144; % 30,000 ft from RFP

% Obtain Atmospheric Conditions
[rho, p, T] = atmosphere(alt);
gamma = 1.4;

% Constants
R = 287;
g = 9.80665;


% Calculate cruise flight speed and dynamic pressure
vinf = velocity(M, T, gamma, R);
q = 0.5 * rho * vinf^2;


mass = 20000; % For 45000 lbs ~initial estimate
W = mass*g;

% Define propulsion type and obtain cruise-specific TSFC
turbojet_cruise = 'turbojet_cruise';
TSFC = get_TSFC(turbojet_cruise);

% Calculate thrust required for cruise and loiter
D_cruise = W / LD_cruise;
D_loiter = W / LD_loiter;
T_required = [D_cruise, D_loiter];

% Calculate fuel flow rates for cruise and loiter
TSFC_loiter = get_TSFC('turbojet_loiter');
fuelFlow = [TSFC, TSFC_loiter] .* T_required;

% Define Thrust phase lapse
alpha = get_alpha('turbojet_cruise');
TSL = T/alpha;

%% Functions

function T_WT0_installed = get_T_WT0_installed(type)
M = 0.8; %assumed
    switch lower(type)
        case "Jet Trainer", T_WT0 = 0.488*M^0.727;
        case "Jet Fighter (dogfighter)", T_WT0 = 0.648*M^0.594;
        case "Jet Fighter (other)", T_WT0 = 0.514*M^0.141;
        case "Military cargo/bomber", T_WT0 = 0.244*M^0.341;
        case "Jet Transport", T_WT0 = 0.267*M^0.363;
            otherwise
            error("Unknown Propulsion Type: %s", type)
    end
end

function alpha = get_alpha(type)
    switch lower(type)
        case "Jet Trainer",                 alpha = 0.488;
        case "Jet Fighter (dogfighter)",    alpha = 0.648;
        case "Jet Fighter (other)",         alpha = 0.514;
        case "Military cargo/bomber",       alpha = 0.244;
        case "Jet Transport",               alpha = 0.267;
            otherwise
            error("Unknown Propulsion Type: %s", type)
    end
end

function T_WT0_uninstalled = get_T_WT0_uninstalled(type)
    switch lower(type)
        case "Long Range", T_WT0_uninstalled = 0.275;
        case "Short and intermediate range with moderate field length", T_WT0_uninstalled = 0.375;
        case "STOL and utility transport", T_WT0_uninstalled = 0.5;
        case "Fighter-close air support", T_WT0_uninstalled = 0.5;
        case "Fighter-strike interdiction", T_WT0_uninstalled = 0.575;
        case "FIghter-air-to-air", T_WT0_uninstalled = 1.05;
        case "FIghter-interceptor", T_WT0_uninstalled = 0.675;
            otherwise
            error("Unknown Mission Requirement: %s", type)
    end
end

function TSFC = get_TSFC(type)
% TSFC from class table
    switch lower(type)
        case 'turbojet_cruise',                   TSFC = 0.9;
        case 'turbojet_loiter',                   TSFC = 0.8;
        case 'low_bypass_turbofan_cruise',        TSFC = 0.8;
        case 'low_bypass_turbofan_loiter',        TSFC = 0.7;
        case 'high_bypass_turbofan_cruise',       TSFC = 0.5;
        case 'high_bypass_turbofan_loiter',       TSFC = 0.4;
            otherwise
            error('Unknown propulsion type: %s', type);
    end
end

function [rho, p, T] = atmosphere(alt)
% ISA, alt in meters, valid to 20 km
    Tsl = 288.15; psl = 101325; R = 287; g = 9.80665;
    if alt <= 11000
        T = Tsl - 0.0065 * alt;
        p = psl * (T / Tsl)^5.2561;
    else
        T = 216.65;
        p = 22632 * exp(-g * (alt - 11000) / (R * T));
    end
    rho = p / (R * T);
end

function vinf = velocity(M, T, gamma, R)
    vinf = M * sqrt(gamma * R * T);
end