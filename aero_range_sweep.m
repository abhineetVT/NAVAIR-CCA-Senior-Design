%% Aero effect on combat radius: random aero configurations + comparator aircraft
% Built on drag_estimator.m (its functions are copied at the bottom).
% Radius = eta * 0.5 * Breguet range. eta is calibrated so the model matches your
% TSFC and weight ratio are held constant. Cruise Mach and altitude are design choices, so they
% vary per aircraft / configuration (they change both speed and wave drag).
clear; clc; close all; rng(1);

%% Common assumptions (agree these with the propulsion team)
M0    = 0.75;      % reference cruise Mach (only used for the dashed reference line)
alt0  = 10500;     % reference cruise altitude [m]
tsfc  = 0.8;       % [1/hr] held constant
WiWf  = 1.30;      % ideal cruise weight ratio (calibration absorbs the rest)
fmid  = 0.85;      % cruise mass = fmid * MTOW (sets cruise CL)
nCfg  = 25;        % number of random aero configurations

gamma = 1.4;  R = 287;  g = 9.80665;
CL = linspace(0, 1.2, 200);

%% Comparator aircraft (SI).  [P] published, [E] estimate
%        name        S[m^2]  b[m]   Lambda  tc    SwetSref  ac_type          MTOW[kg]  M     alt[m]
ac = {  'X-47B',     88.59,  18.92, 55,     0.10, 2.3,      'cca',        20185,    0.75, 10500;
        'MQ-25A',    58,     22.86, 30,     0.12, 4.0,      'cca', 21000,    0.60, 9000;
        'YFQ-44A',   9.0,    5.2,   35,     0.07, 4.0,      'cca',    2268,     0.80, 10000;
        'Vectis',    33,     11.6,  50,     0.08, 2.5,      'cca',           7500,     0.80, 10000 };
% REPLACE with your documented radii [nm]; leave NaN where none (NaN = not used).
% Prefilled: X-47B 1500 nm combat radius w/ 4,500 lb (GlobalSecurity), MQ-25 500 nm w/ 16,000 lb offload.
R_pub_nm = [1500; 500; 700; 1000];   % column, one per aircraft above
n = size(ac, 1);

%% 1. Comparators (each at its own cruise Mach / altitude)
cmp = zeros(n, 7);    % AR, e, CD0, LDmax, CLcr, LDcr, V
for i = 1:n
    cmp(i,:) = aero_case(ac{i,2}, ac{i,3}, ac{i,4}, ac{i,5}, ac{i,6}, ac{i,7}, fmid*ac{i,8}, ac{i,9}, ac{i,10}, CL);
end
ideal = 0.5 * breguet_range(cmp(:,7), tsfc, cmp(:,6), WiWf) / 1852;   % ideal out-and-back radius [nm]

%% 2. Calibration to published radii
have = ~isnan(R_pub_nm);
if any(have)
    eta = exp(mean(log(R_pub_nm(have) ./ ideal(have))));       % geometric mean
else
    eta = 1;  warning('No published radii given; radius is the ideal Breguet value.');
end
fprintf('Calibration factor eta = %.2f (mission radius / ideal Breguet radius)\n', eta);

%% 3. Random aero configurations
types  = {'cca'};
AR_r   = 1.5 + 6 * rand(nCfg,1);            % aspect ratio 1.5-9
Lam_r  = 20 + 40 * rand(nCfg,1);          % LE sweep 20-60 deg
tc_r   = 0.07 + 0.05 * rand(nCfg,1);      % t/c 0.07-0.12
Sw_r   = 2.2 + 2.0 * rand(nCfg,1);        % Swet/Sref 2.2-4.2
WS_r   = 220 + 160 * rand(nCfg,1);        % MTOW/S 220-380 kg/m^2 (comparators: 227-362)
type_r = types(randi(numel(types), nCfg, 1));
M_r    = 0.60 + 0.35 * rand(nCfg,1);      % cruise Mach 0.60-0.95
alt_r  = 9000 + 3000 * rand(nCfg,1);      % cruise altitude 9-12 km
mass_r = 10000;                           % arbitrary; only W/S matters for L/D
rnd = zeros(nCfg, 7);
for k = 1:nCfg
    S_k = mass_r / WS_r(k);
    b_k = sqrt(AR_r(k) * S_k);
    rnd(k,:) = aero_case(S_k, b_k, Lam_r(k), tc_r(k), Sw_r(k), type_r{k}, fmid*mass_r, M_r(k), alt_r(k), CL);
