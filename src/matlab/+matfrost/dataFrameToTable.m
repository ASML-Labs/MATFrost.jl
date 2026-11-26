function value = dataFrameToTable(jl, handle)
% Materialize a retained Julia DataFrame as a MATLAB table.
wire = jl.MATFrost.dataframe_to_table(handle, signature="MATFrost.MATFrostHandle");
names = string(wire.variable_names(:));
types = string(wire.variable_types(:));
if isempty(wire.columns)
    columns = cell(0, 1);
elseif iscell(wire.columns)
    columns = wire.columns(:);
else
    error('MATFrost:InvalidTableWire', 'Table columns must be a cell array.');
end
if numel(names) ~= numel(types) || numel(names) ~= numel(columns) || ...
        numel(unique(names)) ~= numel(names)
    error('MATFrost:InvalidTableWire', 'Table names, types and columns must match.');
end
supported = ["logical", "string", "double", "single", "int8", "uint8", ...
    "int16", "uint16", "int32", "uint32", "int64", "uint64", ...
    "complex_double", "complex_single"];
for k = 1:numel(names)
    if ~ismember(types(k), supported)
        error('MATFrost:UnsupportedTableColumn', ...
            'Unsupported type "%s" for column "%s".', types(k), names(k));
    end
    type = types(k);
    complexColumn = startsWith(type, "complex_");
    if complexColumn
        type = extractAfter(type, "complex_");
    end
    if type == "string"
        columns{k} = string(columns{k}(:));
    else
        columns{k} = feval(char(type), columns{k}(:));
        if complexColumn && isreal(columns{k})
            columns{k} = complex(columns{k});
        end
    end
    if numel(columns{k}) ~= wire.row_count
        error('MATFrost:InvalidTableWire', 'Column "%s" has an invalid row count.', names(k));
    end
end
if isempty(names) && wire.row_count ~= 0
    error('MATFrost:InvalidTableWire', 'A table with rows and no columns is unsupported.');
end
value = table(columns{:}, 'VariableNames', cellstr(names));
end
