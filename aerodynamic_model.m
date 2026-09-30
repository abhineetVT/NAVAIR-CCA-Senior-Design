%% Preliminary Aircraft Analysis Model
%
% Model:
%   CD = CD0 + k*CL^2
%   k  = 1/(pi*e*AR)

clear; clc; close all;

%% Inputs (placeholder values)
% Geometry / Aircraft
S        = 10;        % planform area (m^2)
b        = 8;         % span (m)
Lambda   = 30;        % leading-edge sweep angle (deg)
tc       = 0.10;      % thickness-to-chord ratio
SwetSref = 3.0;       % wetted area / reference area
mass     = 2000;      % aircraft mass (kg)
W        = mass * 9.80665;  % weight (N)
cfe      = 0.0035;    % equivalent skin friction coefficient
    % (for a Jet Fighter; found in "Full Configuration Drag Estimation of 
    % Small-to-Medium Range UAVs and its impact on Initial Sizing Optimization,
    %  Gotten et all)
e        = 0.80;      % Oswald efficiency factor

% Maximum lift coefficient at zero sweep
CLmax_0  = 1.5;       % assumed unswept-wing CLmax

% Lift coefficient used for takeoff/liftoff
CL_TO_fraction = 0.90; % takeoff CL is 90% CLmax

%% Flight Conditions
M        = 0.8;       % Mach number
alt      = 9144;      % altitude (m)

%% Constants
gamma    = 1.4;
Rair     = 287.05;    % J/(kg*K)
g0       = 9.80665;   % m/s^2

%% Atmosphere
[rho, p, T, g] = atmosphere(alt, Rair, g0);

V_inf = velocity(M, T, gamma, Rair);
q_inf = 0.5 * rho * V_inf^2;

%% Geometry
AR = b^2 / S;

%% Aerodynamics
% Zero-lift drag
CD0 = zero_lift_drag(cfe, SwetSref);

% Induced drag factor
k = 1 / (pi * e * AR);

% Cruise lift coefficient
CL_cruise = W / (q_inf * S);

% Cruise drag coefficient
CD_cruise = CD0 + k * CL_cruise^2;

%% Sweep-dependent CLmax
CLmax = CLmax_0 * cosd(Lambda);

% Takeoff lift coefficient
CL_TO = CL_TO_fraction * CLmax;

%% Stall Speed
Vs = sqrt(2 * W / (rho * S * CLmax));

%% Takeoff Speed
V_takeoff = sqrt(2 * W / (rho * S * CL_TO));

%% Display Results

fprintf('\n----------------------------------------\n');
fprintf('Aircraft Aerodynamic Analysis\n');
fprintf('----------------------------------------\n');

fprintf('Aspect Ratio             = %.2f\n', AR);
fprintf('Oswald efficiency        = %.2f\n', e);
fprintf('Induced drag factor k    = %.4f\n', k);
fprintf('CD0                      = %.4f\n', CD0);

fprintf('\nFlight condition:\n');
fprintf('Altitude                 = %.0f m\n', alt);
fprintf('Mach number              = %.2f\n', M);
fprintf('Density                  = %.4f kg/m^3\n', rho);
fprintf('Cruise velocity          = %.2f m/s\n', V_inf);

fprintf('\nLift:\n');
fprintf('CL cruise                = %.4f\n', CL_cruise);
fprintf('CLmax                    = %.4f\n', CLmax);
fprintf('CL takeoff               = %.4f\n', CL_TO);

fprintf('\nSpeeds:\n');
fprintf('Stall speed              = %.2f m/s\n', Vs);
fprintf('Stall speed              = %.2f knots\n', Vs * 1.9438);

fprintf('Takeoff speed            = %.2f m/s\n', V_takeoff);
fprintf('Takeoff speed            = %.2f knots\n', V_takeoff * 1.9438);

fprintf('----------------------------------------\n');


%% SWEEP ANGLE vs TAKEOFF SPEED

Lambda_range = 0:1:60;     % sweep angle range (deg)

% Calculate CLmax for each sweep angle
CLmax_sweep = CLmax_0 .* cosd(Lambda_range);

% Corresponding takeoff CL
CLto_sweep = CL_TO_fraction .* CLmax_sweep;

% Takeoff speed
Vtakeoff_sweep = sqrt(2 * W ./ (rho * S .* CLto_sweep) );

% Stall speed
Vstall_sweep = sqrt(2 * W ./ (rho * S .* CLmax_sweep) );


%% Plot: Sweep Angle vs Takeoff Speed

figure;
plot(Lambda_range, Vtakeoff_sweep * 1.9438, 'LineWidth', 2);
grid on;
xlabel('Sweep Angle, \Lambda (deg)');
ylabel('Takeoff Speed (knots)');
title('Takeoff Speed vs Wing Sweep Angle');


%% Plot: Sweep Angle vs CLmax

figure;
plot(Lambda_range, CLmax_sweep, 'LineWidth', 2);
grid on;
xlabel('Sweep Angle, \Lambda (deg)');
ylabel('C_{L,max}');
title('Maximum Lift Coefficient vs Wing Sweep');


%% CLmax vs STALL SPEED

CLmax_range = 0.5:0.05:2.5;
Vstall_CLmax = sqrt(2 * W ./ (rho * S .* CLmax_range) );

%% Plot: CLmax vs Stall Speed
figure;
plot(CLmax_range, Vstall_CLmax * 1.9438, 'LineWidth', 2);
grid on;
xlabel('C_{L,max}');
ylabel('Stall Speed (knots)');
title('Stall Speed vs C_{L,max}');


%%  Combined Results
fprintf('\nSweep Angle Study:\n');
fprintf('----------------------------------------\n');
fprintf('Sweep (deg)    CLmax       Vstall (knots)    Vtakeoff (knots)\n');

for i = 1:length(Lambda_range)
    fprintf('%6.0f        %7.3f        %8.2f          %8.2f\n', ...
        Lambda_range(i), ...
        CLmax_sweep(i), ...
        Vstall_sweep(i) * 1.9438, ...
        Vtakeoff_sweep(i) * 1.9438);
end

%%  Functions

function [rho, p, T, g] = atmosphere(alt, Rair, g0)
% Standard atmosphere below 11 km.
%
% Inputs:
%   alt  - altitude (m)
%   Rair - specific gas constant (J/kg/K)
%   g0   - sea-level gravitational acceleration (m/s^2)
%
% Outputs:
%   rho  - density (kg/m^3)
%   p    - pressure (Pa)
%   T    - temperature (K)
%   g    - gravitational acceleration (m/s^2)

    Tsl = 288.15;              % sea-level temperature (K)
    psl = 101325;              % sea-level pressure (Pa)
    lapseRate = -6.5e-3;       % K/m
    g = g_alt(alt, g0);
    T = Tsl + lapseRate*alt;
    p = psl * (T/Tsl)^(-g/(Rair * lapseRate));
    rho = p/(Rair*T);
end


function g = g_alt(alt, g0)
% Gravitational acceleration at altitude.
    r_earth = 6.371e6; % Earth radius (m)
    g = g0 * (r_earth/(r_earth + alt))^2;
end


function vinf = velocity(M, T, gamma, R)
% Calculate freestream velocity from Mach number.
    a = sqrt(gamma * R * T);
    vinf = M * a;
end


function CD0 = zero_lift_drag(cfe, SwetSref)
% Estimate zero-lift parasite drag coefficient.
    FF = 1; % Form Factor
    CD0 = cfe * SwetSref * FF;
end
