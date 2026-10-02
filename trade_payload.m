%% THW3 trade study: strike payload requirement
% Lukas Sonnleitner, Avionics & Controls Lead, Team 11
% Needs sizeTOGW.m and unitCostDAPCA.m in the same folder.
clear; clc; close all;

%% Requirements (RFP)
% RFP 3.5.2
R = 500; % nm, combat radius threshold
R_des = 700; % nm, combat radius desired
R_dash = 50; % nm, sea level dash each way
M_dash = 0.8; % sea level dash Mach
% RFP 3.3.2
E = 10/60; % hr, loiter before landing
% RFP 3.4.2
W_av = 1000; % lb, avionics and sensors
% RFP 4(j)
Q = 500; % aircraft produced

%% Class values (W2L1)
% Placeholder segment values from W2L1 until the team builds its own mission table.
f_TO = 0.97; % warmup and takeoff
f_CL = 0.985; % climb
f_LA = 0.995; % landing
RFF = 0.05; % reserve fuel
TFF = 0.01; % trapped fuel
K_LD = 14; % military jet
c_cr = 0.8; % 1/hr, cruise and dash TSFC
c_lt = 0.7; % 1/hr, loiter TSFC

% Empty weight fit, Raymer 5th ed. Table 3.1, jet fighter
A = 2.34;
C = -0.13;

%% Assumptions (will change once the CAD model is finished)
AR = 4; % aspect ratio
SwetSref = 4; % wetted area / reference area
M_cr = 0.75; % cruise Mach at 30,000 ft
k_inst = 1.225; % installed electronics: 7.5% cooling (NASA/TM-2017-219627 Eq. 114) + 15% wiring (assumed)

%% Aerodynamics and speeds (W2L1)
LDmax = K_LD*sqrt(AR/SwetSref);
LD_cr = 0.866*LDmax; % cruise
LD_lt = LDmax; % loiter
LD_da = 0.5*LDmax; % sea level dash, assumed
V_cr = M_cr*994.8*0.5925; % kt, speed of sound 994.8 ft/s at 30,000 ft
V_da = M_dash*1116.4*0.5925; % kt, speed of sound 1116.4 ft/s at sea level

%% Fuel fraction (Breguet range and endurance)
dash = exp(-R_dash*c_cr/(V_da*LD_da));
loiter = exp(-E*c_lt/LD_lt);

cruise = exp(-(R - R_dash)*c_cr/(V_cr*LD_cr)); % 500 nm mission
WfW = (1 + RFF + TFF)*(1 - f_TO*f_CL*cruise^2*dash^2*loiter*f_LA);

cruise7 = exp(-(R_des - R_dash)*c_cr/(V_cr*LD_cr)); % 700 nm mission
WfW7 = (1 + RFF + TFF)*(1 - f_TO*f_CL*cruise7^2*dash^2*loiter*f_LA);

%% Payloads (lb, manufacturer spec sheets)
W_GBU = 204; % GBU-53/B
W_BRU = 330; % BRU-61/A rack
W_jam = 220; % ALQ-214 class jammer
W_MALD = 300; % MALD-J

P_thr = k_inst*W_av + W_BRU + 4*W_GBU; % threshold: RFP strike load
P_des = P_thr + k_inst*W_jam + 2*W_MALD; % desired: strike + EW kit
P_swp = k_inst*(W_av + W_jam) + 2*W_MALD; % EW kit instead of the bombs

%% Unit cost (DAPCA IV) [AOE module A6, slides 13-15]
%Used AI to determined best-use of the equations found in the slides, as
%this specific material has not been covered in class but was necessary for
%to include a quantitative cost trade-study

%Assumed values until propulsion model is finalized, and engine selected.
TW = 0.6; % thrust to weight
T_R = 3000; % deg R, turbine inlet temperature
QD = 4; % flight test aircraft, assumed equal to the MQ-25 development contract (four aircraft)
cost = @(W0, W_elec) unitCostDAPCA(A*W0^C*W0, TW*W0, M_dash, T_R, W_elec, V_da, Q, QD);

%% Results
W_thr = sizeTOGW(P_thr, WfW, A, C);
W_des = sizeTOGW(P_des, WfW, A, C);
W_swp = sizeTOGW(P_swp, WfW, A, C);
W_700 = sizeTOGW(P_thr, WfW7, A, C);

