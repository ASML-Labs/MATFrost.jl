function handle = tableToDataFrame(jl, value)
% Transfer a MATLAB table to a retained Julia DataFrame.
if ~istable(value)
    error('MATFrost:InvalidTable', 'Expected a MATLAB table.');
end
if ~isempty(value.Properties.RowNames)
    error('MATFrost:UnsupportedTableMetadata', 'Table row names are not supported.');
end
names = string(value.Properties.VariableNames(:));
types = strings(numel(names), 1);
columns = cell(numel(names), 1);
for k = 1:numel(names)
    column = value.(names(k));
    if ~iscolumn(column) || size(column, 1) ~= height(value)
        error('MATFrost:UnsupportedTableColumn', ...
            'Column "%s" must be a single column vector.', names(k));
    end
    if isstring(column)
        if any(ismissing(column))
            error('MATFrost:UnsupportedTableColumn', ...
                'Missing strings in column "%s" are not supported.', names(k));
        end
        types(k) = "string";
    elseif isnumeric(column) || islogical(column)
        types(k) = string(class(column));
        if ~ismember(types(k), ["logical", "double", "single", "int8", ...
                "uint8", "int16", "uint16", "int32", "uint32", "int64", "uint64"])
            error('MATFrost:UnsupportedTableColumn', ...
                'Unsupported type "%s" for column "%s".', types(k), names(k));
        end
        if ~isreal(column)
            if ~ismember(types(k), ["double", "single"])
                error('MATFrost:UnsupportedTableColumn', ...
                    'Complex column "%s" must be single or double.', names(k));
            end
            types(k) = "complex_" + types(k);
        end
    else
        error('MATFrost:UnsupportedTableColumn', ...
            'Unsupported type "%s" for column "%s".', class(column), names(k));
    end
    if issparse(column)
        error('MATFrost:UnsupportedTableColumn', 'Sparse column "%s" is not supported.', names(k));
    end
    columns{k} = column;
end
wire = struct('variable_names', names, 'variable_types', types, ...
    'columns', {columns}, 'row_count', int64(height(value)));
handle = jl.MATFrost.table_to_dataframe(wire, signature="MATFrost.TableWire");
end
