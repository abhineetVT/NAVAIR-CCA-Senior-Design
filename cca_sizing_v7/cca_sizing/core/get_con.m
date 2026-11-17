function [con] = get_con(con_no, cons)
%GET_CON  One constraint condition out of the constraint set.
%
%   con = get_con(con_no, cons) pulls one CONDITION out of the constraint
%   set ConstraintSetImporter.read_conditions returned, filling in defaults
%   for the keys that do not apply to every condition type.
%
%   Requirement keys, read directly and left empty ([]) when absent:
%       distance_ft    field length (catapult stroke / arrest run) [ft]
%       G              required climb gradient [-]
%       mach           flight Mach number of the condition [-]
%       n_z            load factor of a sustained-turn condition [-]
%       V_app_kts      max carrier approach speed [kt]
%
%   Keys with defaults, read through get_field:
%       config              "clean"
%       beta                1.0      W at the condition / W_TO
%       thrust_setting      1.0      throttle fraction of the rated rating
%       oei                 false    one engine inoperative
%       max_continuous      false    military/continuous rather than max AB
%       stores_present      true     external stores still carried (drag)

    con.name = string(cons(con_no).name);
    con.type = string(cons(con_no).type);
    con.alt  = cons(con_no).altitude_ft;

    con.distance_ft = get_field(cons(con_no), 'distance_ft', []);
    con.G           = get_field(cons(con_no), 'G',           []);
    con.mach        = get_field(cons(con_no), 'mach',        []);
    con.n_z         = get_field(cons(con_no), 'n_z',         []);
    con.V_app_kts   = get_field(cons(con_no), 'V_app_kts',   []);

    con.config         = string(get_field(cons(con_no), 'config', "clean"));
    con.beta           = get_field(cons(con_no), 'beta',           1.0);
    con.thrust_setting = get_field(cons(con_no), 'thrust_setting', 1.0);
    con.rating         = string(get_field(cons(con_no), 'rating', "max"));   % "max" (dry) or "ab"
    con.oei            = logical(get_field(cons(con_no), 'oei',            false));
    con.max_continuous = logical(get_field(cons(con_no), 'max_continuous', false));
    con.stores_present = logical(get_field(cons(con_no), 'stores_present', true));

    % carrier-specific knobs used only by constraint_takeoff.m / constraint_landing.m
    con.cat_credit      = get_field(cons(con_no), 'cat_credit',      0.35);
    con.approach_margin = get_field(cons(con_no), 'approach_margin', 1.3);

end

%% Supporting Functions
function [val] = get_field(c, name, default)
    if isfield(c, name) && ~isempty(c.(name))
        val = c.(name);
    else
        val = default;
    end
end
