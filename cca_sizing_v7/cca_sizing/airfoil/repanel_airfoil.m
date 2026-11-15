function [x, z, info] = repanel_airfoil(xy, n_panels)
%REPANEL_AIRFOIL  Resample an arbitrary airfoil coordinate set onto the
%   cosine-spaced, closed-trailing-edge contour the panel solver expects.
%
%   [x, z, info] = repanel_airfoil(xy, n_panels)
%
%   xy        Nx2 coordinates, either ordering (TE-upper-LE-lower-TE or the
%             reverse), any chord length (normalised to unit chord here).
%   n_panels  number of panels (even), default 200.
%
%   Output x, z are 1x(n_panels+1) rows ordered TE -> lower -> LE -> upper
%   -> TE, matching naca4_coordinates.m. Each surface is interpolated with
%   a shape-preserving cubic (pchip) in sqrt(x), which keeps the leading-
%   edge shape smooth (z ~ sqrt(x) near a round nose).
%
%   info.te_gap is the trailing-edge gap (fraction of chord) BEFORE it was
%   closed. The solver needs a closed trailing edge, so the two TE points
%   are merged at their mean height; a gap above ~0.2% chord (a blunt
%   trailing edge, as on supercritical sections) distorts the aft shape
%   and a warning is issued.

    arguments
        xy (:,2) double
        n_panels (1,1) double {mustBePositive, mustBeInteger} = 200
    end

    % normalise to unit chord with the LE at the origin
    [xmin, i0] = min(xy(:,1));
    xy(:,1) = xy(:,1) - xmin;
    c = max(xy(:,1));
    xy = xy / c;

    s1 = xy(1:i0, :);   s1 = flipud(s1);   % LE -> end of first branch
    s2 = xy(i0:end, :);                    % LE -> end of second branch
    [~, k1] = unique(s1(:,1)); s1 = s1(k1, :);
    [~, k2] = unique(s2(:,1)); s2 = s2(k2, :);

    % identify upper / lower by height at mid-chord
    if interp1(s1(:,1), s1(:,2), 0.5) >= interp1(s2(:,1), s2(:,2), 0.5)
        up = s1; lo = s2;
    else
        up = s2; lo = s1;
    end

    nh = ceil(n_panels/2);
    beta = linspace(0, pi, nh+1)';
    xc = 0.5*(1 - cos(beta));
    s = sqrt(xc);

    zu = pchip(sqrt(up(:,1)), up(:,2), s);
    zl = pchip(sqrt(lo(:,1)), lo(:,2), s);

    info.te_gap = abs(zu(end) - zl(end));
    if info.te_gap > 0.002
        warning('repanel_airfoil:BluntTE', ...
            ['Trailing-edge gap is %.2f%% of chord. It is closed by merging the ', ...
             'two TE points, which distorts the aft shape of blunt-TE (e.g. ', ...
             'supercritical) sections; treat Cp/Mcr results for this foil with caution.'], ...
            100*info.te_gap);
    end

    zte = 0.5*(zu(end) + zl(end));
    zu(end) = zte;  zl(end) = zte;
    zle = 0.5*(zu(1) + zl(1));
    zu(1) = zle;    zl(1) = zle;

    x = [flipud(xc); xc(2:end)]';
    z = [flipud(zl); zu(2:end)]';
end
