function T = airfoil_transonic(foil, alphas, n_panels, make_plot)
%AIRFOIL_TRANSONIC  Estimate critical and drag-divergence Mach number of
%   any airfoil from its coordinates, using the vortex panel solver.
%
%   T = airfoil_transonic(foil, alphas, n_panels, make_plot)
%
%   foil       one of:
%                "naca65a210"   a file name in airfoil/airfoil_data/ (.dat)
%                "C:\path\my_foil.dat"   any Selig-format coordinate file
%                "2412"         a NACA 4-digit designation
%                an Nx2 matrix of [x z] coordinates
%   alphas     angles of attack to sweep [deg], default -2:0.5:6
%   n_panels   panel count, default 200
%   make_plot  plot Mcr and Mdd against CL, default true
%
%   Returns a table with, per angle of attack: alpha, CL_inc (incompressible
%   lift coefficient), CL_Mcr (lift at the critical Mach number), Cp_min
%   (incompressible), Mcr, Mdd and kappaA_est. Angles where the section is
%   never critical below M = 0.98 have NaN in the Mach columns.
%
%   METHOD (a conceptual-design ESTIMATE, not CFD)
%     1. Inviscid incompressible vortex-panel solution -> Cp distribution.
%     2. Karman-Tsien compressibility correction of the minimum Cp, and the
%        sonic Cp*(M), give the critical Mach number Mcr (mcr_from_cpmin.m).
%     3. Drag divergence from Lock's relation: with wave drag
%        Cdw = 20 (M - Mcr)^4, the slope dCd/dM reaches 0.1 at
%            Mdd = Mcr + (0.1/80)^(1/3) = Mcr + 0.1077.
%     4. The Korn technology factor that this Mdd implies for an UNSWEPT
%        section:  kappaA_est = Mdd + t/c + CL/10   (inverting the Korn
%        equation used in CcaGeom.Mdd with sweep = 0).
%
%   HOW FAR TO TRUST IT.  It is inviscid, ignores the boundary layer and the
%   shock itself, and its Lock offset is generous. Run on NACA 6-series
%   sections it gives kappaA_est near 0.97, while the usual rule of thumb for
%   that family is about 0.87. So use it to COMPARE foils (thickness,
%   camber, family) and to see how Mcr falls with CL; for the sizing JSON
%   keep kappaA at your best data-backed value (0.87 is the common figure
%   for 6-series sections). Blunt-trailing-edge foils (supercritical
%   sections) are not handled well -- see repanel_airfoil.m.

    arguments
        foil
        alphas (1,:) double = -2:0.5:6
        n_panels (1,1) double {mustBePositive, mustBeInteger} = 200
        make_plot (1,1) logical = true
    end

    % ---- resolve the input into a closed contour + panel set ------------
    label = "";
    if isnumeric(foil)
        [x, z] = repanel_airfoil(foil, n_panels);
        label = "custom coordinates";
    else
        name = char(string(foil));
        if numel(name) == 4 && all(isstrprop(name, 'digit'))
            [x, z] = naca4_coordinates(str2double(name(1))/100, ...
                str2double(name(2))/10, str2double(name(3:4))/100, n_panels);
            label = "NACA " + string(name);
        else
            if isfile(name)
                file = name;
            else
                here = fileparts(mfilename('fullpath'));
                file = fullfile(here, 'airfoil_data', [name '.dat']);
                if ~isfile(file)
                    avail = dir(fullfile(here, 'airfoil_data', '*.dat'));
                    error('airfoil_transonic:NotFound', ...
                        'Could not find "%s". Bundled foils: %s', name, ...
                        strjoin(erase(string({avail.name}), '.dat'), ', '));
                end
            end
            [x, z] = repanel_airfoil(read_airfoil_dat(file), n_panels);
            label = string(name);
        end
    end
    panel = panels_from_xz(x, z);

    % thickness ratio from the contour (upper minus lower at same x)
    nh = (numel(x) - 1)/2;
    xl = x(1:nh+1);   zl = z(1:nh+1);          % TE -> LE, lower
    xu = x(nh+1:end); zu = z(nh+1:end);        % LE -> TE, upper
    tc = max(interp1(xu, zu, linspace(0, 1, 400), 'pchip') - ...
             interp1(fliplr(xl), fliplr(zl), linspace(0, 1, 400), 'pchip'));

    % ---- sweep alpha -----------------------------------------------------
    n = numel(alphas);
    CL_inc = zeros(n,1); CL_Mcr = nan(n,1); Cpmin = zeros(n,1);
    Mcr = nan(n,1); Mdd = nan(n,1); kappa = nan(n,1);

    for i = 1:n
        r = napm_solve(panel, alphas(i));
        CL_inc(i) = r.CL_kj;
        Cpmin(i)  = min(r.Cp);
        Mcr(i) = mcr_from_cpmin(Cpmin(i));
        if ~isnan(Mcr(i))
            Mdd(i) = Mcr(i) + (0.1/80)^(1/3);
            beta = sqrt(1 - Mcr(i)^2);
            CL_Mcr(i) = CL_inc(i) / (beta + (Mcr(i)^2/(1 + beta))*CL_inc(i)/2);
            kappa(i)  = Mdd(i) + tc + CL_Mcr(i)/10;
        end
    end

    T = table(alphas(:), CL_inc, CL_Mcr, Cpmin, Mcr, Mdd, kappa, ...
        'VariableNames', {'alpha_deg','CL_inc','CL_Mcr','Cp_min','Mcr','Mdd','kappaA_est'});

    fprintf('\n%s   (t/c = %.3f, %d panels)\n', label, tc, n_panels);
    disp(T);

    % summary at a few lift coefficients
    ok = ~isnan(T.Mcr);
    if nnz(ok) >= 2
        [clu, iu] = unique(T.CL_Mcr(ok));
        mcrv = T.Mcr(ok); mddv = T.Mdd(ok); kv = T.kappaA_est(ok);
        fprintf('  at CL =   Mcr     Mdd    kappaA_est\n');
        for cl = [0.1 0.2 0.3 0.4 0.5]
            if cl >= min(clu) && cl <= max(clu)
                fprintf('   %4.2f    %.3f   %.3f   %.3f\n', cl, ...
                    interp1(clu, mcrv(iu), cl), interp1(clu, mddv(iu), cl), ...
                    interp1(clu, kv(iu), cl));
            end
        end
    end

    if make_plot && nnz(ok) >= 2
        figure('Name', "Transonic estimate: " + label); hold on; grid on; box on;
        plot(T.CL_Mcr(ok), T.Mcr(ok), '-o', 'LineWidth', 1.6, 'DisplayName', 'M_{cr}');
        plot(T.CL_Mcr(ok), T.Mdd(ok), '-s', 'LineWidth', 1.6, 'DisplayName', 'M_{dd} (Lock)');
        xlabel('C_L at M_{cr}'); ylabel('Mach number');
        title("Critical and drag-divergence Mach: " + label, 'Interpreter', 'none');
        legend('Location', 'best'); hold off;
    end
end
