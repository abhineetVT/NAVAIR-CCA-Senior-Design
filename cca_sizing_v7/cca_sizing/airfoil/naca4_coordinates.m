function [x, z, panel] = naca4_coordinates(m, p, t, n_panels)
%NACA4_COORDINATES  Closed-contour panel geometry for a NACA 4-digit airfoil.
%
%   [x, z, panel] = naca4_coordinates(m, p, t, n_panels)
%
%   Inputs (standard NACA 4-digit definitions, e.g. "2412" -> m=0.02, p=0.4,
%   t=0.12; a symmetric section such as "0012" has m=0, p irrelevant):
%     m          maximum camber, fraction of chord [-]  (0.02 for "2412")
%     p          location of maximum camber, fraction of chord [-]
%     t          maximum thickness, fraction of chord [-]
%     n_panels   number of boundary panels (even number recommended)
%
%   Outputs
%     x, z       1x(n_panels+1) boundary coordinates, unit chord, counter-
%                clockwise starting and ending at the trailing edge, going
%                first along the LOWER surface then back along the UPPER
%                surface (the convention the panel-method solver expects:
%                outward normals then point away from the airfoil for a
%                clockwise-looking traverse when the standard sign/rotation
%                in napm_solve.m is used -- see that file's header).
%     panel      struct array, one element per panel, with
%                  .x1,.z1,.x2,.z2   endpoints
%                  .xm,.zm           midpoint (the collocation point)
%                  .L                length
%                  .phi              panel inclination [rad], atan2(dz,dx)
%                  .nx,.nz           outward unit normal
%                  .tx,.tz           unit tangent (from point 1 to point 2)
%
%   Thickness distribution: standard NACA 4-digit closed-trailing-edge form
%       t/c * ( 0.2969 sqrt(xc) - 0.1260 xc - 0.3516 xc^2
%               + 0.2843 xc^3 - 0.1036 xc^4 ) / 0.2
%   (the -0.1036 coefficient, rather than the open-TE -0.1015, closes the
%   trailing edge exactly -- needed for a clean panel method contour).
%   Camber line: the standard two-parabola NACA 4-digit mean line.
%
%   Points are cosine-clustered in chordwise fraction so panels are small
%   near the leading and trailing edges, where curvature and the panel-
%   method solution are most sensitive.

    arguments
        m (1,1) double {mustBeNonnegative}
        p (1,1) double {mustBeNonnegative}
        t (1,1) double {mustBePositive}
        n_panels (1,1) double {mustBePositive, mustBeInteger} = 160
    end

    n_half = n_panels/2;
    if mod(n_panels,2) ~= 0
        n_half = ceil(n_panels/2);
    end

    beta = linspace(0, pi, n_half+1)';
    xc   = 0.5*(1 - cos(beta));          % cosine clustering, 0 -> 1

    % --- thickness distribution (closed trailing edge) -----------------
    tt = (t/0.2) * (0.2969*sqrt(xc) - 0.1260*xc - 0.3516*xc.^2 ...
                     + 0.2843*xc.^3 - 0.1036*xc.^4);

    % --- camber line and its slope --------------------------------------
    zc    = zeros(size(xc));
    dzcdx = zeros(size(xc));
    if m > 0 && p > 0
        fwd = xc < p;
        zc(fwd)    = (m/p^2) * (2*p*xc(fwd) - xc(fwd).^2);
        dzcdx(fwd) = (2*m/p^2) * (p - xc(fwd));
        aft = ~fwd;
        zc(aft)    = (m/(1-p)^2) * ((1 - 2*p) + 2*p*xc(aft) - xc(aft).^2);
        dzcdx(aft) = (2*m/(1-p)^2) * (p - xc(aft));
    end

    theta = atan(dzcdx);

    xu = xc - tt.*sin(theta);
    zu = zc + tt.*cos(theta);
    xl = xc + tt.*sin(theta);
    zl = zc - tt.*cos(theta);

    % --- assemble closed contour: TE -> lower surface -> LE -> upper -> TE
    x = [flipud(xl); xu(2:end)]';
    z = [flipud(zl); zu(2:end)]';

    % --- build panel struct array ---------------------------------------
    N = numel(x) - 1;
    panel = repmat(struct('x1',0,'z1',0,'x2',0,'z2',0,'xm',0,'zm',0, ...
                           'L',0,'phi',0,'nx',0,'nz',0,'tx',0,'tz',0), 1, N);
    for k = 1:N
        x1 = x(k);   z1 = z(k);
        x2 = x(k+1); z2 = z(k+1);
        dx = x2 - x1; dz = z2 - z1;
        L  = hypot(dx, dz);
        phi = atan2(dz, dx);

        panel(k).x1 = x1; panel(k).z1 = z1;
        panel(k).x2 = x2; panel(k).z2 = z2;
        panel(k).xm = 0.5*(x1+x2);
        panel(k).zm = 0.5*(z1+z2);
        panel(k).L  = L;
        panel(k).phi = phi;
        panel(k).tx = dx/L; panel(k).tz = dz/L;
        % OUTWARD normal: tangent rotated +90 deg (to the LEFT of travel).
        % For the TE->lower->LE->upper->TE ordering built above (clockwise),
        % the fluid is on the left of travel, so the left normal points out
        % of the airfoil.
        panel(k).nx = -panel(k).tz;
        panel(k).nz =  panel(k).tx;
    end
end
