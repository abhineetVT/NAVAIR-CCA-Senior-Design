%% THW3 trade study: strike payload requirement
% Lukas Sonnleitner, Avionics & Controls Lead, Team 11
% Equation numbers match the report: (1)-(6) in Section 2, (A1)-(A10) in the Appendix.
% Needs sizeTOGW.m and unitCostDAPCA.m in the same folder. Prints every number used in the report.
clear; clc; close all;

%% Requirements (RFP, project copy)
R = 500; % nm, strike combat radius threshold [RFP 3.5.2(a), p.4]
R_des = 700; % nm, desirable radius, used only to compare payload against radius [RFP 3.5.2(a), p.4]
R_dash = 50; % nm, sea level dash each way [RFP 3.5.2(b), p.5]
M_dash = 0.8; % sea level dash Mach [RFP 3.5.2(c), p.5]
E = 10/60; % hr, loiter before arrestment [RFP 3.3.2(c), p.4]
W_av = 1000; % lb, internal avionics and sensors [RFP 3.4.2(a), p.4]
Q = 500; % production quantity for unit cost [RFP 4(j), p.6]

%% Class values (W2L1)
f_TO = 0.97; % warmup and takeoff weight ratio [W2L1 s.8]
f_CL = 0.985; % climb weight ratio [W2L1 s.8]
f_LA = 0.995; % landing weight ratio [W2L1 s.8]
RFF = 0.05; % reserve fuel fraction [W2L1 s.17]
TFF = 0.01; % trapped fuel fraction [W2L1 s.17]
K_LD = 14; % L/Dmax constant, military jet [W2L1 s.30]
c_cr = 0.8; % 1/hr, cruise and dash TSFC, low-bypass turbofan [W2L1 s.31]
c_lt = 0.7; % 1/hr, loiter TSFC, low-bypass turbofan [W2L1 s.31]
C = -0.16; % Eq. (2) exponent, UAV Recce & UCAV row [Raymer 5th ed. Table 3.1 p.31, via IIT Bombay AE-332 L10 slide 4]
A = 1.53*2.2046^(-C); % Eq. (2) coefficient: 1.53 is for W0 in kg (units per L10 slide 3), converted for W0 in lb

