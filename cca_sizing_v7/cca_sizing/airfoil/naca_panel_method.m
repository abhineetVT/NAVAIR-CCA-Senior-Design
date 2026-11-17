function result = naca_panel_method(designation, alpha_deg_list, n_panels, verbose)
%NACA_PANEL_METHOD  Public entry point: analyze a NACA 4-digit section.
%
%   result = naca_panel_method(designation, alpha_deg_list, n_panels, verbose)
%
%   Inputs
%     designation     4-character string, e.g. "2412", or a 1x3 numeric
%                     [m, p, t] as fractions (e.g. [0.02 0.4 0.12])
%     alpha_deg_list  vector of angles of attack to sweep [deg]. Default
%                     -4:1:10.
%     n_panels        panel count (even). Default 160.
%     verbose         true to print the self-consistency check per alpha.
%                     Default true.
%
%   Output struct
%     .alpha_deg, .CL_kj, .CL_cp, .CD_cp, .Cm_c4   1xN_alpha each
%     .CLa_per_rad     lift-curve slope, least-squares fit over the linear
%                      (|alpha| small) portion of the sweep
%     .alpha0_deg      zero-lift angle, from the same fit
%     .Cm_c4_mean      mean quarter-chord moment over the linear range
%                      (should be close to constant for a fixed-camber
%                      section -- this constancy is itself another
%                      consistency check, independent of the CL cross-check)
%     .max_CL_CP_mismatch_pct   worst-case |CL_kj - CL_cp|/|CL_kj| over the
%                      sweep, flagged loudly if above 5% -- increase
%                      n_panels or treat the result with suspicion
%
%   THIS IS A CONCEPTUAL-DESIGN CROSS-CHECK TOOL, not a replacement for the
%   transonic supercritical section the wing is actually designed around.
%   Its job in this framework: analyze arbitrary NACA 4-digit sections so a
%   reader can sanity-check the thin-airfoil-style camber/thickness
%   assumptions (Cl_alpha, alpha0, Cm_c4) the 3D VLM in CcaAero/aero_drag.m
%   uses, against an independent inviscid panel solution, and explore how
%   much section choice moves those three numbers before committing to one.
%   It is INCOMPRESSIBLE and INVISCID: no drag, no stall, no compressibility
%   correction is applied here (Prandtl-Glauert can be applied by the
%   caller: CLa_compressible = CLa_incompressible / sqrt(1-M^2)).

    arguments
        designation
        alpha_deg_list (1,:) double = -4:1:10
        n_panels (1,1) double {mustBePositive, mustBeInteger} = 160
        verbose (1,1) logical = true
    end

    if isstring(designation) || ischar(designation)
        d = char(designation);
        if numel(d) ~= 4 || any(~isstrprop(d, 'digit'))
            error('naca_panel_method:BadDesignation', ...
                'A string designation must be exactly 4 digits, e.g. "2412".');
        end
        m = str2double(d(1))/100;
        p = str2double(d(2))/10;
        t = str2double(d(3:4))/100;
    else
        mpt = designation;
        m = mpt(1); p = mpt(2); t = mpt(3);
    end

    [~, ~, panel] = naca4_coordinates(m, p, t, n_panels);

    n_a = numel(alpha_deg_list);
    CL_kj = zeros(1, n_a); CL_cp = zeros(1, n_a);
    CD_cp = zeros(1, n_a); Cm_c4 = zeros(1, n_a);
    mismatch_pct = zeros(1, n_a);

    for i = 1:n_a
        r = napm_solve(panel, alpha_deg_list(i));
        CL_kj(i) = r.CL_kj;
        CL_cp(i) = r.CL_cp;
        CD_cp(i) = r.CD_cp;
        Cm_c4(i) = r.Cm_c4;
        % Relative to max(|CL|, 0.1): near the zero-lift angle CL -> 0 and a
        % plain relative error blows up on tiny absolute differences.
        mismatch_pct(i) = 100*abs(r.CL_kj - r.CL_cp)/max(abs(r.CL_kj), 0.1);
        if verbose
            fprintf(['alpha=%6.2f deg   CL_kj=%7.4f   CL_cp=%7.4f   ', ...
                'CD_cp(~0 check)=%8.5f   Cm_c4=%7.4f   mismatch=%5.2f%%\n'], ...
                alpha_deg_list(i), r.CL_kj, r.CL_cp, r.CD_cp, r.Cm_c4, mismatch_pct(i));
        end
    end

    % Linear-range fit: |alpha| <= 6 deg, away from likely stall/separation
    lin = abs(alpha_deg_list) <= 6;
    if nnz(lin) < 2
        lin = true(size(alpha_deg_list));
    end
    p_fit = polyfit(deg2rad(alpha_deg_list(lin)), CL_kj(lin), 1);
    CLa = p_fit(1);
    alpha0 = -p_fit(2)/p_fit(1);

    result.alpha_deg = alpha_deg_list;
    result.CL_kj = CL_kj;
    result.CL_cp = CL_cp;
    result.CD_cp = CD_cp;
    result.Cm_c4 = Cm_c4;
    result.CLa_per_rad = CLa;
    result.alpha0_deg = rad2deg(alpha0);
    result.Cm_c4_mean = mean(Cm_c4(lin));
    result.max_CL_CP_mismatch_pct = max(mismatch_pct);
    result.panel = panel;
    result.designation = designation;

    if verbose
        fprintf('\n--- %s summary --------------------------------------\n', string(designation));
        fprintf('  CLa  = %.3f /rad  (%.3f /deg)\n', CLa, CLa*pi/180);
        fprintf('  alpha0 = %.2f deg\n', result.alpha0_deg);
        fprintf('  Cm_c4 (mean, linear range) = %.4f\n', result.Cm_c4_mean);
        fprintf('  worst CL_kj vs CL_cp mismatch = %.2f%%', result.max_CL_CP_mismatch_pct);
        if result.max_CL_CP_mismatch_pct > 5
            fprintf('   <-- ABOVE 5%%, treat this case with suspicion\n');
        else
            fprintf('   (OK)\n');
        end
    end
end
