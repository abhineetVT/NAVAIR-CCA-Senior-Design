%% GOBBLEWORKS_OEW.m -- OEW(W_TO) for the CCA, your design parameters, one graph.
clear; close all; clc;

%% ---- design parameters ----
d.WS_TO = 100; d.AR = 4.0; d.taper = 0.25; d.sweep_c4 = 35;      % geometry
d.tc_root = 0.10; d.Sct_frac = 0.14; d.Sht_ratio = 0.18; d.Svt_ratio = 0.14;
d.Nvt = 2; d.Lt = 18; d.L_fus = 46; d.D_fus = 6.0; d.W_fus = 8.5;
d.k_fus_wet = 0.80; d.bay_door_ft2 = 60; d.L_mlg_in = 60; d.L_nlg_in = 55;
d.N_gear_limit = 5.0; d.L_duct = 20; d.K_duct = 2.5;

d.Nz_limit = 5.0; d.FoS = 1.5;                                   % loads

d.T_max_SL = 22000; d.W_dry = 2445; d.D_ft = 2.92; d.L_ft = 12.9; % F414-GE-400
d.sfc_max = 1.6;                                                 % 1/hr @ SL static, max power

d.W_avionics = 1000; d.W_autonomy = 300; d.Rkva = 120;           % systems
d.N_fc_sys = 4; d.N_hyd_func = 12; d.N_tanks = 4; d.protected_frac = 0.5;
d.growth = 0.10;

d.f_wing = 0.85; d.f_tail = 0.83; d.f_fus = 0.90; d.f_gear = 0.95; d.f_inlet = 0.85;
d.k_bay_fus = 1.08; d.door_lb_ft2 = 4.0; d.RAM_lb_ft2 = 0.15;
d.k_carrier_fus = 1.07; d.k_carrier_gear = 1.20; d.wing_fold_frac = 0.05;
d.W_hook = 350; d.n_hardpoints = 4; d.W_hardpoint = 60;

W_energy = 9923;              % lb  mission fuel (fixed estimate, from the sizing model)
W_payload = 2000;             % lb  internal stores -- [TEAM] 2k cap
W_TO_target = 45000;          % lb  [TEAM] planned target TOGW

%% ---- sweep W_TO and plot ----
W_TO_vec = linspace(20000, 50000, 80);
OEW_vec  = arrayfun(@(w) oew(d, w, W_energy), W_TO_vec);
req_vec  = W_TO_vec - W_energy - W_payload;    % closure: W_TO = OEW + energy + payload

idx = find(diff(sign(OEW_vec - req_vec)) ~= 0, 1);
W_TO_solved = interp1(OEW_vec(idx:idx+1)-req_vec(idx:idx+1), W_TO_vec(idx:idx+1), 0);
OEW_solved  = oew(d, W_TO_solved, W_energy);
fprintf('Closure: W_TO = %.0f lb, OEW = %.0f lb  (planned target: %.0f lb)\n', W_TO_solved, OEW_solved, W_TO_target);

figure; hold on; grid on;
plot(W_TO_vec/1000, OEW_vec/1000, 'b-', 'LineWidth', 2);
plot(W_TO_vec/1000, req_vec/1000, 'r--', 'LineWidth', 2);
plot(W_TO_solved/1000, OEW_solved/1000, 'kp', 'MarkerSize', 16, 'MarkerFaceColor', 'y');
yl = ylim;
plot([1 1]*W_TO_target/1000, yl, 'k:', 'LineWidth', 1.8);
xlabel('Candidate W_{TO} (1000 lb)'); ylabel('OEW (1000 lb)');
legend('OEW(W_{TO})', 'Required: W_{TO} - energy - payload', 'Closure point', '45k target', 'Location', 'northwest');
title(sprintf('GobbleWorks CCA: closes at %.0f lb TOGW, %.0f lb OEW (target %.0f lb)', W_TO_solved, OEW_solved, W_TO_target));
saveas(gcf, 'oew_vs_wto.png');

