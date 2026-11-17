function xy = read_airfoil_dat(path)
%READ_AIRFOIL_DAT  Read a Selig-format airfoil coordinate file (.dat).
%
%   xy = read_airfoil_dat(path) returns an Nx2 matrix [x z]. A leading
%   text line (the airfoil name) is skipped automatically. This is the
%   format used by the UIUC airfoil database and airfoiltools.com: points
%   run from the trailing edge along the upper surface to the leading edge
%   and back along the lower surface. (repanel_airfoil.m accepts either
%   ordering.)

    arguments
        path {mustBeTextScalar, mustBeNonzeroLengthText}
    end

    lines = splitlines(string(fileread(path)));
    xy = zeros(0, 2);
    for i = 1:numel(lines)
        v = sscanf(char(lines(i)), '%f');
        if numel(v) >= 2
            xy(end+1, :) = v(1:2)'; %#ok<AGROW>
        end
    end
    if size(xy, 1) < 10
        error('read_airfoil_dat:TooFewPoints', ...
            'Only %d coordinate rows were read from "%s".', size(xy,1), path);
    end
end
