classdef ConstraintSetImporter
%CONSTRAINTSETIMPORTER  Reads constraint conditions from a requirements JSON.
%
%   Generic Layer-1 utility. Reads a top-level "constraints" block whose
%   "conditions" member is an array of condition objects. Each object
%   carries REQUIREMENT / CONDITION data only (flight condition + the
%   field-performance or maneuver requirement), keyed by explicit field
%   names. It carries NO discipline-owned quantity (no CLmax, CD0, K1,
%   TSFC): those come from the injected aero/prop objects at run time.
%
%   Wiring each condition into a concrete constraint function is a Layer-2
%   concern -- see run_constraints.m.

    methods (Static)

        function conditions = read_conditions(json_path)
            arguments
                json_path (1,1) string {mustBeNonzeroLengthText}
            end

            raw = jsondecode(fileread(json_path));

            if ~isfield(raw, 'constraints') || ~isfield(raw.constraints, 'conditions')
                error('ConstraintSetImporter:missingConstraintsBlock', ...
                    ['Requirements JSON "%s" has no constraints.conditions block.'], ...
                    json_path);
            end

            conditions = json_as_struct_array(raw.constraints.conditions);
        end

    end

end
