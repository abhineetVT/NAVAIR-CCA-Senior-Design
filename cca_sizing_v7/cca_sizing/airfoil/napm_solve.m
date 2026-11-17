function out = napm_solve(panel, alpha_deg)
%NAPM_SOLVE  Constant-strength vortex panel method, one angle of attack.
%
%   out = napm_solve(panel, alpha_deg)
%
%   2D constant-strength vortex panel method [Katz & Plotkin, "Low-Speed
%   Aerodynamics", 2nd ed., Ch. 11]. Each panel carries one unknown vortex
%   sheet strength gamma_j (circulation per unit length, constant over the
%   panel; POSITIVE = CLOCKWISE, i.e. positive lift).
%
%   BOUNDARY CONDITION.  The tangential velocity just INSIDE the body is
%   set to zero at every panel midpoint (the "inner-flow"/Dirichlet-type
%   form). This is a second-kind integral equation and is well conditioned.
%   (An earlier version enforced zero NORMAL velocity instead; that form
%   has a near-null sawtooth mode at the leading edge that is invisible in
%   the total circulation but wrecks the pressures.) The Kutta condition
%   gamma_1 + gamma_N = 0 replaces the equation at one panel near the
%   leading edge, keeping the system square.
%
%   INFLUENCE COEFFICIENTS, closed form.  Transform the field point into
%   the panel's own local axes (x* along the panel, z* to its left). For a
%   unit-strength constant vortex panel from (0,0) to (L,0):
%       u* = (1/2pi) [ atan2(z*, x*-L) - atan2(z*, x*) ]
%       w* = (1/2pi) ln( r2/r1 ),   r1=hypot(x*,z*), r2=hypot(x*-L,z*)
%   On the panel's own control point the limit is u* = +1/2 (just outside,
%   on the left/fluid side) and w* = 0; the INSIDE value is u* = -1/2.
%   The closed-form influence formulas were validated against the exact
%   circular-cylinder solution gamma = 2 U sin(theta).
%
%   GEOMETRY CONVENTION.  Panels run TE -> lower -> LE -> upper -> TE
%   (clockwise), so the fluid is on each panel's LEFT and the outward
%   normal is n = (-t_z, t_x) (set in naca4_coordinates.m).
%
%   CL is reported TWO independent ways, as a built-in self-consistency check
%   (they should agree to about 1-2% for an attached-flow case):
%     (1) Kutta-Joukowski on the total bound circulation, CL = 2 Gamma / (U c)
%     (2) integrating the panel pressure coefficients (Cp) into a force and
%         resolving it into lift and drag. The inviscid "drag" this produces
%         should be close to zero (D'Alembert's paradox).
%   If those three numbers (CL_kj, CL_cp, CD_cp) do not agree, do not trust
%   the Cm or Cp output for that case -- increase n_panels first.
%
%   Output struct
%     .CL_kj, .CL_cp, .CD_cp   the three cross-check numbers above
%     .Cm_LE, .Cm_c4           pitching moment about the LE and the c/4
%     .Cp                      1xN panel pressure coefficients
%     .gamma                   1xN solved vortex strengths
%     .panel                   the input panel struct, passed through

    arguments
        panel (1,:) struct
        alpha_deg (1,1) double
    end

    N = numel(panel);
    alpha = deg2rad(alpha_deg);
    Uinf = [cos(alpha), sin(alpha)];   % unit freestream, chord-normalized

    xm = [panel.xm]; zm = [panel.zm];
    nx = [panel.nx]; nz = [panel.nz];
    tx = [panel.tx]; tz = [panel.tz];
    x1 = [panel.x1]; z1 = [panel.z1];
    Lp = [panel.L];  phi = [panel.phi];

    A_t = zeros(N, N);   % tangential-velocity influence, OUTSIDE surface

    for j = 1:N
        cphi = cos(phi(j)); sphi = sin(phi(j));

        dx = xm - x1(j);
        dz = zm - z1(j);
        xs =  dx*cphi + dz*sphi;     % local coords of every control point,
        zs = -dx*sphi + dz*cphi;     % in panel j's own frame

        r1 = hypot(xs, zs);
        r2 = hypot(xs - Lp(j), zs);
        th1 = atan2(zs, xs);
        th2 = atan2(zs, xs - Lp(j));

        us = (th2 - th1) / (2*pi);
        ws = log(max(r2, 1e-14) ./ max(r1, 1e-14)) / (2*pi);

        % self-term: control point i == source panel j, outside (fluid) side
        us(j) = 0.5;
        ws(j) = 0.0;

        u = us*cphi - ws*sphi;       % rotate back to global axes
        w = us*sphi + ws*cphi;

        A_t(:, j) = (u.*tx + w.*tz)';
    end

    % Inside tangential velocity: same matrix, but the self term flips from
    % +1/2 to -1/2 (the vortex-sheet jump), i.e. subtract the identity.
    A_in = A_t - eye(N);
    rhs  = -(Uinf(1)*tx' + Uinf(2)*tz');

    % Kutta condition replaces the equation at one panel near the LE
    % (never panel 1 or N). Dropping at the trailing edge instead gives a
    % wrong-sign solution with this formulation -- keep it near mid-contour.
    k_drop = max(2, floor(N/2));
    A_in(k_drop, :) = 0;
    A_in(k_drop, 1) = 1;
    A_in(k_drop, N) = 1;
    rhs(k_drop) = 0;

    gamma = A_in \ rhs;

    % Surface (outside) tangential velocity and pressure coefficient
    Vt = A_t*gamma + (Uinf(1)*tx' + Uinf(2)*tz');
    Cp = 1 - Vt.^2;                  % |Uinf| = 1 in this normalization

    % --- Kutta-Joukowski total-circulation lift (robust cross-check) ----
    Gamma = sum(gamma.*Lp');
    CL_kj = 2*Gamma;                  % U=1, c=1 in these normalized units

    % --- Cp-integrated force and moment -----------------------------------
    % Pressure acts INTO the body: force on panel k is -Cp_k * L_k * n_k with
    % n the OUTWARD normal.
    Fx = -sum(Cp'.*Lp.*nx);
    Fz = -sum(Cp'.*Lp.*nz);

    CL_cp =  Fx*(-sin(alpha)) + Fz*cos(alpha);
    CD_cp =  Fx*cos(alpha)    + Fz*sin(alpha);

    % Moment about the leading edge (x=0,z=0), positive nose-up, then
    % transferred to the quarter chord.
    Cm_LE = -sum(Cp'.*Lp.*(nx.*zm - nz.*xm));
    Cm_c4 = Cm_LE + CL_cp*0.25*cos(alpha) + CD_cp*0.25*sin(alpha);

    out.alpha_deg = alpha_deg;
    out.CL_kj = CL_kj;
    out.CL_cp = CL_cp;
    out.CD_cp = CD_cp;
    out.Cm_LE = Cm_LE;
    out.Cm_c4 = Cm_c4;
    out.Cp    = Cp';
    out.gamma = gamma';
    out.panel = panel;
end
