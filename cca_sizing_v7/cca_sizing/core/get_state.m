function [state] = get_state(alt_ft, mach)
%GET_STATE  Full flight state at an altitude and Mach, for discipline calls.
%
%   state = get_state(alt_ft)        -- mach defaults to 0 (statics only:
%                                        sigma, rho; used by ground-roll-type
%                                        constraints that do not need a V).
%   state = get_state(alt_ft, mach)  -- also fills V, q, Reynolds-ready mu.
%
%   Thin wrapper around AircraftState that also carries sigma (density
%   ratio) at the top level, since nearly every constraint and mission
%   segment reads it directly.
    arguments
        alt_ft (1,1) double {mustBeNonnegative}
        mach   (1,1) double {mustBeNonnegative} = 0
    end

    atm = AircraftState(alt_ft, mach);

    state.alt   = alt_ft;
    state.mach  = mach;
    state.rho   = atm.rho;
    state.sigma = atm.sigma;
    state.a     = atm.a;
    state.V     = atm.V;
    state.q     = atm.q;
    state.mu    = atm.mu;
    state.atm   = atm;   % full AircraftState object, for Reynolds-number calls
end
