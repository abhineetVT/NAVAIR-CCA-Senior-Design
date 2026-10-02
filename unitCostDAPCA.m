function UC = unitCostDAPCA(We, T_SLS, M_max, T_R, W_elec, S, Q, QD)
%Used AI to compile all necessary equations given the slides, as this
%specific topic hasn't been covered in class yet.
%References to equations are to a separate document where the equations are
%written and the sources stated in detail.

% Average unit cost, $M FY2024 = (development + production)/Q, Eq. (6)
% DAPCA IV as taught in AOE module A6 "Cost Considerations" (Raymer Ch. 18; Nicolai & Carichner Ch. 24)
% We empty weight (lb), S max speed (kt), Q total aircraft, QD flight test aircraft
H_E = 4.86*We^0.777*S^0.894*Q^0.163; % Eq. (A7) engineering hours [A6 s.13]
H_T = 5.99*We^0.777*S^0.696*Q^0.263; % Eq. (A7) tooling hours [A6 s.13]
H_M = 7.37*We^0.82*S^0.484*Q^0.641; % Eq. (A7) manufacturing hours [A6 s.13]
H_Q = 0.13*H_M; % Eq. (A7) quality control hours, non-transport aircraft [A6 s.13]
D = 66*We^0.63*S^1.3; % Eq. (A8) development support, 1998 $ [A6 s.13]
F = 1852*We^0.325*S^0.822*QD^1.21; % Eq. (A8) flight test, 1998 $ [A6 s.13]
M = 16.39*We^0.921*S^0.621*Q^0.799; % Eq. (A8) manufacturing materials, 1998 $ [A6 s.13]
P_eng = 2306*(0.043*T_SLS + 243.3*M_max + 0.969*T_R - 2228); % Eq. (A9) one engine, 1998 $ [A6 s.14]
k98 = 229.594/163.0; % 1998 to 2012 $ [BLS CPI-U annual averages]
k24 = 313.689/229.594; % 2012 to 2024 $ [BLS CPI-U annual averages]
labor = 115*H_E + 118*H_T + 98*H_M + 108*H_Q; % 2012 $, hourly rates [A6 s.15]
airframe = 1.2*(labor + k98*(D + F + M)); % +20% for modern military aircraft [A6 s.15]
per_unit = k98*P_eng + 6000*W_elec; % engine + avionics at $6,000/lb, midpoint of $4,000-8,000 (2012 $) [A6 s.14]
UC = k24*(airframe/Q + per_unit)/1e6; % Eq. (6)
end