end
rad_r = eta * 0.5 * breguet_range(rnd(:,7), tsfc, rnd(:,6), WiWf) / 1852;
rad_c = eta * ideal;                      % comparators on the calibrated model

%% Output
fprintf('\nTSFC %.2f /hr, Wi/Wf %.2f (held constant)\n\n', tsfc, WiWf);
fprintf('%-8s %5s %5s %5s %7s %7s %6s %9s %9s %7s\n', 'Aircraft', 'M', 'AR', 'e', 'CD0', 'L/Dcr', ...
    'CLcr', 'Model[nm]', 'Publ.[nm]', 'Ratio');
for i = 1:n
    fprintf('%-8s %5.2f %5.2f %5.3f %7.4f %7.2f %6.3f %9.0f %9.0f %7.2f\n', ac{i,1}, ac{i,9}, cmp(i,1), cmp(i,2), ...
        cmp(i,3), cmp(i,6), cmp(i,5), rad_c(i), R_pub_nm(i), R_pub_nm(i)/rad_c(i));
end
fprintf('\nRandom configurations\n%4s %5s %5s %6s %6s %-14s %6s %5s %5s %6s %8s %9s\n', '#', 'AR', 'LE', 't/c', ...
    'Sw/Sr', 'type', 'W/S', 'M', 'alt', 'e', 'L/Dcr', 'Radius[nm]');
for k = 1:nCfg
    fprintf('%4d %5.1f %5.0f %6.3f %6.2f %-14s %6.0f %5.2f %5.0f %6.3f %8.2f %9.0f\n', k, AR_r(k), Lam_r(k), tc_r(k), ...
        Sw_r(k), type_r{k}, WS_r(k), M_r(k), alt_r(k), rnd(k,2), rnd(k,6), rad_r(k));
end

%% Table of all configurations (CSV file + MATLAB table in the workspace)
hdr  = {'Name','Type','AR','LE_sweep_deg','tc','SwetSref','Cfe','CD0','WS_kg_m2','Mach','Alt_m', ...
        'e','CL_cruise','LD_cruise','LD_max','Radius_model_nm','Radius_published_nm'};
rows = cell(n + nCfg, numel(hdr));
for i = 1:n          % comparators
    rows(i,:) = {ac{i,1}, ac{i,7}, cmp(i,1), ac{i,4}, ac{i,5}, ac{i,6}, get_cfe(ac{i,7}), cmp(i,3), ...
                 ac{i,8}/ac{i,2}, ac{i,9}, ac{i,10}, cmp(i,2), cmp(i,5), cmp(i,6), cmp(i,4), rad_c(i), R_pub_nm(i)};
end
for k = 1:nCfg       % random configurations
    rows(n+k,:) = {sprintf('Cfg %d', k), type_r{k}, rnd(k,1), Lam_r(k), tc_r(k), Sw_r(k), get_cfe(type_r{k}), ...
                   rnd(k,3), WS_r(k), M_r(k), alt_r(k), rnd(k,2), rnd(k,5), rnd(k,6), rnd(k,4), rad_r(k), NaN};
end
fid = fopen('aero_configs.csv', 'w');
fprintf(fid, '%s\n', strjoin(hdr, ','));
for r = 1:size(rows, 1)
    fprintf(fid, '%s,%s,%.2f,%.1f,%.3f,%.2f,%.4f,%.4f,%.0f,%.2f,%.0f,%.3f,%.3f,%.2f,%.2f,%.0f,%.0f\n', rows{r,:});