C_thr = cost(W_thr, W_av);
C_des = cost(W_des, W_av + W_jam); % jammer bought for every aircraft

%Used AI to determine best way of expressing important values
fprintf('Threshold: P = %.0f lb, W0 = %.0f lb, cost = $%.1fM\n', P_thr, W_thr, C_thr);
fprintf('Desired: P = %.0f lb, W0 = %.0f lb, cost = $%.1fM\n', P_des, W_des, C_des);
fprintf('Change: W0 %+.1f%%, cost %+.1f%%\n', 100*(W_des/W_thr - 1), 100*(C_des/C_thr - 1));
fprintf('EW kit instead of bombs: P = %.0f lb, W0 = %.0f lb\n', P_swp, W_swp);

%% Sensitivity
slope = (W_des - W_thr)/(P_des - P_thr); % lb TOGW per lb payload, threshold to desired
e_P = (W_des/W_thr - 1)/(P_des/P_thr - 1); % payload elasticity
e_R = (W_700/W_thr - 1)/(R_des/R - 1); % radius elasticity

fprintf('Slope: %.1f lb per lb\n', slope);
fprintf('Elasticity: payload %.2f, radius %.2f\n', e_P, e_R);
fprintf('500 to 700 nm: W0 %+.1f%%\n', 100*(W_700/W_thr - 1));

%% Payload sweep
P = 1000:100:4500;
for i = 1:length(P)
    W0(i) = sizeTOGW(P(i), WfW, A, C);
    UC(i) = cost(W0(i), W_av);
end

%% Plot
% Used AI to help with plot formatting.
figure('Position', [100 100 1100 420]);

subplot(1, 2, 1); hold on; grid on; box on;
plot(P, W0, 'k-', 'LineWidth', 1.5, 'HandleVisibility', 'off');
plot(P_thr, W_thr, 'ks', 'MarkerSize', 11, 'MarkerFaceColor', [.6 .6 .6], 'DisplayName', 'Baseline');
plot(P_thr, W_thr, 'p', 'MarkerSize', 16, 'Color', [0 .5 0], 'MarkerFaceColor', [.2 .8 .2], 'DisplayName', 'Recommended');
plot(P_swp, W_swp, 'd', 'MarkerSize', 8, 'Color', [0 0 .7], 'MarkerFaceColor', [.4 .6 1], 'DisplayName', 'EW kit instead of bombs');
yl = ylim;
plot([P_thr P_thr], yl, 'b--', 'LineWidth', 1.2, 'DisplayName', 'RFP threshold');
plot([P_des P_des], yl, 'r-.', 'LineWidth', 1.2, 'DisplayName', 'Desired (+ EW)');
plot(P_des, W_des, 'o', 'MarkerSize', 7, 'Color', [.7 0 0], 'MarkerFaceColor', [1 .5 .5], 'HandleVisibility', 'off');
ylim(yl);
xlabel('Strike payload: stores + installed mission systems (lb)');
ylabel('Takeoff gross weight (lb)');
title(sprintf('TOGW at 500 nm: threshold to desired %+.0f%%', 100*(W_des/W_thr - 1)));
legend('Location', 'northwest', 'FontSize', 8);

subplot(1, 2, 2); hold on; grid on; box on;
plot(P, UC, 'k-', 'LineWidth', 1.5);
plot(P_thr, C_thr, 'ks', 'MarkerSize', 11, 'MarkerFaceColor', [.6 .6 .6]);
plot(P_thr, C_thr, 'p', 'MarkerSize', 16, 'Color', [0 .5 0], 'MarkerFaceColor', [.2 .8 .2]);
yl = ylim;
plot([P_thr P_thr], yl, 'b--', 'LineWidth', 1.2);
plot([P_des P_des], yl, 'r-.', 'LineWidth', 1.2);
plot(P_des, C_des, 'o', 'MarkerSize', 7, 'Color', [.7 0 0], 'MarkerFaceColor', [1 .5 .5]);
ylim(yl);
xlabel('Strike payload: stores + installed mission systems (lb)');
ylabel('Unit cost, $M (FY2024)');
title(sprintf('Unit cost (MoM-06): threshold to desired %+.0f%%', 100*(C_des/C_thr - 1)));

print('-dpng', '-r150', 'fig_payload_trade_lsonnleitner.png');