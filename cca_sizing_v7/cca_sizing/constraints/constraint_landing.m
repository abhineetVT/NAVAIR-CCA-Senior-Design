function WS_max = constraint_landing(geom, aero, con)
%CONSTRAINT_LANDING  Arrested-landing MAXIMUM wing loading (a vertical line
%   on the matching diagram, not a T/W curve -- landing distance/approach
%   speed is a function of W/S and CLmax only, not of thrust).
%
%   Per the project scope, arresting-gear energy absorption and hook loads
%   are NOT modeled. This constraint instead enforces the classical
%   APPROACH-SPEED limit [Raymer 6th ed. Eq. 5.6-class stall-margin
%   relation], using con.V_app_kts (the required max approach speed, a
%   carrier-ops number driven by the arresting gear's design speed, which
%   is therefore where that carrier-specific limit actually enters this
%   framework):
%       W/S_max = 0.5 * rho * V_app^2 * CLmax_land / k_app^2
%   with k_app (con.approach_margin, default 1.3) the standard
%   stall-speed margin V_app = k_app * V_stall.

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        con (1,1) struct
    end

    state = get_state(con.alt, 0.05);
    V_app_fps = con.V_app_kts * 1.68781;

    k_app = 1.3;
    if isfield(con, 'approach_margin'), k_app = con.approach_margin; end

    con_land = con;
    con_land.config = "landing";
    CLmax_land = aero.get_CLmax(state, con_land);

    WS_max = 0.5 * state.rho * V_app_fps^2 * CLmax_land / k_app^2;
end
