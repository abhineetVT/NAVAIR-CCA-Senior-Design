function panel = panels_from_xz(x, z)
%PANELS_FROM_XZ  Build the panel struct array napm_solve.m expects from a
%   closed contour ordered TE -> lower -> LE -> upper -> TE (as returned by
%   naca4_coordinates.m and repanel_airfoil.m).
%
%   Fields per panel: x1,z1,x2,z2 (endpoints), xm,zm (midpoint), L,
%   phi (inclination), tx,tz (unit tangent), nx,nz (OUTWARD unit normal,
%   the left of travel for this clockwise ordering).

    arguments
        x (1,:) double
        z (1,:) double
    end

    N = numel(x) - 1;
    panel = repmat(struct('x1',0,'z1',0,'x2',0,'z2',0,'xm',0,'zm',0, ...
                           'L',0,'phi',0,'nx',0,'nz',0,'tx',0,'tz',0), 1, N);
    for k = 1:N
        dx = x(k+1) - x(k);
        dz = z(k+1) - z(k);
        L  = hypot(dx, dz);

        panel(k).x1 = x(k);   panel(k).z1 = z(k);
        panel(k).x2 = x(k+1); panel(k).z2 = z(k+1);
        panel(k).xm = 0.5*(x(k) + x(k+1));
        panel(k).zm = 0.5*(z(k) + z(k+1));
        panel(k).L  = L;
        panel(k).phi = atan2(dz, dx);
        panel(k).tx = dx/L;  panel(k).tz = dz/L;
        panel(k).nx = -panel(k).tz;
        panel(k).nz =  panel(k).tx;
    end
end
