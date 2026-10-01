%% TOGW vs. range and TOGW vs. TSFC (strike mission, F414 baseline engine)
% Mission: climb -> cruise out -> 50 nm sea-level dash -> 50 nm dash back -> cruise back -> 10 min loiter -> land
clear; clc; close all;

%% Inputs (placeholders for this assignment)
p.Wfixed = 1000 + 4*204;          % lb, ordanance is 204 lbs each (4 total)
p.A = 2.11;  p.C = -0.13;         % empty weight fraction We/W0 = A*W0^C  (Raymer fighter)
p.oew = 0.90;                     % unmanned reduction (assumption)

p.c_cr = 1.01;   p.V_cr = 472;   p.LD_cr = 8.6;    % cruise  (M0.8, 30 kft)
p.c_ds = 1.13;   p.V_ds = 529;   p.LD_ds = 3.2;    % SL dash (M0.8, dry thrust)
p.c_lt = 0.97;                   p.LD_lt = 9.0;    % loiter  (M0.5, 10 kft)

%% Study 1: TOGW vs. combat radius
R = 300:25:900;
W = arrayfun(@(r) togw(r, 1.0, p), R);
W500 = togw(500, 1.0, p);  W700 = togw(700, 1.0, p);
fprintf('500 nm: %.0f lb | 700 nm: %.0f lb | change: %+.1f%%\n', W500, W700, 100*(W700/W500-1));

figure; plot(R, W, 'b-', 'LineWidth', 2); hold on; grid on;
plot([500 700], [W500 W700], 'ro', 'MarkerFaceColor', 'r');
xlabel('Combat radius [nmi]'); ylabel('TOGW [lb]');
title('TOGW vs. combat radius (strike)');
text(500, W500, sprintf('  Threshold: %.0f lb', W500), 'VerticalAlignment', 'top');
text(700, W700, sprintf('  Desired: %.0f lb', W700),   'VerticalAlignment', 'top');

%% Study 2: TOGW vs. TSFC
pct = -20:2.5:30;                                  % % change in TSFC from F414 baseline
figure; hold on; grid on;
for r = [500 700]
    plot(pct, arrayfun(@(d) togw(r, 1 + d/100, p), pct), '-o', 'LineWidth', 1.5, ...
         'DisplayName', sprintf('%d nm radius', r));
end
xline(0, 'k--', 'F414 baseline', 'HandleVisibility', 'off');
xlabel('Change in TSFC [%]'); ylabel('TOGW [lb]');
title('TOGW vs. TSFC (strike)'); legend('Location', 'northwest');

%% Sizing function 
function W0 = togw(R, m, p)
    % m = TSFC multiplier (1 = F414 baseline) (1.1 is a 10% worse TSFC)
    Rc = R - p.dash;                                             % cruise distance each way
    f  = 0.970 * 0.985 * 0.995;                                  % warmup, climb, landing
    f  = f * exp(-2*Rc*m*p.c_cr / (p.V_cr*p.LD_cr));             % cruise out + back (Breguet)
    f  = f * exp(-2*p.dash*m*p.c_ds / (p.V_ds*p.LD_ds));         % dash in + out
    f  = f * exp(-p.t_loit*m*p.c_lt / p.LD_lt);                  % loiter
    ff = p.reserve * (1 - f);                                    % fuel fraction Wf/W0

    W0 = 15000;                                                  % initial guess
    for k = 1:2000
        We_frac = p.oew * p.A * W0^p.C;                          % empty weight fraction
        Wnew = p.Wfixed / (1 - We_frac - ff);                    % W0 = Wfixed/(1 - We/W0 - Wf/W0)
        if Wnew < 0 || Wnew > 1e6, W0 = NaN; return; end         % mission can't close
        if abs(Wnew - W0) < 0.01, W0 = Wnew; return; end
        W0 = Wnew;
    end
end