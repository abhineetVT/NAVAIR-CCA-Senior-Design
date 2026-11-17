function facets = build_facet_model(geom)
%BUILD_FACET_MODEL  Purely-geometric flat-facet model for the horizontal-
%   plane (elevation = 0, i.e. radar at the same altitude as the
%   aircraft) monostatic RCS sweep in rcs_estimate.m.
%
%   SCOPE / WHY ONLY THESE FACETS.  This is a feasibility-level, purely
%   geometric tool (no materials, no RAM coatings, no cavity/duct
%   diffraction, no edge-wave/GTD terms for the wing's leading/trailing
%   edges) -- physical-optics flat-PLATE theory. A thin, nearly-horizontal
%   lifting surface (the wing, and a horizontal tail if present) has its
%   own flat-plate normal pointing mostly +/-Z (UP/DOWN), so it has almost
%   no specular return toward a radar sitting IN THE AIRCRAFT'S OWN
%   HORIZONTAL PLANE -- its big flash shows up looking down/up at the
%   aircraft, a different (elevation) cut this tool does not sweep. What
%   DOES dominate the horizontal-plane (azimuth) RCS pattern, and is
%   exactly the set of design choices this project is asking about
%   (number/type of tail, store carriage), is:
%     - fuselage side panels (broadside flash near the beam, phi=90 deg)
%     - fuselage nose/tailcone taper panels (smaller, angle-shifted flashes)
%     - vertical-tail panel(s) -- BIG broadside flashes for a
%       conventional/t_tail single fin or an UNTOED twin_vertical pair;
%       toe-in (twin_vertical) or cant (v_tail) rotates each panel's
%       normal and visibly moves/splits/shrinks that flash -- the classic
%       geometric reason low-RCS designs use canted/toed fins or none at
%       all (tail_type = "none")
%     - the inlet face cavity, approximated as a single flat disk-area
%       facet facing forward (and, loosely, an exhaust facet facing aft)
%       -- the classic big nose-on/tail-on engine-face spike
%     - EXTERNAL stores, approximated as small flat side-facing facets per
%       store (their own flat/box shape presents extra broadside area an
%       internal bay does not) -- this is the one place the stores
%       configuration choice shows up geometrically in RCS, consistent
%       with "purely geometric" scope (no attempt to model a store's
%       actual fin/body scattering in detail).
%
%   Each facet: .name, .area_ft2, .char_length_ft (the dimension governing
%   the specular lobe's angular WIDTH in this cut), .normal_az_deg
%   (outward normal direction, degrees from the nose/+X axis, 0=nose,
%   90=right wingtip side, 180=tail, 270/-90=left side).

    arguments
        geom (1,1) CcaGeom
    end

    facets = struct('name',{},'area_ft2',{},'char_length_ft',{},'normal_az_deg',{});

    % --- fuselage sides (constant section only -- see file header) ------
    A_side = geom.h_fus * geom.l_cabin;
    facets(end+1) = mkfacet('fuselage_side_R', A_side, geom.l_cabin, 90);
    facets(end+1) = mkfacet('fuselage_side_L', A_side, geom.l_cabin, -90);

    % --- nose taper panels, normal canted in from +/-90 by the taper ----
    nose_half_angle = atand( (geom.w_fus/2) / max(geom.l_nose,1) );
    A_nose = geom.h_fus * geom.l_nose;
    facets(end+1) = mkfacet('nose_taper_R', A_nose, geom.l_nose, 90 - nose_half_angle);
    facets(end+1) = mkfacet('nose_taper_L', A_nose, geom.l_nose, -(90 - nose_half_angle));

    % --- tailcone taper panels ------------------------------------------
    cone_half_angle = atand( ((geom.w_fus - geom.w_cone_end)/2) / max(geom.l_cone,1) );
    A_cone = geom.h_fus * geom.l_cone;
    facets(end+1) = mkfacet('tailcone_taper_R', A_cone, geom.l_cone, 90 + cone_half_angle);
    facets(end+1) = mkfacet('tailcone_taper_L', A_cone, geom.l_cone, -(90 + cone_half_angle));

    % --- vertical tail panel(s), by tail_type ---------------------------
    switch geom.tail_type
        case {"conventional","t_tail"}
            facets(end+1) = mkfacet('vtail', geom.S_vt_total, sqrt(geom.S_vt_total), 90);
            facets(end+1) = mkfacet('vtail_back', geom.S_vt_total, sqrt(geom.S_vt_total), -90);
        case "twin_vertical"
            toe = geom.twin_vt_toe_deg;
            A_each = geom.S_vt_total / 2;
            facets(end+1) = mkfacet('vtail_R', A_each, sqrt(A_each), 90 - toe);
            facets(end+1) = mkfacet('vtail_L', A_each, sqrt(A_each), -90 + toe);
        case "v_tail"
            cant = geom.vtail_cant_deg;
            A_each = geom.S_vt_total / 2;
            xy_fraction = cosd(cant);   % normal's in-plane (xy) component shrinks with cant
            facets(end+1) = mkfacet('vtail_R', A_each*xy_fraction, sqrt(A_each), 90);
            facets(end+1) = mkfacet('vtail_L', A_each*xy_fraction, sqrt(A_each), -90);
        case "none"
            % no vertical tail panel at all -- nothing added, by design.
    end

    % --- inlet / exhaust cavity face ------------------------------------
    A_inlet = geom.prop.n_engines * pi/4 * geom.d_nacelle^2;
    facets(end+1) = mkfacet('inlet_face', A_inlet, geom.d_nacelle, 0);
    facets(end+1) = mkfacet('exhaust_face', A_inlet, geom.d_nacelle, 180);

    % --- external stores (geometric side-area proxy only) --------------
    if ~geom.is_internal_stores && geom.n_stores > 0
        A_store_each = 0.5 * geom.store_Dq_each;  % crude proxy: half the
                                                    % flat-plate drag area
                                                    % as a broadside RCS area
        n_each_side = ceil(geom.n_stores/2);
        facets(end+1) = mkfacet('stores_R', n_each_side*A_store_each, 3, 90);
        facets(end+1) = mkfacet('stores_L', n_each_side*A_store_each, 3, -90);
    end
end


function f = mkfacet(name, area_ft2, char_length_ft, normal_az_deg)
    f.name = name;
    f.area_ft2 = max(area_ft2, 0);
    f.char_length_ft = max(char_length_ft, 0.1);
    f.normal_az_deg = normal_az_deg;
end
