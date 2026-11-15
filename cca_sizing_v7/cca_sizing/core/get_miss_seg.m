function [miss_seg] = get_miss_seg(seg_no, miss)
%GET_MISS_SEG  One segment out of the mission profile.
    s = miss.segments(seg_no);

    miss_seg.type      = lower(string(s.type));
    miss_seg.alt       = get_field(s, 'alt_ft',       NaN);
    miss_seg.mach      = get_field(s, 'mach',         NaN);
    miss_seg.time_min  = get_field(s, 'time_min',     NaN);
    miss_seg.dist_nm   = get_field(s, 'distance_nm',  NaN);
    miss_seg.rating    = string(get_field(s, 'rating', "max"));   % "max" dry, "ab", or "auto" (AB only if dry thrust is short)
    miss_seg.config    = string(get_field(s, 'config', "clean"));
    miss_seg.releases_stores = logical(get_field(s, 'releases_stores', false));
end

function [val] = get_field(s, name, default)
    if isfield(s, name) && ~isempty(s.(name))
        val = s.(name);
    else
        val = default;
    end
end
