function out = rcs_estimate(geom, lambda_m, az_deg_vec, make_plot)
%RCS_ESTIMATE  Standalone, purely-geometric monostatic RCS-vs-azimuth
%   estimate for the current CcaGeom -- NOT wired into the sizing loop
%   (per project scope: a cross-check/trade tool a user runs by hand on a
%   candidate geometry, not a constraint or objective sizing_pass.m reads
%   or closes on).
%
%   out.az_deg, out.sigma_m2, out.sigma_dBsm   (incoherent sum over every
%   facet from build_facet_model.m, i.e. sigma_total(az) =
%   sum_i sigma_facet_i(az) -- a standard PO simplification that ignores
%   inter-facet phase/interference, appropriate at this feasibility
%   level) plus out.facets (the facet model used, for inspection) and,
%   if make_plot, a polar RCS-vs-azimuth plot in dBsm.
%
%   lambda_m   radar wavelength [m], e.g. ~0.03 m for X-band (10 GHz).
%   az_deg_vec default 0:2:358 (0 = nose-on).

    arguments
        geom (1,1) CcaGeom
        lambda_m (1,1) double {mustBePositive} = 0.03
        az_deg_vec (1,:) double = 0:2:358
        make_plot (1,1) logical = true
    end

    facets = build_facet_model(geom);
    n_az = numel(az_deg_vec);
    sigma_m2 = zeros(1, n_az);

    for j = 1:n_az
        s = 0;
        for i = 1:numel(facets)
            s = s + rcs_facet_po(facets(i).area_ft2, facets(i).char_length_ft, ...
                facets(i).normal_az_deg, az_deg_vec(j), lambda_m);
        end
        sigma_m2(j) = s;
    end

    out.az_deg = az_deg_vec;
    out.sigma_m2 = sigma_m2;
    out.sigma_dBsm = 10*log10(max(sigma_m2, 1e-6));
    out.facets = facets;
    out.lambda_m = lambda_m;

    if make_plot
        figure('Name', 'Geometric RCS estimate (horizontal cut)');
        polarplot(deg2rad(az_deg_vec), out.sigma_dBsm - min(out.sigma_dBsm) + 1);
        title(sprintf('Monostatic RCS vs azimuth (relative, dBsm floor-shifted), \\lambda = %.3f m, tail = %s, stores = %s', ...
            lambda_m, geom.tail_type, geom.store_config));
    end
end
