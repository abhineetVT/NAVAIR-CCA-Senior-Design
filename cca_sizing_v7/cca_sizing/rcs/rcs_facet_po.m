function sigma_m2 = rcs_facet_po(area_ft2, char_length_ft, normal_az_deg, look_az_deg, lambda_m)
%RCS_FACET_PO  Monostatic physical-optics flat-plate RCS of ONE facet, at
%   ONE look azimuth, in the horizontal (elevation=0) cut.
%
%   sigma = (4*pi*A^2/lambda^2) * cos^2(theta) * sinc^2( k*L*sin(theta)/2 )
%   [standard PO flat-plate monostatic RCS formula, e.g. Knott/Shaeffer/
%   Tuley "Radar Cross Section", or any PO-RCS reference -- the sinc
%   term is the usual simplification keeping only the dominant 1D
%   specular-lobe narrowing along the facet's characteristic length L in
%   the cut plane, dropping the orthogonal in-plane dimension's sinc term
%   (reasonable here since every facet above is modeled as if seen near
%   broadside/along its long axis in this single horizontal cut -- a
%   feasibility-level simplification, consistent with "purely geometric"
%   scope, not a full 2D aperture treatment].
%
%   theta = angle between the look direction and the facet's OUTWARD
%   normal. A facet with |theta| > 90 deg is back-facing (not illuminated
%   from this azimuth) and returns 0.

    arguments
        area_ft2 (1,1) double {mustBeNonnegative}
        char_length_ft (1,1) double {mustBePositive}
        normal_az_deg (1,1) double
        look_az_deg (1,1) double
        lambda_m (1,1) double {mustBePositive}
    end

    if area_ft2 <= 0
        sigma_m2 = 0; return;
    end

    raw = mod(look_az_deg - normal_az_deg + 180, 360) - 180;  % wrap to (-180,180]
    theta_deg = raw;
    if abs(theta_deg) >= 90
        sigma_m2 = 0;
        return;
    end
    theta = deg2rad(theta_deg);

    ft2m = 0.3048;
    A_m2 = area_ft2 * ft2m^2;
    L_m  = char_length_ft * ft2m;

    k = 2*pi/lambda_m;
    X = k*L_m*sin(theta)/2;

    if abs(X) < 1e-9
        sinc_term = 1;
    else
        sinc_term = sin(X)/X;     % unnormalized sinc, no toolbox needed
    end

    sigma_m2 = (4*pi*A_m2^2/lambda_m^2) * cos(theta)^2 * sinc_term^2;
end