%% ---- OEW function ----
function OEW = oew(d, W_TO, W_fuel)
    Sw = W_TO / d.WS_TO; b = sqrt(d.AR*Sw); cr = 2*Sw/(b*(1+d.taper));
    Scsw = d.Sct_frac*Sw; Sht = d.Sht_ratio*Sw; Svt = d.Svt_ratio*Sw/d.Nvt;
    Swet = d.k_fus_wet*pi*0.5*(d.D_fus+d.W_fus)*d.L_fus + 2.04*(Sw-min(cr*d.W_fus,0.6*Sw)) + 2.04*(Sht+d.Nvt*Svt);

    Nz = d.Nz_limit*d.FoS;
    Wdg = W_TO - 0.5*W_fuel;             % mid-mission weight [approx]
    Wl  = W_TO - 0.75*W_fuel;            % landing weight [approx]
    Nl  = 1.5*d.N_gear_limit;

    W_wing = 0.0103*(Wdg*Nz)^0.5*Sw^0.622*d.AR^0.785*d.tc_root^-0.4*(1+d.taper)^0.05/cosd(d.sweep_c4)*Scsw^0.04*d.f_wing;
    W_ht   = 3.316*(1+0.5*d.W_fus/sqrt(3.5*Sht))^-2*(Wdg*Nz/1000)^0.260*Sht^0.806*d.f_tail;
    W_vt   = d.Nvt*0.452*(Wdg*Nz)^0.488*Svt^0.718*0.90^0.341/d.Lt*1.25^0.348*1.3^0.223*1.4^0.25/cosd(40)^0.323*d.f_tail;
    W_fus  = 0.499*Wdg^0.35*Nz^0.25*d.L_fus^0.5*d.D_fus^0.849*d.W_fus^0.685*d.f_fus;
    W_lg   = ((Wl*Nl)^0.25*d.L_mlg_in^0.973 + (Wl*Nl)^0.290*d.L_nlg_in^0.5*2^0.525)*d.f_gear;

    Te = d.T_max_SL;
    W_eng_install = 0.013*Te^0.579*Nz + 1.13*pi*d.D_ft*0.5*d.L_ft + 0.01*d.W_dry^0.717*Nz ...
                  + 3.5*d.D_ft*8 + 4.55*d.D_ft*d.L_ft + 37.82 + 10.5*20^0.222 + 0.025*Te^0.760;
    W_inlet = 13.29*d.L_duct^0.643*d.K_duct^0.182*d.D_ft*d.f_inlet;
    Vt = W_fuel/6.8; Vp = d.protected_frac*Vt;
    W_fs = 7.45*Vt^0.47*2^-0.095*(1+Vp/Vt)*d.N_tanks^0.066*(Te*d.sfc_max/1000)^0.249;

    Scs = Scsw + 0.3*Sht + 0.25*Svt*d.Nvt;
    W_flt_ctrl = 36.28*0.90^0.003*Scs^0.489*d.N_fc_sys^0.484;
    W_instr    = 8.0 + 36.37*d.N_tanks^0.237;
    W_hyd      = 37.23*d.N_hyd_func^0.664;
    W_elec     = 172.2*1.45*d.Rkva^0.152*40^0.10*2^0.091;
    W_av       = d.W_avionics + d.W_autonomy;
    W_ecs      = 201.6*(W_av/1000)^0.735;

    structure  = W_wing + W_ht + W_vt + W_fus + W_lg + d.n_hardpoints*d.W_hardpoint;
    stealth    = W_fus*(d.k_bay_fus-1) + d.bay_door_ft2*d.door_lb_ft2 + d.RAM_lb_ft2*Swet;
    carrier    = d.wing_fold_frac*W_wing + W_fus*d.k_bay_fus*(d.k_carrier_fus-1) + W_lg*(d.k_carrier_gear-1) + d.W_hook;
    propulsion = d.W_dry + W_eng_install + W_inlet + W_fs;
    systems    = W_flt_ctrl + W_instr + W_hyd + W_elec + W_av + W_ecs + 3.2e-4*W_TO;

    raw = structure + stealth + carrier + propulsion + systems;
    OEW = raw * (1 + d.growth);
end