function out = run_constraints(geom, aero, prop, conditions, WS_vec, make_plot)
%RUN_CONSTRAINTS  Top-level constraint-analysis driver: dispatches every
%   condition in `conditions` (from ConstraintSetImporter/get_con.m) to
%   its matching constraint_*.m by con.type, builds the T/W curve set
%   (or the landing W/S cap), combines them with matching_envelope.m, and
%   optionally plots. This is the function sizing_pass.m calls each
%   iteration to get the current (WS_design, TW_design) to size the wing
%   and engine from.

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        conditions (1,:) struct
        WS_vec (1,:) double {mustBePositive} = linspace(40, 140, 100)
        make_plot (1,1) logical = false
    end

    TW_curves = {};
    names = {};
    WS_max_landing = inf;

    for i = 1:numel(conditions)
        con = get_con(i, conditions);   % normalize raw JSON fields
                                         % (altitude_ft -> alt, defaults
                                         % filled in) -- see get_con.m
        switch string(con.type)
            case "cruise"
                TW_curves{end+1} = constraint_cruise(geom, aero, prop, con, WS_vec); %#ok<AGROW>
                names{end+1} = con.name; %#ok<AGROW>
            case "dash"
                TW_curves{end+1} = constraint_dash(geom, aero, prop, con, WS_vec); %#ok<AGROW>
                names{end+1} = con.name; %#ok<AGROW>
            case "climb"
                TW_curves{end+1} = constraint_climb(geom, aero, prop, con, WS_vec); %#ok<AGROW>
                names{end+1} = con.name; %#ok<AGROW>
            case "takeoff"
                TW_curves{end+1} = constraint_takeoff(geom, aero, prop, con, WS_vec); %#ok<AGROW>
                names{end+1} = con.name; %#ok<AGROW>
            case "landing"
                WS_max_landing = min(WS_max_landing, constraint_landing(geom, aero, con));
            otherwise
                error('run_constraints:UnknownConditionType', ...
                    'Unknown constraint condition type "%s" (name "%s").', con.type, con.name);
        end
    end

    if isinf(WS_max_landing)
        error('run_constraints:NoLandingCondition', ...
            'No "landing" condition was found -- the matching diagram needs a landing wing-loading cap to pick a finite design point.');
    end

    env = matching_envelope(WS_vec, TW_curves, WS_max_landing);

    if make_plot
        plot_matching_diagram(WS_vec, TW_curves, names, WS_max_landing, ...
            env.WS_design, env.TW_design);
    end

    out = env;
    out.names = names;
    out.TW_curves = TW_curves;
end
