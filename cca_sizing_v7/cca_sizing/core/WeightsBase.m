classdef (Abstract) WeightsBase < handle
%WEIGHTSBASE  Tier-1 abstract enforcer for all weights discipline classes.
%
%   Inheritance: WeightsBase -> CcaWeights

    methods (Abstract)

        %OEW  Operating empty weight [lbf] at a candidate takeoff weight.
        %   Every W_TO-dependent term is evaluated at the PASSED W_TO, never
        %   at a stored W_TO -- the sizing loop calls this at a trial weight
        %   that is not yet the object's own weight.
        oew = OEW(obj, W_TO)

        %OEW_BREAKDOWN  Itemised empty weight [lbf] at a candidate W_TO.
        bd = OEW_breakdown(obj, W_TO)

        %PAYLOAD  Total payload [lbf]. The number the TOGW closure solves for.
        W = payload(obj)

    end

end
