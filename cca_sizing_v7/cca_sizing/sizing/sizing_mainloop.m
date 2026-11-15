function result = sizing_mainloop(geom, aero, prop, weights, conditions, missions, W_TO_guess, opts)
%SIZING_MAINLOOP  Fixed-point TOGW closure, under-relaxed, calling
%   sizing_pass.m once per iteration until W_TO stops moving (or raising
%   a clear closure-failure error, mirroring the reference TTPA code's
%   sizing_pass:closureInfeasible-style diagnostics -- a non-convergent
%   closure is a result to report, not to loop on silently forever).
%
%   opts (struct, optional): .relax (default 0.5), .tol_rel (default
%   1e-4), .max_iter (default 50), .WS_vec (default linspace(40,140,100)),
%   .verbose (default true).

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        weights (1,1) CcaWeights
        conditions (1,:) struct
        missions (1,:) struct
        W_TO_guess (1,1) double {mustBePositive}
        opts struct = struct()
    end

    relax    = getdef(opts, 'relax', 0.5);
    tol_rel  = getdef(opts, 'tol_rel', 1e-4);
    max_iter = getdef(opts, 'max_iter', 50);
    WS_vec   = getdef(opts, 'WS_vec', linspace(40, 140, 100));
    verbose  = getdef(opts, 'verbose', true);

    W_TO = W_TO_guess;
    history = repmat(struct('iter',0,'W_TO',0,'W_TO_new',0,'rel_change',0), 1, max_iter);

    for iter = 1:max_iter
        p = sizing_pass(geom, aero, prop, weights, W_TO, conditions, missions, WS_vec, false);

        rel_change = abs(p.W_TO_new - W_TO) / W_TO;
        history(iter) = struct('iter', iter, 'W_TO', W_TO, 'W_TO_new', p.W_TO_new, ...
            'rel_change', rel_change);

        if verbose
            fprintf('iter %2d:  W_TO = %8.1f lbf  ->  W_TO_new = %8.1f lbf  (rel change %.4f%%)  S_ref=%.1f ft^2  T_SL=%.0f lbf  spot=%.3f\n', ...
                iter, W_TO, p.W_TO_new, 100*rel_change, p.S_ref, p.T_SL, p.spot_factor);
        end

        if rel_change < tol_rel
            % HARD CARRIER GATE on the converged design (see spot_factor_check.m)
            spot_factor_check(geom);
            result.converged = true;
            result.n_iter = iter;
            result.W_TO = p.W_TO_new;
            result.final_pass = p;
            result.history = history(1:iter);
            return;
        end

        W_TO = W_TO + relax*(p.W_TO_new - W_TO);
    end

    error('sizing_mainloop:NotConverged', ...
        ['TOGW closure did not converge in %d iterations (last relative change ', ...
         '%.4f%%, tol %.4f%%). Try a smaller relax factor, a better initial guess, ', ...
         'or check for an oscillating/infeasible constraint set.'], ...
        max_iter, 100*rel_change, 100*tol_rel);
end


function v = getdef(s, name, default)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end
