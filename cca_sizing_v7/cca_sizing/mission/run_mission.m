function result = run_mission(geom, aero, prop, weights, W_TO, segments)
%RUN_MISSION  Sequences a carrier strike profile, segment by segment,
%   tracking weight, fuel burn, time and distance -- the mission-analysis
%   discipline's contribution to the TOGW closure (sizing_pass.m reads
%   result.W_fuel_total from this).
%
%   segments   struct array from MissionProfileReader / get_miss_seg.m,
%              each with .type, .alt, .mach, and EITHER .dist_nm (cruise/
%              dash/climb-to-range legs) OR .time_min (loiter legs), plus
%              .releases_stores (logical).
%
%   STORE RELEASE.  n_stores_present starts at geom.n_stores. The FIRST
%   segment with releases_stores == true drops ALL remaining stores at
%   the START of that segment (both their weight and, for an external
%   configuration, their drag, via con_like.n_stores_present passed into
%   every aero/prop call for every later segment). This is a single
%   simultaneous release, matching how a CCA would deliver its full
%   loadout in one weapons-bay/pylon event rather than one-at-a-time --
%   adequate for the TOGW/range accounting this framework is for; a
%   store-by-store release schedule would be a straightforward extension
%   of this same loop if a later design iteration needs it.
%
%   Returns result with: W_fuel_total, W_TO, W_land (= W_TO - fuel -
%   released stores), t_total_min, dist_total_nm, and .log (one row per
%   segment: type, W_start, W_end, fuel_burn_lbf, time_min, dist_nm,
%   n_stores_present).

    arguments
        geom (1,1) CcaGeom
        aero (1,1) CcaAero
        prop (1,1) PropulsionBase_Jet
        weights (1,1) CcaWeights
        W_TO (1,1) double {mustBePositive}
        segments (1,:) struct
    end

    W_current = W_TO;
    n_stores_present = geom.n_stores;
    W_fuel_total = 0;
    t_total_sec = 0;
    dist_total_ft = 0;
    last_alt_ft = 0;    % carrier deck -- start of mission

    log = repmat(struct('type',"",'W_start',0,'W_end',0,'fuel_burn_lbf',0, ...
        'time_min',0,'dist_nm',0,'n_stores_present',0,'used_ab',false), 1, numel(segments));

    for i = 1:numel(segments)
        seg = get_miss_seg(i, struct('segments', segments));  % normalize
                                         % raw JSON fields (alt_ft -> alt,
                                         % distance_nm -> dist_nm, defaults
                                         % filled in) -- see get_miss_seg.m
        W_seg_start = W_current;

        if isfield(seg,'releases_stores') && seg.releases_stores && n_stores_present > 0
            W_current = W_current - n_stores_present*weights.store_weight_each;
            n_stores_present = 0;
        end

        con_like.n_stores_present = n_stores_present;
        con_like.stores_present = n_stores_present > 0;
        con_like.rating = "max";
        used_ab = false;

        switch string(seg.type)
            case "takeoff"
                [fb, dt, dd] = segment_takeoff_landing("takeoff", W_current);
            case "landing"
                [fb, dt, dd] = segment_takeoff_landing("landing", W_current);
            case "climb"
                [fb, dt, dd] = segment_climb(geom, aero, prop, W_current, ...
                    last_alt_ft, seg.alt, seg.mach, con_like);
            case {"cruise","dash"}
                con_like.rating = seg.rating;
                [fb, dt, dd, used_ab] = segment_cruise(geom, aero, prop, W_current, ...
                    seg.alt, seg.mach, seg.dist_nm, con_like);
            case "loiter"
                [fb, dt, dd] = segment_loiter(geom, aero, prop, W_current, ...
                    seg.alt, seg.mach, seg.time_min, con_like);
            otherwise
                error('run_mission:UnknownSegmentType', ...
                    'Unknown mission segment type "%s".', seg.type);
        end

        W_current = W_current - fb;
        W_fuel_total = W_fuel_total + fb;
        t_total_sec = t_total_sec + dt;
        dist_total_ft = dist_total_ft + dd;
        if ~isnan(seg.alt)
            last_alt_ft = seg.alt;
        end

        log(i).type = string(seg.type);
        log(i).W_start = W_seg_start;
        log(i).W_end = W_current;
        log(i).fuel_burn_lbf = fb;
        log(i).time_min = dt/60;
        log(i).dist_nm = dd/6076.12;
        log(i).n_stores_present = n_stores_present;
        log(i).used_ab = used_ab;

        if ~isfinite(fb) || ~isfinite(W_current)
            error('run_mission:NonFinite', ...
                ['Segment %d (%s) produced a non-finite fuel burn/weight ', ...
                 '(fuel = %g lbf, T_SL = %g lbf, S_ref = %g ft^2). Check the engine ', ...
                 'size and constraint set upstream.'], i, seg.type, fb, prop.T_SL, geom.S_ref);
        end

        if W_current <= 0
            error('run_mission:NegativeWeight', ...
                ['Aircraft weight went to zero or below during segment %d ', ...
                 '(%s) -- this mission profile is infeasible for the ', ...
                 'current W_TO sizing point.'], i, seg.type);
        end
    end

    % combat radius = outbound distance = half of the round-trip distance flown
    % in climb/cruise/dash segments (loiter, takeoff, landing excluded)
    d_leg = 0;
    for k = 1:numel(log)
        if any(log(k).type == ["climb","cruise","dash"])
            d_leg = d_leg + log(k).dist_nm;
        end
    end
    result.radius_nm = d_leg/2;

    result.W_TO = W_TO;
    result.W_fuel_total = W_fuel_total;
    result.W_land = W_current;
    result.t_total_min = t_total_sec/60;
    result.dist_total_nm = dist_total_ft/6076.12;
    result.n_stores_present_end = n_stores_present;
    result.log = log;
end
