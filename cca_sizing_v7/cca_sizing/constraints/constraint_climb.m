function TW = constraint_climb(geom, aero, prop, con, WS_vec)
%CONSTRAINT_CLIMB  Specified climb-gradient T/W lower bound.
%
%   T/W = CD(CL)/CL + G/kT   [small-climb-angle energy balance: thrust
%   overcomes drag AND provides the climb-gradient component of weight,
%   Raymer 6th ed. Eq. 5.14-class relation], where:
%     G        required climb gradient (dh/dx, dimensionless), read from
%              con.G -- e.g. the carrier-suitability single-engine-climb
%              requirement, or a simple en-route second-segment-climb
%              check. con.oei=true drops one engine in prop.thrust_ratio
%              for an engine-out gradient check.
%     CD(CL)/CL   the drag-divided-by-lift term is NOT divided by kT
%              (it's an aerodynamic ratio, altitude-independent at a
%              given CL other than through compressibility, already
%              folded into aero.compute_CD_at via the state argument);
%              only the climb-gradient term needs the thrust-lapse
%              correction, since it's a thrust requirement, not a drag
%              ratio.
    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        con (1,1) struct
        WS_vec (1,:) double {mustBePositive}
    end

    state = get_state(con.alt, con.mach);
    kT = prop.thrust_ratio(state, con);

    CL_vec = WS_vec / state.q;
    TW = zeros(size(WS_vec));
    for i = 1:numel(WS_vec)
        CD = aero.compute_CD_at(state, CL_vec(i), con);
        CD_over_CL = CD / CL_vec(i);
        TW(i) = CD_over_CL + con.G/kT;
    end
end
