%% GobbleWorks CCA -- Internal vs. External Stores Carriage: Incremental Cost
%  Trade study owners: Kapil & Adi
%  Requirement traded: Ordnance (store) carriage configuration
%
%  RFP basis ("Ordnance (store) Carriage"):
%     "External carriage of ordnance is acceptable."          <- threshold
%     "Internal carriage of ordnance is desirable for
%      reduced radar cross section."                          <- desired
%
%  COST SCOPE: aircraft weight is held fixed at the team-frozen baseline
%  across all three configurations (no Aero/Prop resize -- see report).
%  Reports the ADDITIONAL unit cost of Hybrid and Internal relative to
%  External (the RFP's minimum/"acceptable" configuration, $0 reference).
%
%  STEALTH SCOPE: RCS indices are derived from a comparator table of real
%  aircraft with commonly-cited, UNCLASSIFIED, open-source RCS figures
%  (order-of-magnitude only; actual values are classified). Used here only
%  to anchor our three carriage configurations to a believable order of
%  magnitude instead of picking numbers by feel.
clear; clc; close all;
%% ================= COMPARATOR AIRCRAFT: RCS BENCHMARKS =================
%  Figures below are widely-repeated unclassified/open-source estimates
%  (defense media, public officials' statements, textbook order-of-magnitude
%  figures). They are NOT classified data and are not precise to the digit
%  -- used here only to anchor our three carriage configurations to a
%  believable order of magnitude instead of guessing in a vacuum.
% --- Internal-carriage / VLO-shaped class (anchors our "Internal" config) ---
internal_names = {'F-22 Raptor (VLO, internal bay)', ...
                  'F-35 clean config (VLO, internal bay)', ...
                  'B-2 Spirit (VLO, internal bay)'};
internal_rcs_m2 = [0.0005, 0.003, 0.0003];   % frontal-aspect order-of-magnitude, m^2
% --- Partial-exposure class (anchors our "Hybrid" config) ---
% Public USAF/Lockheed commentary on F-35 "Beast Mode" (external stores
% added) describes the signature as reverting toward a 4th-generation-like
% level -- used here as the Hybrid anchor since it is the same airframe,
% isolating the carriage effect rather than comparing different airframes.
hybrid_names = {"F-35 'Beast Mode' (external stores added)"};
hybrid_rcs_m2 = [0.3];
% --- Conventional external-carriage class (anchors our "External" config) ---
external_names = {'F/A-18E/F Super Hornet (conventional, external)', ...
                  'F-16 (conventional, external)'};
external_rcs_m2 = [1.5, 3.0];
% Representative value per class = geometric mean (appropriate since RCS
% spans orders of magnitude and is conventionally compared in dB/log terms).
% Implemented manually (exp(mean(log(x)))) to avoid requiring the
% Statistics and Machine Learning Toolbox's geomean().
rcs_internal_rep = exp(mean(log(internal_rcs_m2)));
rcs_hybrid_rep   = exp(mean(log(hybrid_rcs_m2)));
rcs_external_rep = exp(mean(log(external_rcs_m2)));
fprintf('=== Comparator-Derived RCS Classes (unclassified, open-source) ===\n');
fprintf('Internal class representative RCS: %.5f m^2  (avg of %s)\n', ...
       rcs_internal_rep, strjoin(internal_names, ', '));
fprintf('Hybrid class representative RCS:   %.5f m^2  (anchor: %s)\n', ...
       rcs_hybrid_rep, hybrid_names{1});
fprintf('External class representative RCS: %.5f m^2  (avg of %s)\n\n', ...
       rcs_external_rep, strjoin(external_names, ', '));
% Index relative to Internal = 1.0, plus the dB form (standard RCS unit)
rcs_index = [rcs_external_rep, rcs_hybrid_rep, rcs_internal_rep] / rcs_internal_rep;
rcs_dB    = 10*log10(rcs_index);   % dB above Internal baseline (0 dB)
fprintf('Relative index (Internal = 1.0x):  External=%.0fx   Hybrid=%.0fx   Internal=1.0x\n', ...
       rcs_index(1), rcs_index(2));
fprintf('In dB above Internal baseline:      External=%.1f dB   Hybrid=%.1f dB   Internal=0.0 dB\n\n', ...
       rcs_dB(1), rcs_dB(2));
%% ---- Frozen team baseline (held fixed across all configs) ----
We_baseline_lb   = 31665;      % OEW placeholder -- replace w/ Adi's frozen OEW model
dash_speed_kt    = 560;        % ~M0.95 desired dash, used as DAPCA design speed
quantity         = 500;        % RFP: unit cost for a 500-aircraft production run
rate_eng  = 150.0;
rate_tool = 130.0;
rate_mfg  = 100.0;
rate_qc   = 110.0;
fta = 2;    % flight-test articles (nonrecurring)
%% ---- Configurations: manufacturing/structures effects only ----
% mfg_mult / tool_mult: DAPCA manufacturing & tooling HOUR multipliers.
% These remain engineering estimates (no comparable public numeric data
% exists for labor-hour deltas), but GAO reports on the F-35 program have
% repeatedly cited the internal weapons-bay doors/actuation system as a
% recurring cost and schedule driver -- directional support for an
% internal-carriage producibility penalty, even without an exact multiplier.
names      = {'External', 'Hybrid', 'Internal'};
mfg_mult   = [0.88,        1.08,     1.26];
tool_mult  = [0.82,        1.12,     1.42];
we_delta   = [-350.0,      -120.0,   0.0];
n = numel(names);
We        = We_baseline_lb + we_delta;
unit_cost = zeros(1, n);
CE  = zeros(1, n); CT = zeros(1, n); CMlab = zeros(1, n);
CQ  = zeros(1, n); CMmat = zeros(1, n);
for i = 1:n
   [unit_cost(i), CE(i), CT(i), CMlab(i), CQ(i), CMmat(i)] = ...
       dapca_unit_cost(We(i), dash_speed_kt, quantity, ...
                        mfg_mult(i), tool_mult(i), ...
                        rate_eng, rate_tool, rate_mfg, rate_qc, fta);
end
%% ---- Incremental cost relative to External (RFP "acceptable") ----
d_total = unit_cost - unit_cost(1);
d_CE    = CE    - CE(1);
d_CT    = CT    - CT(1);
d_CMlab = CMlab - CMlab(1);
d_CQ    = CQ    - CQ(1);
d_CMmat = CMmat - CMmat(1);
d_other = d_CE + d_CMmat;
fprintf('=== Incremental Cost of Carriage vs. External (RFP acceptable) ===\n');
fprintf('%-10s %10s %10s %10s %10s\n', 'Config', 'dTotal$M', 'dLabor$M', 'dTool$M', 'RCS(dB)');
for i = 1:n
   fprintf('%-10s %10.3f %10.3f %10.3f %10.1f\n', names{i}, d_total(i)/1e6, ...
           d_CMlab(i)/1e6, d_CT(i)/1e6, rcs_dB(i));
end
fprintf('\nExternal -> Hybrid:   +$%.2fM/aircraft for %.1f dB RCS reduction\n', ...
       d_total(2)/1e6, rcs_dB(1)-rcs_dB(2));
fprintf('External -> Internal: +%.2fM/aircraftfor%.1fdBRCSreduction(%.2fB fleet-wide)\n', ...
       d_total(3)/1e6, rcs_dB(1)-rcs_dB(3), d_total(3)*quantity/1e9);
fprintf('Hybrid   -> Internal: +$%.2fM/aircraft for %.1f dB further RCS reduction\n', ...
       (d_total(3)-d_total(2))/1e6, rcs_dB(2)-rcs_dB(3));
%% ---- Figure: incremental cost (stacked) + stealth (dB) ----
figure('Position', [100 100 1200 500]);
subplot(1,2,1);
stack_data = [d_CMlab; d_CT; d_CQ; d_other]' / 1e6;
b = bar(stack_data, 'stacked');
b(1).FaceColor = [0.12 0.31 0.55];
b(2).FaceColor = [0.79 0.58 0.11];
b(3).FaceColor = [0.30 0.60 0.16];
b(4).FaceColor = [0.60 0.60 0.60];
set(gca, 'XTickLabel', {'External (RFP acceptable)', 'Hybrid', 'Internal (baseline)'});
ylabel('Additional unit cost vs. External baseline ($M/aircraft)');
title('Manufacturing MoM: Incremental Cost of Carriage');
legend({'Manufacturing labor','Tooling','Quality control','Engineering + materials'}, ...
      'Location', 'northwest');
grid on; ylim([0 7]);
for i = 1:n
   if d_total(i) == 0
       txt = 'Reference ($0)';
   else
       txt = sprintf('+$%.2fM', d_total(i)/1e6);
   end
   text(i, d_total(i)/1e6 + 0.25, txt, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
subplot(1,2,2);
b2 = bar(rcs_dB);
b2.FaceColor = 'flat';
b2.CData = [0.30 0.60 0.16; 0.79 0.58 0.11; 0.12 0.31 0.55];
set(gca, 'XTickLabel', names);
ylabel('RCS relative to Internal baseline (dB, lower is better)');
title('Stealth MoM: RCS vs. Comparator-Anchored Classes');
grid on; ylim([-5 40]);
for i = 1:n
   text(i, rcs_dB(i) + 1.2, sprintf('%+.1f dB', rcs_dB(i)), ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
text(2, -2.5, {'Anchored to F-22/F-35/B-2 (internal), F-35', ...
              '"Beast Mode" (hybrid), F/A-18E/F & F-16', ...
              '(external) -- unclassified, order-of-magnitude'}, ...
    'HorizontalAlignment', 'center', 'FontAngle', 'italic', 'FontSize', 7.5, 'Color', [0.4 0.4 0.4]);;
sgtitle('Internal vs. External Stores Carriage: Incremental Cost vs. Stealth');
saveas(gcf, 'fig_incremental_cost_matlab.png');
%% ================= local function =================
function [unit_cost, CE, CT, CMlab, CQ, CMmat] = dapca_unit_cost( ...
   we, v_kt, qty, mfg_mult, tool_mult, rate_eng, rate_tool, rate_mfg, rate_qc, fta)
% DAPCA IV cost-estimating relationship (Raymer, Aircraft Design Ch. 18).
   N_ENGINES         = 1;
   ENGINE_UNIT_COST  = 4.5e6;   % existing-production engine (F414-class)
   AVIONICS_FRAC     = 0.15;
   HE = 4.86 * we^0.777 * v_kt^0.894 * qty^0.163;
   HT = 5.99 * we^0.777 * v_kt^0.696 * qty^0.263 * tool_mult;
   HM = 7.37 * we^0.820 * v_kt^0.484 * qty^0.641 * mfg_mult;
   HQ = 0.133 * HM;
   CE_total    = HE * rate_eng;
   CT_total    = HT * rate_tool;
   CMlab_total = HM * rate_mfg;
   CQ_total    = HQ * rate_qc;
   CMmat_total = 16.39 * we^0.921 * v_kt^0.621 * qty^0.799;
   CD          = 66.0 * we^0.630 * v_kt^1.300;
   CF          = 1947.4 * we^0.325 * v_kt^0.822 * fta^1.21;
   airframe_recur = CE_total + CT_total + CMlab_total + CQ_total + CMmat_total;
   program_total  = airframe_recur + CD + CF;
   avionics_total = AVIONICS_FRAC * airframe_recur;
   engine_total   = ENGINE_UNIT_COST * N_ENGINES * qty;
   unit_cost = (program_total + avionics_total + engine_total) / qty;
   CE    = CE_total    / qty;
   CT    = CT_total    / qty;
   CMlab = CMlab_total / qty;
   CQ    = CQ_total    / qty;
   CMmat = CMmat_total / qty;
end
