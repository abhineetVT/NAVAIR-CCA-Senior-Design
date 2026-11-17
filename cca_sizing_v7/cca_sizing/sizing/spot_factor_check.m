function ok = spot_factor_check(geom)
%SPOT_FACTOR_CHECK  Hard carrier spot-factor gate.
%
%   spot_factor = (b_effective * l_fuselage) / reference footprint MUST be <= geom.spot_factor_max
%   (0.80 per the RFP). This is NOT silently corrected by shrinking the
%   wing or growing the fuselage behind the sizing loop's back -- exactly
%   like the reference TTPA code's sizing_pass:closureInfeasible-style
%   errors, a violation STOPS the loop with a clear diagnostic, because a
%   spot-factor violation is a real design decision point (fold more of
%   the span, lower AR, accept a smaller/lighter aircraft, or stretch the
%   fuselage), not something this function should paper over.

    arguments
        geom (1,1) CcaGeom
    end

    if geom.spot_factor_ok
        ok = true;
        return;
    end

    ok = false;
    error('spot_factor_check:Infeasible', ...
        ['Carrier spot factor %.3f exceeds the hard limit %.2f ', ...
         '(b_effective = %.1f ft [fold_fraction = %.2f, unfolded span = %.1f ft], ', ...
         'l_fuselage = %.1f ft, footprint %.0f ft^2 vs reference %.0f ft^2). Reduce wing area/AR, increase fold_fraction credit ', ...
         '(a foldable outer wing panel), or lengthen the fuselage -- this sizing ', ...
         'point is rejected, not auto-corrected.'], ...
        geom.spot_factor, geom.spot_factor_max, geom.b_effective, ...
        geom.fold_fraction, geom.b, geom.l_fus, geom.b_effective*geom.l_fus, geom.spot_reference_area);
end
