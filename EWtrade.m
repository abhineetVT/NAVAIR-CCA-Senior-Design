%% THW3 Payload/EW trade studies (Hari, Team 11)
% Study 1: internal vs external carriage of the 4 GBU-53/B (TOGW and unit cost)
% Study 2: EW capability tiers (TOGW, unit cost, team-defined capability score)
clear; clc; close all;

%% --- Shared baseline (copied from Lukas's trade_payload.m; need to edit here when the team freezes the baseline) ---
% Requirements (RFP)
p.R       = 500;   % nm, strike combat radius threshold [RFP 3.5.2(a)]
p.R_des   = 700;   % nm, desirable radius [RFP 3.5.2(a)]
p.R_dash  = 50;    % nm, sea level dash each way [RFP 3.5.2(b)]
p.M_dash  = 0.8;   % sea level dash Mach [RFP 3.5.2(c)]
p.E       = 10/60; % hr, loiter before arrestment [RFP 3.3.2(c)]
p.W_av    = 1000;  % lb, internal avionics and sensors [RFP 3.4.2(a)]
p.Q       = 500;   % production quantity [RFP 4(j)]

% Class values (W2L1)
p.f_TO = 0.97; p.f_CL = 0.985; p.f_LA = 0.995;   
p.RFF  = 0.05; p.TFF  = 0.01;                  
p.K_LD = 14;                                    
p.c_cr = 0.8;  p.c_lt = 0.7;                     
p.C    = -0.16;                                 
p.A    = 1.53*2.2046^(-p.C);                    

% Assumptions Lukas flagged (replace with frozen baseline)
p.AR       = 4;     % aspect ratio
p.SwetSref = 4;     % wetted/reference area, treated here as the CLEAN (no bay) airframe
p.M_cr     = 0.75;  % cruise Mach at 30,000 ft
p.k_inst   = 1.225; % installed electronics factor
p.TW = 0.6; p.T_R = 3000; p.QD = 4;              % cost-only assumptions

% Speeds, Eq. (A3)
p.V_cr = p.M_cr  *994.8 *0.5925;  % kt
p.V_da = p.M_dash*1116.4*0.5925;  % kt

% Component weights, lb
p.W_GBU  = 204;  % GBU-53/B
p.W_BRU  = 330;  % BRU-61/A rack 
p.W_jam  = 220;  % ALQ-214 class jammer, uninstalled 
p.W_MALD = 300;  % MALD-J upper bound 

%% --- Study assumptions (source given for each; "ASSUMED" = our judgment, swept/flagged in report) ---
% --- Internal vs external carriage ---
a.n_stores = 4;       % GBU-53/B per sortie [RFP 3.4.2]
a.bay_target = 0.075; % midpoint of 6-9%
a.bay_range  = [0.06 0.09];
% External-store drag, built bottom-up from the bomb size:
a.d_store_in = 7;    
a.Cd_store   = 0.20; 
a.k_pyl      = 1.5;  
a.WS         = 90;   
a.e          = 0.8; 

% --- EW ---
a.W_esm   = 47.7;     % lb, passive RWR/ESM, AN/APR-39D(V)2 system weight
a.C_MALD  = 80.768/200*(313.689/236.736);   % $M per round, FY2024
a.w_esm = 0.2; a.w_spj = 0.4; a.w_decoy = 0.4;  % team-defined capability score weights (no source)
a.score_target = 0.6; % team choice: minimum capability score, shown as a reference line

%% --- STUDY 1: internal vs external carriage ---
% RFP 1(e): external carriage "acceptable" (threshold), internal "desirable for reduced RCS" (desired).
% Baseline: Lukas's threshold aircraft (no carriage hardware or store drag)
WfW0 = missionFuelFrac(p, p.R, p.SwetSref, 1);
W_base = sizeTOGW(p.k_inst*p.W_av + p.W_BRU + 4*p.W_GBU, WfW0, p.A, p.C);
C_base = unitCostDAPCA(p.A*W_base^p.C*W_base, p.TW*W_base, p.M_dash, p.T_R, p.W_av, p.V_da, p.Q, p.QD);

% Per-store L/D loss from bottom-up drag: added CD0 per store / clean CD0, with L/D ~ 1/sqrt(CD0)
Sref = W_base/a.WS;                                        % ft^2
dCD0 = a.Cd_store*a.k_pyl*(pi/4*(a.d_store_in/12)^2)/Sref;
K    = 1/(pi*a.e*p.AR);
CD0  = 1/(4*K*(p.K_LD*sqrt(p.AR/p.SwetSref))^2);           
a.dLD_ext = 0.5*dCD0/CD0;                                  
fprintf('Per-store drag: dCD0 = %.5f (%.1f%% of clean CD0 = %.4f) -> L/D loss %.1f%% per store\n', dCD0, 100*dCD0/CD0, CD0, 100*a.dLD_ext);

% Calibrate bay weight so all-internal vs all-external TOGW matches the literature
for j = 1:3
  tgt = [a.bay_target a.bay_range];
  wb(j) = fzero(@(w) bayGap(w, p, a) - tgt(j), [0 1000]);
end
a.W_bay = wb(1);
fprintf('Bay weight calibrated to +%.1f%% TOGW (all ext to all int): %.0f lb per internal store (range %.0f to %.0f lb for 6-9%%)\n', ...
  100*a.bay_target, wb(1), wb(2), wb(3));

n = 0:a.n_stores; fr = n/a.n_stores;
for i = 1:numel(n), r(i) = runCarriage(n(i), p.R, p, a); end
W0 = [r.W0]; UC = [r.UC];
for i = 1:numel(n), t = runCarriage(n(i), p.R_des, p, a); W7(i) = t.W0; U7(i) = t.UC; end

fprintf('Baseline (Lukas): W0 = %.0f lb, $%.2fM\n\nn_int  frac  W0(lb)  cost($M)\n', W_base, C_base);
for i = 1:numel(n), fprintf('%d     %3.0f%%  %6.0f  %7.2f\n', n(i), 100*fr(i), W0(i), UC(i)); end
fprintf('\nAll external to all internal: TOGW %+.1f%%, cost %+.1f%%\n', 100*(W0(end)/W0(1)-1), 100*(UC(end)/UC(1)-1));
fprintf('Per internal store: %+.1f lb, %+.2f $M\n', (W0(end)-W0(1))/4, (UC(end)-UC(1))/4);
fprintf('At 700 nm: TOGW %+.1f%%, cost %+.1f%% (all ext to all int)\n', 100*(W7(end)/W7(1)-1), 100*(U7(end)/U7(1)-1));
lbl = {'low (6%)', 'high (9%)'};
for j = 2:3   % cost range across the 6-9% in literature
  aj = a; aj.W_bay = wb(j); lo = runCarriage(0, p.R, p, aj); hi = runCarriage(4, p.R, p, aj);
  fprintf('Literature %s: TOGW %+.1f%%, cost %+.1f%%\n', lbl{j-1}, 100*(hi.W0/lo.W0-1), 100*(hi.UC/lo.UC-1));
end

%% Carriage figure: TOGW and unit cost vs fraction internal
figure('Position', [50 50 900 420], 'Color', 'w');
Y = {W0, UC}; yl = {'Takeoff gross weight (lb)', 'Unit cost, $M (FY2024)'};
tt = {sprintf('TOGW: %+.1f%% (ext to int)', 100*(W0(end)/W0(1)-1)), sprintf('Unit cost: %+.1f%% (ext to int)', 100*(UC(end)/UC(1)-1))};
for k = 1:2
  subplot(1,2,k); hold on; grid on; box on; y = Y{k};
  lim = [min(y) max(y)] + 0.15*(max(y)-min(y)+eps)*[-1 1];
  plot(fr, y, 'k-o', 'LineWidth', 1.6, 'MarkerFaceColor', 'k');
  h1 = plot([0 0], lim, 'b--', 'LineWidth', 1.2); h2 = plot([1 1], lim, 'r-.', 'LineWidth', 1.2);
  if k == 1, text(0.30, lim(1)+0.05*diff(lim), sprintf('Baseline (Lukas, no carriage hardware): %.0f lb', W_base), 'FontSize', 7); end
  if k == 2, text(0.30, lim(1)+0.05*diff(lim), sprintf('Baseline (Lukas, no carriage hardware): $%.2fM', C_base), 'FontSize', 7); end
  ylim(lim); xlim([-0.05 1.05]); xlabel('Fraction of strike stores carried internally'); ylabel(yl{k}); title(tt{k});
  legend([h1 h2], {'Threshold (external OK)', 'Desired (internal)'}, 'Location', 'northwest', 'FontSize', 7);
end
print('-dpng', '-r150', 'fig_carriage_trade_hari.png');

fid = fopen('results_carriage_hari.csv', 'w'); fprintf(fid, 'n_internal,fraction,TOGW_lb,unit_cost_M\n');
for i = 1:numel(n), fprintf(fid, '%d,%.2f,%.1f,%.3f\n', n(i), fr(i), W0(i), UC(i)); end; fclose(fid);

%% --- STUDY 2: EW capability tiers ---
% RFP 3.1(a) asks for EW-threat design but gives no EW load; range is team-derived (same as Lukas's):
%% EW tiers (weights uninstalled; installed factor k_inst applied to electronics only)
names = {'None', 'RWR/ESM only', 'SPJ (ALQ-214 class)', 'SPJ + 2 MALD-J', 'SPJ + 4 MALD-J'};
W_ew  = [0, a.W_esm, p.W_jam, p.W_jam, p.W_jam];  % lb electronics
n_md  = [0, 0, 0, 2, 4];                          % MALD-J rounds
esm   = [0 1 1 1 1]; spj = [0 0 1 1 1]; decoy = min(n_md/4, 1);
score = a.w_esm*esm + a.w_spj*spj + a.w_decoy*decoy;   
nT = numel(names); idx = 1:nT; i_thr = 1; i_des = 4;

%% Size each tier at the 500 nm strike mission
WfW = missionFuelFrac(p, p.R, p.SwetSref, 1);
P_base = p.k_inst*p.W_av + p.W_BRU + 4*p.W_GBU;        % RFP strike load (Lukas threshold)
for i = 1:nT
  P(i)  = P_base + p.k_inst*W_ew(i) + n_md(i)*p.W_MALD;     
  W0(i) = sizeTOGW(P(i), WfW, p.A, p.C);                   
  UC(i) = unitCostDAPCA(p.A*W0(i)^p.C*W0(i), p.TW*W0(i), p.M_dash, p.T_R, p.W_av + W_ew(i), p.V_da, p.Q, p.QD);
  sortie(i) = n_md(i)*a.C_MALD;                               % $M expended per sortie
end
% EW kit carried INSTEAD of the bombs (Lukas's swap case)
P_swp = p.k_inst*(p.W_av + p.W_jam) + 2*p.W_MALD;
W_swp = sizeTOGW(P_swp, WfW, p.A, p.C);
C_swp = unitCostDAPCA(p.A*W_swp^p.C*W_swp, p.TW*W_swp, p.M_dash, p.T_R, p.W_av + p.W_jam, p.V_da, p.Q, p.QD);

fprintf('Tier                    payload(lb)  W0(lb)  cost($M)  score  sortie($M)\n');
for i = 1:nT, fprintf('%-22s  %9.0f  %7.0f  %7.2f   %.2f   %.2f\n', names{i}, P(i), W0(i), UC(i), score(i), sortie(i)); end
fprintf('\nCheck vs Lukas: tier 1 W0 %.0f (6438), tier 4 W0 %.0f (8395), tier 4 cost $%.2fM (19.8)\n', W0(1), W0(4), UC(4));
fprintf('Threshold to desired: TOGW %+.1f%%, unit cost %+.1f%%, score %.2f to %.2f\n', ...
  100*(W0(i_des)/W0(i_thr)-1), 100*(UC(i_des)/UC(i_thr)-1), score(i_thr), score(i_des));
fprintf('SPJ only (tier 3) vs none: TOGW %+.1f%%, cost %+.1f%%\n', 100*(W0(3)/W0(1)-1), 100*(UC(3)/UC(1)-1));
fprintf('Swap case (EW instead of bombs): P = %.0f lb, W0 = %.0f (%+.1f%%), cost $%.2fM\n', P_swp, W_swp, 100*(W_swp/W0(1)-1), C_swp);
fprintf('Marginal $M per +0.1 score: ');  fprintf('%.2f ', diff(UC)./(diff(score)/0.1)); fprintf('\n');

%% Figure 1: TOGW and cost by tier
figure('Position', [50 50 1100 450], 'Color', 'w');
Y = {W0, UC}; yl = {'Takeoff gross weight (lb)', 'Unit cost, $M (FY2024)'};
for k = 1:2
  subplot(1,2,k); hold on; grid on; box on; y = Y{k};
  yy = y; if k == 1, yy = [y W_swp]; end
  lim = [min(yy) max(yy)] + [-0.15 0.2]*(max(yy)-min(yy));
  plot(idx, y, 'k-o', 'LineWidth', 1.6, 'MarkerFaceColor', 'k');
  h1 = plot(i_thr*[1 1], lim, 'b--', 'LineWidth', 1.2);
  h2 = plot(i_des*[1 1], lim, 'r-.', 'LineWidth', 1.2);
  if k == 1, h5 = plot(i_des, W_swp, 'd', 'MarkerSize', 8, 'Color', [0 0 .7], 'MarkerFaceColor', [.4 .6 1]); end
  ylim(lim); xlim([0.5 nT+0.5]); set(gca, 'XTick', idx, 'XTickLabel', names, 'FontSize', 7);
  try, xtickangle(25); catch, end
  ylabel(yl{k}); title(sprintf('%s: %+.1f%% (threshold to desired)', strtok(yl{k}, ','), 100*(y(i_des)/y(i_thr)-1)));
  if k == 1, legend([h1 h2 h5], {'Threshold (no EW)', 'Desired (SPJ + 2 MALD-J)', 'EW kit instead of bombs'}, 'Location', 'northwest', 'FontSize', 7); end
  if k == 2, legend([h1 h2], {'Threshold (no EW)', 'Desired (SPJ + 2 MALD-J)'}, 'Location', 'northwest', 'FontSize', 7); end
end
print('-dpng', '-r150', 'fig_ew_trade_hari.png');

%% Figure 2: capability score vs unit cost 
figure('Position', [80 80 600 480], 'Color', 'w'); hold on; grid on; box on;
hd = plot(UC, score, 'k-o', 'LineWidth', 1.6, 'MarkerFaceColor', 'k');
for i = 1:nT, text(UC(i)+0.03, score(i)-0.03, sprintf('%s (+$%.1fM/sortie)', names{i}, sortie(i)), 'FontSize', 7); end
hl = plot([min(UC) max(UC)+0.6], a.score_target*[1 1], 'm--', 'LineWidth', 2);
legend([hd hl], {'EW tiers (no EW to SPJ + 4 MALD-J)', sprintf('Minimum capability target (team choice, %.1f)', a.score_target)}, 'Location', 'southeast', 'FontSize', 7);
xlim([min(UC)-0.1 max(UC)+1.4]); ylim([-0.05 1.1]);
xlabel('Unit cost, $M (FY2024), flyaway'); ylabel('EW capability score (team-defined, 0-1)'); title('EW capability vs unit cost');
print('-dpng', '-r150', 'fig_ew_pareto_hari.png');

%% Results for the team driver-comparison figure
fid = fopen('results_ew_hari.csv', 'w');
fprintf(fid, 'tier,name,payload_lb,TOGW_lb,unit_cost_M,score,sortie_cost_M\n');
for i = 1:nT, fprintf(fid, '%d,%s,%.0f,%.1f,%.3f,%.2f,%.2f\n', i, names{i}, P(i), W0(i), UC(i), score(i), sortie(i)); end
fclose(fid);

%% --- Local functions ---
function WfW = missionFuelFrac(p, R, SwetSref, LDmult)
LDmax = p.K_LD*sqrt(p.AR/SwetSref)*LDmult; 
LD_cr = 0.866*LDmax;                      
LD_lt = LDmax;                             
LD_da = 0.5*LDmax;                         
cruise = @(d) exp(-d*p.c_cr/(p.V_cr*LD_cr));           
dash   = exp(-p.R_dash*p.c_cr/(p.V_da*LD_da));         
loiter = exp(-p.E*p.c_lt/LD_lt);                      
WfW = (1 + p.RFF + p.TFF)*(1 - p.f_TO*p.f_CL*cruise(R - p.R_dash)^2*dash^2*loiter*p.f_LA); % Eq. (3),(A4)
end

function out = runCarriage(n_int, R, p, a)
% Re-size the strike aircraft with n_int of the 4 GBU-53/B carried internally
n_ext  = a.n_stores - n_int;
LDmult = 1 - a.dLD_ext*n_ext;                              % external store drag
P = p.k_inst*p.W_av + p.W_BRU + a.n_stores*p.W_GBU + a.W_bay*n_int;   % payload + bay structure
WfW = missionFuelFrac(p, R, p.SwetSref, LDmult);
W0  = sizeTOGW(P, WfW, p.A, p.C);
We  = p.A*W0^p.C*W0 + a.W_bay*n_int;                 
UC  = unitCostDAPCA(We, p.TW*W0, p.M_dash, p.T_R, p.W_av, p.V_da, p.Q, p.QD);
out.W0 = W0; out.UC = UC; out.P = P;
end

function g = bayGap(w_bay, p, a)
% TOGW increase, all-internal vs all-external, for a given bay weight per store (used to calibrate w_bay)
a.W_bay = w_bay;
hi = runCarriage(a.n_stores, p.R, p, a); lo = runCarriage(0, p.R, p, a);
g = hi.W0/lo.W0 - 1;
end
