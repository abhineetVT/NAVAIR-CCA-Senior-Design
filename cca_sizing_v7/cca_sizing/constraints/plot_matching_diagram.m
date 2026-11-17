function plot_matching_diagram(WS_vec, TW_curves, names, WS_max_landing, WS_design, TW_design)
%PLOT_MATCHING_DIAGRAM  T/W (SL static) vs W/S matching diagram: every
%   individual constraint curve, the landing W/S cap (vertical line), the
%   combined feasible region (shaded), and the chosen design point.

    arguments
        WS_vec (1,:) double
        TW_curves cell
        names (1,:) cell
        WS_max_landing (1,1) double
        WS_design (1,1) double
        TW_design (1,1) double
    end

    figure('Name', 'CCA T/W - W/S Matching Diagram'); hold on; grid on; box on;
    cols = lines(numel(TW_curves));

    for k = 1:numel(TW_curves)
        plot(WS_vec, TW_curves{k}, '-', 'Color', cols(k,:), 'LineWidth', 1.8, ...
            'DisplayName', names{k});
    end

    stacked = zeros(numel(TW_curves), numel(WS_vec));
    for k = 1:numel(TW_curves), stacked(k,:) = TW_curves{k}(:)'; end
    TW_env = max(stacked, [], 1);

    feasible_x = WS_vec(WS_vec <= WS_max_landing);
    feasible_y_lo = TW_env(WS_vec <= WS_max_landing);
    y_top = max(TW_env)*1.3;
    fill([feasible_x, fliplr(feasible_x)], [feasible_y_lo, y_top*ones(size(feasible_y_lo))], ...
        [0.75 0.90 0.75], 'FaceAlpha', 0.35, 'EdgeColor', 'none', ...
        'DisplayName', 'Feasible region');

    xline(WS_max_landing, '--k', 'LineWidth', 1.6, 'DisplayName', 'Landing W/S cap');
    plot(WS_design, TW_design, 'r*', 'MarkerSize', 14, 'LineWidth', 2, ...
        'DisplayName', 'Design point');

    xlabel('Wing loading, W/S [lbf/ft^2]');
    ylabel('Thrust-to-weight, T/W (sea-level static)');
    title('CCA Constraint Analysis -- Matching Diagram');
    legend('Location', 'northoutside', 'NumColumns', 2, 'Interpreter', 'none');
    ylim([0, y_top]);
    hold off;
end
