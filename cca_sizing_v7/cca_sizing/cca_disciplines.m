function disc = cca_disciplines(json_path, W_TO_guess, WS_guess, mission_name)
%CCA_DISCIPLINES  Wires up every discipline object from one requirements
%   JSON, in dependency order, exactly the role the reference TTPA
%   framework's ttpa_disciplines.m played: ONE place that knows the
%   construction order (prop before geom, since geom needs the injected
%   engine for nacelle sizing; geom and prop before aero/weights) so
%   run_demo.m and sizing_mainloop.m callers don't have to.
%
%   geom.S_ref is seeded from (W_TO_guess, WS_guess) as a STARTING guess
%   only -- sizing_mainloop.m immediately resizes it every iteration from
%   the actual constraint-analysis design point; this just has to be
%   finite and roughly sane so the first iteration's CD0/Mdd evaluation
%   is not nonsense.

    arguments
        json_path {mustBeTextScalar, mustBeNonzeroLengthText}
        W_TO_guess (1,1) double {mustBePositive} = 5000
        WS_guess (1,1) double {mustBePositive} = 70
        mission_name {mustBeTextScalar, mustBeNonzeroLengthText} = "carrier_strike"
    end

    prop = CcaProp(json_path);
    geom = CcaGeom(json_path, prop);
    geom.S_ref = W_TO_guess / WS_guess;

    aero = CcaAero(geom);
    weights = CcaWeights(json_path, geom, prop);

    conditions = ConstraintSetImporter.read_conditions(json_path);
    profile = MissionProfileReader.read_profile(json_path, mission_name);

    disc.geom = geom;
    disc.aero = aero;
    disc.prop = prop;
    disc.weights = weights;
    disc.conditions = conditions;
    disc.missions = profile.segments;
    disc.W_TO_guess = W_TO_guess;
end