%% Assumptions (replace with the team's frozen baseline)
AR = 4; % aspect ratio, assumed
SwetSref = 4; % wetted to reference area ratio, assumed
M_cr = 0.75; % cruise Mach at 30,000 ft, assumed
k_inst = 1.225; % Eq. (A5) installed electronics: 1 + 0.075 cooling [NASA/TM-2017-219627 Eq.114] + 0.15 wiring (assumed)

%% Aerodynamics and speeds
LDmax = K_LD*sqrt(AR/SwetSref); % Eq. (A1) [W2L1 s.30]
LD_cr = 0.866*LDmax; % Eq. (A2) jet cruise at 86.6% of L/Dmax [W2L1 s.13]
LD_lt = LDmax; % Eq. (A2) jet loiter at L/Dmax [W2L1 s.14]
LD_da = 0.5*LDmax; % Eq. (A2) sea level dash well below L/Dmax, assumed
V_cr = M_cr*994.8*0.5925; % Eq. (A3) kt, a = 994.8 ft/s at 30,000 ft [W2L1 s.13], 0.5925 kt per ft/s
V_da = M_dash*1116.4*0.5925; % Eq. (A3) kt, a = 1116.4 ft/s at sea level (standard atmosphere)

%% Mission fuel fraction and sizing
cruise = @(d) exp(-d*c_cr/(V_cr*LD_cr)); % Eq. (4) Breguet range for a d nm cruise leg [W2L1 s.13]
dash = exp(-R_dash*c_cr/(V_da*LD_da)); % Eq. (4) Breguet range for one 50 nm sea level dash
loiter = exp(-E*c_lt/LD_lt); % Eq. (5) Breguet endurance [W2L1 s.14]
WfW = @(r) (1 + RFF + TFF)*(1 - f_TO*f_CL*cruise(r - R_dash)^2*dash^2*loiter*f_LA); % Eq. (3) with mission product (A4) [W2L1 s.17]
W0_of = @(P, r) sizeTOGW(P, WfW(r), A, C); % Eq. (1) with (2): full re-size for payload P at radius r

%% Payloads (lb)
W_GBU = 204; % GBU-53/B [Raytheon SDB II fact sheet, p.2]
W_BRU = 330; % BRU-61/A four-place rack, empty [Cobham BRU-61/A brochure, p.1]
W_jam = 220; % ALQ-214 class jammer: receiver 36 + modulator 40 + dual transmitter 57 + preamp 14 + E/F rack 73 [L3Harris ALQ-214 sell sheet, p.2]
W_MALD = 300; % MALD-J, upper bound: "less than 300 pounds" is stated for the MALD family [RTX MALD page, How it works]
P_thr = k_inst*W_av + W_BRU + 4*W_GBU; % Eq. (A6) threshold: RFP strike load [RFP 3.4.2, p.4]
P_des = P_thr + k_inst*W_jam + 2*W_MALD; % Eq. (A6) desired: strike + organic EW kit, team-derived [RFP 3.1(a)(a); PRM 2 slide 7]
P_swp = k_inst*(W_av + W_jam) + 2*W_MALD; % Eq. (A6) EW kit carried instead of the bombs and rack

%% Unit cost (DAPCA IV) [AOE module A6, slides 13-15]
TW = 0.6; % thrust to weight, sizes the engine for cost only, assumed
T_R = 3000; % deg R, turbine inlet temperature, assumed
QD = 4; % flight test aircraft, assumed equal to the MQ-25 development contract (four aircraft) [Boeing release, Aug. 30, 2018]
cost = @(W0, W_elec) unitCostDAPCA(A*W0^C*W0, TW*W0, M_dash, T_R, W_elec, V_da, Q, QD); % Eq. (6), empty weight from Eq. (2), $M FY2024

%% Results
W_thr = W0_of(P_thr, R);
W_des = W0_of(P_des, R);
W_swp = W0_of(P_swp, R);
C_thr = cost(W_thr, W_av);
C_des = cost(W_des, W_av + W_jam); % includes buying a jammer for every aircraft
C_des_af = cost(W_des, W_av); % airframe growth only, no jammer
fprintf('Threshold: P = %.0f lb, W0 = %.0f lb, We/W0 = %.3f, cost = $%.2fM\n', P_thr, W_thr, A*W_thr^C, C_thr);
fprintf('Desired: P = %.0f lb, W0 = %.0f lb (%+.1f%%), cost = $%.2fM (%+.1f%%; airframe only %+.1f%%)\n', ...
  P_des, W_des, 100*(W_des/W_thr - 1), C_des, 100*(C_des/C_thr - 1), 100*(C_des_af/C_thr - 1));
fprintf('EW kit instead of bombs: P = %.0f lb (below threshold %.0f lb)\n', P_swp, P_thr);

%% Sensitivity metrics, Eq. (A10)
P = 1000:100:4500; % range studied, lb
W0 = arrayfun(@(p) W0_of(p, R), P);
UC = arrayfun(@(w) cost(w, W_av), W0);
dW = diff(W0)./diff(P); % slope dW0/dP across the range
W7 = W0_of(P_thr, R_des); % threshold payload at 700 nm
fprintf('Slope at threshold: %.2f lb/lb, $%.2fM per 1,000 lb\n', (W0_of(P_thr + 100, R) - W_thr)/100, 10*(cost(W0_of(P_thr + 100, R), W_av) - C_thr));
fprintf('Slope across range: %.2f to %.2f lb/lb\n', dW(1), dW(end));
fprintf('Elasticity threshold to desired: W0 %.2f, cost %.2f\n', (W_des/W_thr - 1)/(P_des/P_thr - 1), (C_des/C_thr - 1)/(P_des/P_thr - 1));
fprintf('Radius 500 to 700 nm: W0 %+.1f%%, elasticity %.2f; payload slope at 700 nm %.2f lb/lb\n', ...
  100*(W7/W_thr - 1), (W7/W_thr - 1)/(R_des/R - 1), (W0_of(P_thr + 100, R_des) - W7)/100);
fprintf('Sizing denominator at threshold: %.2f\n', 1 - A*W_thr^C - WfW(R));
fprintf('X-47B check: Eq. (2) gives %.3f vs actual 14,000/44,567 = %.3f [VT AOE X-47 presentation, slide 5]\n', A*44567^C, 14000/44567);

%% Plot: payload requirement vs MoMs, with threshold, desired, baseline, recommended marked
range = @(x) max(x) - min(x);
Y = {W0, UC};
Ym = {[W_thr W_des], [C_thr C_des]};
ylab = {'Takeoff gross weight (lb)', 'Unit cost, $M (FY2024)'};
ttl = {sprintf('TOGW at 500 nm: threshold to desired %+.0f%%', 100*(W_des/W_thr - 1)), ...
  sprintf('Unit cost (MoM-06): threshold to desired %+.0f%%', 100*(C_des/C_thr - 1))};
figure('Position', [100 100 1100 420]);
for k = 1:2
  subplot(1, 2, k); hold on; grid on; box on;
  yl = [min([Y{k} Ym{k}]) max([Y{k} Ym{k}])] + [-0.05 0.08]*range([Y{k} Ym{k}]);
  plot(P, Y{k}, 'k-', 'LineWidth', 1.6);
  h1 = plot([P_thr P_thr], yl, 'b--', 'LineWidth', 1.2);
  h2 = plot([P_des P_des], yl, 'r-.', 'LineWidth', 1.2);
  h3 = plot(P_thr, Ym{k}(1), 'ks', 'MarkerSize', 11, 'MarkerFaceColor', [.6 .6 .6]);
  h4 = plot(P_thr, Ym{k}(1), 'p', 'MarkerSize', 16, 'Color', [0 .5 0], 'MarkerFaceColor', [.2 .8 .2]);
  plot(P_des, Ym{k}(2), 'o', 'MarkerSize', 7, 'Color', [.7 0 0], 'MarkerFaceColor', [1 .5 .5]);
  ylim(yl); ylabel(ylab{k}); title(ttl{k});
  xlabel('Strike payload: stores + installed mission systems (lb)');
end
subplot(1, 2, 1);
h5 = plot(P_swp, W_swp, 'd', 'MarkerSize', 8, 'Color', [0 0 .7], 'MarkerFaceColor', [.4 .6 1]);
legend([h1 h2 h3 h4 h5], {'RFP threshold', 'Desired (+ organic EW)', 'Baseline', 'Recommended', 'EW kit instead of bombs'}, 'Location', 'northwest', 'FontSize', 8);
print('-dpng', '-r150', 'fig_payload_trade_lsonnleitner.png');
