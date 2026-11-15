function TW = constraint_dash(geom, aero, prop, con, WS_vec)
%CONSTRAINT_DASH  Mach-0.85 dash-speed T/W lower bound. Same level-flight
%   physics as constraint_cruise.m (see level_flight_TW_required.m); what
%   makes this THE dash constraint is simply that con.mach = 0.85 (or
%   whatever the RFP's goal dash Mach is set to in the requirements JSON).
%   This is normally the TIGHTEST (highest T/W) of the cruise-type
%   constraints and, together with the carrier spot-factor gate, is the
%   requirement driving wing sweep via CcaGeom.required_sweep_deg.
%
%   This constraint is evaluated with con.stores_present/con.
%   n_stores_present taken at face value from the condition read in
%   get_con.m -- i.e. the requirements JSON decides whether dash capability
%   is required WITH stores still aboard (a harder, more honest
%   requirement for a strike aircraft returning from a target, or before
%   weapons release) or clean (after release). Both are legitimate dash
%   conditions to check; which one(s) to include is a requirements choice,
%   made in the conditions list, not hard-coded here.
    TW = level_flight_TW_required(geom, aero, prop, con, WS_vec);
end
