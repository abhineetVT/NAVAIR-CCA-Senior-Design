classdef CcaWeights < WeightsBase
%CCAWEIGHTS  Empty/operating weight and payload, including the explicit
%   internal-bay-vs-external-pylon structural trade.
%
%   Uses a simplified fixed-fraction-of-W_TO statistical method for the
%   airframe structure and systems groups [conceptual-design simplification
%   of Raymer 6th ed. Ch. 15's statistical group-weight equations, which
%   are themselves regressions against existing fighter/attack aircraft;
%   fractions here are representative of that class for a tailless-to-
%   conventional, single/twin-engine UCAV-class airframe] -- appropriate
%   for this stage, where the point is the STORES trade and the carrier
%   constraints, not a part-by-part weight statement. Engine weight comes
%   from the injected CcaProp (thrust-based, not a fraction of W_TO).
%
%   STORES WEIGHT TRADE (this is the point of this class)
%     external: no bay structure cost, but a pylon/rack weight PER STORE
%               (structural hard-point + release mechanism), added to OEW.
%     internal: no pylon weight, but a weapons-bay structure weight
%               (doors, longerons around the cutout, actuators) scaled
%               with the bay's own volume (geom.bay_volume), added to OEW.
%   Either way, the STORE itself (the weapon round) is PAYLOAD, not OEW --
%   it is carried whether internal or external, and is what the mission
%   analysis drops at a releases_stores segment.

    properties (SetAccess = immutable)
        geom      % CcaGeom
        prop      % CcaProp (for engine_weight)

        structure_frac    % airframe structure group, fraction of W_TO
        systems_frac      % avionics/flight-controls/electrical/hydraulics/autonomy-compute
        fuel_system_frac  % tanks, lines, pumps

        pylon_weight_each       % lbf, external-carriage hardware per store
        bay_structure_density   % lbf/ft^3, internal-bay structure penalty

        store_weight_each       % lbf, the weapon/store itself (payload)
        fixed_payload_lb        % lbf, sensors/EO-IR/radar/datalink payload
        reserve_fuel_frac       % reserve as fraction of LOADED fuel (RFP: 0.25 at landing)
    end

    methods
        function obj = CcaWeights(json_path, geom, prop)
            arguments
                json_path {mustBeTextScalar, mustBeNonzeroLengthText}
                geom (1,1) CcaGeom
                prop (1,1) PropulsionBase_Jet
            end
            obj.geom = geom;
            obj.prop = prop;

            J = jsondecode(fileread(json_path));
            W = J.weights;

            obj.structure_frac   = W.structure_frac_of_WTO;
            obj.systems_frac     = W.systems_frac_of_WTO;
            obj.fuel_system_frac = getdef(W, 'fuel_system_frac_of_WTO', 0.015);

            obj.pylon_weight_each     = getdef(W, 'pylon_weight_each_lbf', 60);
            obj.bay_structure_density = getdef(W, 'bay_structure_density_lbf_per_ft3', 8);

            obj.store_weight_each = W.store_weight_each_lbf;
            obj.fixed_payload_lb  = getdef(W, 'fixed_payload_lbf', 0);
            obj.reserve_fuel_frac = getdef(W, 'reserve_fuel_frac_of_loaded', 0);
        end

        %% ---------------- WeightsBase interface --------------------------
        function OEW = OEW(obj, W_TO)
            b = obj.OEW_breakdown(W_TO);
            OEW = b.total;
        end

        function b = OEW_breakdown(obj, W_TO)
            b.structure   = obj.structure_frac   * W_TO;
            b.systems     = obj.systems_frac     * W_TO;
            b.fuel_system = obj.fuel_system_frac * W_TO;
            [b.engines, b.engine_each] = obj.prop.engine_weight();

            if obj.geom.is_internal_stores
                b.store_hardware = obj.bay_structure_density * obj.geom.bay_volume;
                b.store_hardware_type = "internal_bay_structure";
            else
                b.store_hardware = obj.geom.n_stores * obj.pylon_weight_each;
                b.store_hardware_type = "external_pylons";
            end

            b.total = b.structure + b.systems + b.fuel_system + b.engines + b.store_hardware;
        end

        function W_loaded = fuel_loaded(obj, W_burned)
            %FUEL_LOADED  Total fuel carried so that reserve_fuel_frac of it
            %   is still in the tanks after the mission burn.
            W_loaded = W_burned / (1 - obj.reserve_fuel_frac);
        end

        function W_payload = payload(obj)
            W_payload = obj.geom.n_stores * obj.store_weight_each + obj.fixed_payload_lb;
        end
    end
end


function v = getdef(s, name, default)
    if isfield(s, name) && ~isempty(s.(name))
        v = s.(name);
    else
        v = default;
    end
end
