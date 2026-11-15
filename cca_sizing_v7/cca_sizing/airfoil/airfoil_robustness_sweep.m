function table_out = airfoil_robustness_sweep(sections, plot_it)
%AIRFOIL_ROBUSTNESS_SWEEP  Compare several NACA 4-digit sections' Cl_alpha,
%   alpha0 and Cm_c4, as a robustness cross-check on the thickness/camber
%   assumption CcaGeom/CcaAero make for the (actual, transonic supercritical)
%   wing section.
%
%   table_out = airfoil_robustness_sweep(sections, plot_it)
%
%   sections   cellstr/string array of 4-digit designations, e.g.
%              ["0008","0010","0012","2410","2412","4412"]. Default spans
%              a thickness range bracketing a typical transonic root/tip
%              t/c (6-12%) at zero and moderate camber.
%   plot_it    true to also plot CL vs alpha for every section. Default true.
%
%   Returns a table with one row per section: CLa_per_rad, alpha0_deg,
%   Cm_c4_mean, max_CL_CP_mismatch_pct (the validity flag for that case).
%
%   WHY THIS MATTERS FOR THE SIZING CODE: CcaAero assumes a small camber
%   (m~0.02, p~0.4) thin-airfoil-equivalent section when it builds the VLM
%   mesh, standing in for the real transonic supercritical airfoil (whose
%   exact camber/thickness is proprietary/undetermined at this stage). This
%   sweep shows how much Cl_alpha, alpha0 and Cm_c4 actually move across a
%   reasonable family of 4-digit sections, i.e. how sensitive the whole
%   sizing result is to that stand-in assumption.

    arguments
        sections = ["0006","0008","0010","0012","2408","2410","2412","4412"]
        plot_it (1,1) logical = true
    end

    n = numel(sections);
    CLa = zeros(n,1); a0 = zeros(n,1); Cmc4 = zeros(n,1); mism = zeros(n,1);

    if plot_it
        figure('Name', 'Airfoil robustness sweep'); hold on; grid on; box on;
        cols = lines(n);
    end

    for i = 1:n
        r = naca_panel_method(sections(i), -6:1:10, 160, false);
        CLa(i)  = r.CLa_per_rad;
        a0(i)   = r.alpha0_deg;
        Cmc4(i) = r.Cm_c4_mean;
        mism(i) = r.max_CL_CP_mismatch_pct;

        if plot_it
            plot(r.alpha_deg, r.CL_kj, '-o', 'Color', cols(i,:), ...
                'DisplayName', string(sections(i)));
        end
    end

    if plot_it
        xlabel('\alpha [deg]'); ylabel('C_L (incompressible, inviscid)');
        title('NACA 4-digit panel-method sweep'); legend('Location','best');
        hold off;
    end

    table_out = table(sections(:), CLa, a0, Cmc4, mism, ...
        'VariableNames', {'section','CLa_per_rad','alpha0_deg','Cm_c4_mean','max_mismatch_pct'});

    disp(table_out);
end
