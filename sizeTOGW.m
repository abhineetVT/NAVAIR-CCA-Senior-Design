function W0 = sizeTOGW(W_fixed, WfW, A, C)
% Class fixed-point sizing [W2L1 s.19-22]
W0 = 20000; % lb, initial guess
for k = 1:200
  W_new = W_fixed/(1 - A*W0^C - WfW); % Eq. (1) W0 = W_fixed/(1 - We/W0 - Wf/W0), with We/W0 = A*W0^C, Eq. (2)
  if abs(W_new - W0) < 0.1, break; end
  W0 = W_new;
end
W0 = W_new;
end
