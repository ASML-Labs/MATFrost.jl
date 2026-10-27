function value = matfrost_materialize(value)
% matfrost_materialize - Turns MATFrost wire payloads into native MATLAB types.
%
% Values that carry a recognized dataType marker are rebuilt into the MATLAB
% type they represent. Handles are intentionally left as structs.

    if isstruct(value)
        if isscalar(value) && isfield(value, "dataType") && ...
                isequal(string(value.dataType), "matfrost_table")
            value = materialize_table(value);
            return
        end

        fields = string(fieldnames(value));
        for k = 1:numel(fields)
            for e = 1:numel(value)
                value(e).(fields(k)) = matfrost_materialize(value(e).(fields(k)));
            end
        end
    elseif iscell(value)
        for k = 1:numel(value)
            value{k} = matfrost_materialize(value{k});
        end
    end
end

function t = materialize_table(wire)
    columns = cellfun(@matfrost_materialize, wire.columns(:)', 'UniformOutput', false);
    columns = cellfun(@(c) c(:), columns, 'UniformOutput', false);

    t = table(columns{:}, 'VariableNames', cellstr(string(wire.variable_names(:)')));
end
