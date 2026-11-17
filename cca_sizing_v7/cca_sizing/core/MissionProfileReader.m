classdef MissionProfileReader
%MISSIONPROFILEREADER  Reads one named mission profile from a requirements JSON.
%
%   Generic Layer-1 utility -- the mission-analysis analogue of
%   ConstraintSetImporter. Reads a top-level "missions" object keyed by
%   profile name, each profile carrying mission-level scalars and an
%   ordered "segments" array. Each segment carries REQUIREMENT data only
%   (type, end-of-segment flight condition, and whichever of
%   distance_nm/time_min/mach applies). It carries NO discipline-owned
%   quantity.

    methods (Static)

        function profile = read_profile(json_path, profile_name)
            arguments
                json_path    (1,1) string {mustBeNonzeroLengthText}
                profile_name (1,1) string {mustBeNonzeroLengthText}
            end

            if ~isfile(json_path)
                error('MissionProfileReader:fileNotFound', ...
                    'Mission requirements JSON not found: "%s".', json_path);
            end

            raw = jsondecode(fileread(json_path));

            if ~isfield(raw, 'missions')
                error('MissionProfileReader:missingMissionsBlock', ...
                    ['Requirements JSON "%s" has no top-level "missions" block.'], json_path);
            end

            key = char(profile_name);
            if ~isfield(raw.missions, key)
                avail = MissionProfileReader.profile_names(raw.missions);
                error('MissionProfileReader:profileNotFound', ...
                    'Mission profile "%s" is not in "%s". Available profiles: %s.', ...
                    key, json_path, strjoin(avail, ', '));
            end

            profile = raw.missions.(key);

            if ~isfield(profile, 'segments') || isempty(profile.segments)
                error('MissionProfileReader:noSegments', ...
                    'Mission profile "%s" has no non-empty "segments" array.', key);
            end

            profile.segments = json_as_struct_array(profile.segments);

            for i = 1:numel(profile.segments)
                if ~isfield(profile.segments(i), 'type') ...
                        || isempty(profile.segments(i).type) ...
                        || strlength(string(profile.segments(i).type)) == 0
                    error('MissionProfileReader:segmentMissingType', ...
                        'Segment %d of profile "%s" has no "type" field.', i, key);
                end
            end

            profile.name = string(profile_name);
        end

    end

    methods (Static, Access = private)

        function names = profile_names(missions)
            f = string(fieldnames(missions));
            names = f(~startsWith(f, "_") & ~startsWith(f, "x_"));
        end

    end

end
