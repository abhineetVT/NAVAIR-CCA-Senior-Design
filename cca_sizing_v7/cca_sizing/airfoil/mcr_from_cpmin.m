function M = mcr_from_cpmin(cp0_min)
%MCR_FROM_CPMIN  Critical Mach number from the incompressible minimum
%   pressure coefficient.
%
%   The incompressible Cp is corrected to Mach M with the Karman-Tsien rule
%       Cp(M) = Cp0 / ( beta + (M^2/(1+beta)) * Cp0/2 ),  beta = sqrt(1-M^2)
%   and the section is critical where Cp(M) equals the sonic value
%       Cp* (M) = 2/(gamma M^2) * ( ((1 + 0.2 M^2)/1.2)^3.5 - 1 ),  gamma = 1.4.
%   M is found by scanning upward from 0.30 for the FIRST crossing, which
%   avoids the Karman-Tsien singularity that appears near M = 1 for strong
%   suction. Returns NaN if no crossing occurs below M = 0.98 (the section
%   is effectively not critical in the subsonic range).

    arguments
        cp0_min (1,1) double
    end

    Ms = (0.30:0.001:0.98)';
    beta = sqrt(1 - Ms.^2);
    cp_kt   = cp0_min ./ (beta + (Ms.^2./(1 + beta)) * cp0_min/2);
    cp_star = 2./(1.4*Ms.^2) .* (((1 + 0.2*Ms.^2)/1.2).^3.5 - 1);
    f = cp_kt - cp_star;

    i = find(f <= 0, 1, 'first');
    if isempty(i)
        M = NaN;
    elseif i == 1
        M = Ms(1);
    else
        M = Ms(i-1) + (Ms(i) - Ms(i-1)) * f(i-1)/(f(i-1) - f(i));
    end
end
