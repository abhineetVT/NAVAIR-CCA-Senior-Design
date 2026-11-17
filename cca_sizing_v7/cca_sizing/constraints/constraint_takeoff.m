function TW = constraint_takeoff(geom, aero, prop, con, WS_vec)
%CONSTRAINT_TAKEOFF  Catapult-assisted takeoff T/W lower bound.
%
%   Per the project scope, this does NOT model catapult stroke energy,
%   shuttle dynamics, or end-speed in any carrier-specific detail. It
%   keeps the classical TAKEOFF PARAMETER form [Raymer 6th ed. Eq. 5.8-
%   class relation, free takeoff roll]:
%       TOP23 = (W/S) / (sigma * CLmax_TO * (T/W))
%       T/W required = (W/S) / (sigma * CLmax_TO * TOP23_allow)
%   and applies a single CATAPULT ENERGY CREDIT FACTOR (con.cat_credit,
%   0 < value <= 1, default 0.35) that scales down the EFFECTIVE ground-
%   roll distance the engine alone has to cover -- i.e. it treats the
%   catapult as supplying (1-cat_credit) of the kinetic energy a free
%   takeoff roll would otherwise need from the engines, which is the one
%   piece of "carrier-ness" this constraint carries. A smaller cat_credit
%   makes the engine do more of the work (less catapult assist assumed);
%   1.0 would mean a free-roll (non-catapult) takeoff.
%
%   TOP23_allow (con.distance_ft, the allowable free-roll-equivalent
%   distance) and CLmax_TO (from aero.get_CLmax with con.config="takeoff")
%   are both requirements-JSON inputs, not fixed here.

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        con (1,1) struct
        WS_vec (1,:) double {mustBePositive}
    end

    state = get_state(con.alt, 0.05);   % takeoff roll, near-zero Mach for sigma
    sigma = state.sigma;
    kT = prop.thrust_ratio(state, con);

    con_to = con;
    con_to.config = "takeoff";
    CLmax_TO = aero.get_CLmax(state, con_to);

    cat_credit = 0.35;
    if isfield(con, 'cat_credit'), cat_credit = con.cat_credit; end
    dist_effective = con.distance_ft * (1 - cat_credit);

    TOP23_allow = dist_effective;  % ft, free-roll-equivalent
    TW = (WS_vec ./ (sigma * CLmax_TO * TOP23_allow)) / kT;
end