end
fclose(fid);
fprintf('\nWrote aero_configs.csv (%d rows)\n', size(rows, 1));
if exist('cell2table') > 0                       % MATLAB: also show it as a table
    cfgTable = cell2table(rows, 'VariableNames', hdr);
    disp(cfgTable);
end

%% Plots
figure('Position', [100 100 1400 600]); set(gcf, 'PaperPositionMode', 'auto');
subplot(1,2,1); hold on;
LDline = linspace(0.9 * min([rnd(:,6); cmp(:,6)]), 1.05 * max([rnd(:,6); cmp(:,6)]), 50);
[~, ~, T0] = atmosphere(alt0);  V0 = velocity(M0, T0, gamma, R);
plot(LDline, eta * 0.5 * breguet_range(V0, tsfc, LDline, WiWf) / 1852, 'k--');   % reference: M 0.75, 10.5 km
plot(rnd(:,6), rad_r, 'o', 'Color', [0.5 0.5 0.5], 'MarkerFaceColor', [0.8 0.8 0.8], 'MarkerSize', 7);
for i = 1:n
    plot(cmp(i,6), rad_c(i), 's', 'MarkerSize', 9, 'LineWidth', 1.5);
    text(cmp(i,6) + 0.3, rad_c(i), ac{i,1});
end
xlabel('Cruise L/D'); ylabel('Combat radius [nm]'); grid on;
title('Radius vs cruise L/D');

subplot(1,2,2); hold on;
plot(rnd(:,3), rad_r, 'o', 'Color', [0.5 0.5 0.5], 'MarkerFaceColor', [0.8 0.8 0.8], 'MarkerSize', 7);
for i = 1:n
    plot(cmp(i,3), rad_c(i), 's', 'MarkerSize', 9, 'LineWidth', 1.5);
    text(cmp(i,3) + 0.0003, rad_c(i), ac{i,1});
end
xlabel('C_{D0}'); ylabel('Combat radius [nm]'); grid on; title('Radius vs CD0');

%% Functions
function out = aero_case(S, b, Lambda, tc, SwetSref, ac_type, mass, M, alt, CL)
% One configuration through the drag_estimator.m model at its own Mach / altitude.
% Returns [AR, e, CD0, L/Dmax, CL_cruise, L/D_cruise, V].
    g = 9.80665;  gamma = 1.4;  R = 287;
    [rho, ~, T] = atmosphere(alt);
    V = velocity(M, T, gamma, R);
    q = 0.5 * rho * V^2;
    AR  = b^2 / S;
    cfe = get_cfe(ac_type);
    CD0 = zero_lift_drag(cfe, SwetSref);
    e   = span_eff(AR, Lambda, M);
    K   = 1 / (pi * AR * e);
    CD  = CD0 + K * CL.^2 + wave_drag(M, Lambda, tc, CL);
    LDmax = max(CL ./ CD);
    CL_cruise = mass * g / (q * S);
    CD_cruise = CD0 + K * CL_cruise^2 + wave_drag(M, Lambda, tc, CL_cruise);
    out = [AR, e, CD0, LDmax, CL_cruise, CL_cruise / CD_cruise, V];
end

function R = breguet_range(V, tsfc, LD, WiWf)
% Jet Breguet range [m]. V [m/s], tsfc [1/hr]
    R = (V ./ (tsfc / 3600)) .* LD .* log(WiWf);
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

function e = span_eff(AR, Lambda, M)
% Raymer regression (replaces the Nicolai/Brandt form, which returned e > 1 and
% rose with Mach). M is kept in the signature so calls don't change; it is not used.
    f    = 1 - 0.045 * AR^0.68;
    e_st = 1.78 * f - 0.64;                          % straight wing
    e_sw = 4.61 * f * cosd(Lambda)^0.15 - 3.1;       % swept, Lambda >= 30 deg
    e    = e_st + (e_sw - e_st) * min(Lambda / 30, 1);
    e    = min(max(e, 0.5), 0.95);
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