function ok = design_point_check(WS_point, TW_point, WS_vec, TW_curves, WS_max_landing, names)
%DESIGN_POINT_CHECK  Verify a chosen (W/S, T/W) design point satisfies
%   EVERY individual constraint curve (T/W >= each curve's lower bound at
%   that W/S, by interpolation) AND the landing wing-loading cap, and
%   prints a clear pass/fail line per constraint -- the diagnostic a
%   sizing loop should call right after picking a design point off
%   matching_envelope.m, so a violation is caught with a NAME attached
%   rather than just "somewhere on the envelope".

    arguments
        WS_point (1,1) double
        TW_point (1,1) double
        WS_vec (1,:) double
        TW_curves cell
        WS_max_landing (1,1) double
        names (1,:) cell = {}
    end

    n_curves = numel(TW_curves);
    if isempty(names)
        names = arrayfun(@(k) sprintf('constraint_%d', k), 1:n_curves, 'UniformOutput', false);
    end

    ok = true;

    if WS_point > WS_max_landing
        fprintf('[FAIL] landing wing-loading cap: W/S = %.2f > %.2f psf allowed\n', ...
            WS_point, WS_max_landing);
        ok = false;
    else
        fprintf('[ OK ] landing wing-loading cap: W/S = %.2f <= %.2f psf\n', ...
            WS_point, WS_max_landing);
    end

    for k = 1:n_curves
        TW_req = interp1(WS_vec, TW_curves{k}, WS_point, 'linear', 'extrap');
        if TW_point + 1e-9 < TW_req
            fprintf('[FAIL] %-22s requires T/W >= %.4f, design point has %.4f\n', ...
                names{k}, TW_req, TW_point);
            ok = false;
        else
            fprintf('[ OK ] %-22s requires T/W >= %.4f, design point has %.4f\n', ...
                names{k}, TW_req, TW_point);
        end
    end
end
