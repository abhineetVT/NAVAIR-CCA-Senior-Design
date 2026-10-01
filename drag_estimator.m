%% Preliminary drag polar
clear; clc; close all;

%% Inputs
S        = 10;        % planform area
b        = 8;         % span 
Lambda   = 30;        % leading-edge sweep angle
tc       = 0.10;      % thickness-to-chord ratio
SwetSref = 3.0;       % wetted area / reference area (~2.1-2.5 blended/flying wing, 3.5-4.5 fighter-like)
ac_type  = 'cca';     
mass     = 2000;      % takeoff/cruise mass, estimated

M        = 0.7;       % Mach number
alt      = 8000;      % altitude

gamma = 1.4;
R     = 287;         
g     = 9.80665;     
CL = linspace(0, 1.2, 200);   % CL sweep for the polar

% 1. geometry
AR = b^2 / S;

% 2. atmosphere and flight conditions
[rho, p, T] = atmosphere(alt);
V = velocity(M, T, gamma, R);
q = 0.5 * rho * V^2;
CL_cruise = mass * g / (q * S);     

% 3. zero-lift drag from historical data 
cfe = get_cfe(ac_type);
CD0 = zero_lift_drag(cfe, SwetSref);

% 4. induced drag
e = span_eff(AR, Lambda, M);
K = 1 / (pi * AR * e);

% 5. wave drag 
CDw = wave_drag(M, Lambda, tc, CL);

% 6. assemble
CD = CD0 + K * CL.^2 + CDw;
LD = CL ./ CD;

[LDmax, i] = max(LD);
CD_cruise  = CD0 + K * CL_cruise^2 + wave_drag(M, Lambda, tc, CL_cruise);

%% Output
fprintf('AR = %.2f | e = %.3f | K = %.4f\n', AR, e, K);
fprintf('Cfe = %.4f | CD0 = %.4f\n', cfe, CD0);
fprintf('q = %.0f Pa | V = %.1f m/s | rho = %.4f kg/m^3\n', q, V, rho);
fprintf('(L/D)max = %.2f at CL = %.2f\n', LDmax, CL(i));
fprintf('Cruise CL = %.3f, CD = %.4f, L/D = %.2f\n', CL_cruise, CD_cruise, CL_cruise/CD_cruise);
if CL_cruise > CL(end)
    warning('Cruise CL is beyond the plotted CL range.');
end

figure;
subplot(1,2,1);
plot(CD, CL, 'LineWidth', 1.5); hold on;
plot(CD_cruise, CL_cruise, 'ro', 'MarkerFaceColor', 'r');
xlabel('C_D'); ylabel('C_L'); title('Drag polar'); grid on;
legend('Polar', 'Cruise point', 'Location', 'best');

subplot(1,2,2);
plot(CL, LD, 'LineWidth', 1.5);
xlabel('C_L'); ylabel('L/D'); title('Lift-to-drag'); grid on;

%% Functions
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

function e = span_eff(AR, Lambda, M)
% Nicolai/Brandt fit. Lambda in deg (use max-thickness-line sweep if you have it).
% Rough for low AR / high sweep, so the result is clamped.
    term = max(1 + tand(Lambda)^2 - M^2, 0);
    e = 2 / (2 - AR + sqrt(4 + AR^2 * term));
    e = min(max(e, 0.4), 1.0);
end

function cfe = get_cfe(type)
% Equivalent skin friction coefficient from historical data (Raymer-style values)
    switch lower(type)
        case 'bomber',              cfe = 0.0030;
        case 'jet_transport',       cfe = 0.0026;
        case 'military_cargo',      cfe = 0.0035;
        case 'af_fighter',          cfe = 0.0035;
        case 'navy_fighter',        cfe = 0.0040;
        case 'supersonic_cruise',   cfe = 0.0025;
        case 'light_twin',          cfe = 0.0045;
        case 'light_single',        cfe = 0.0055;
        case 'sailplane',           cfe = 0.0030;
        case 'cca',                 cfe = 0.0033;   % assumption: clean fighter-like UAV, low-observable finish
        otherwise
            error('Unknown aircraft type "%s".', type);
    end
end

function cd0 = zero_lift_drag(cfe, SwetSref)
    cd0 = cfe * SwetSref;
end

function cdw = wave_drag(M, Lambda, tc, CL)
% Korn equation + Lock wave drag (kappa = 0.87 conventional, 0.95 supercritical)
    kappa = 0.87;
    Mdd   = kappa / cosd(Lambda) - tc / cosd(Lambda)^2 - CL / (10 * cosd(Lambda)^3);
    Mcrit = Mdd - (0.1 / 80)^(1/3);
    cdw   = 20 * max(M - Mcrit, 0).^4;
end