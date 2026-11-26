"""
    TableWire

Column-oriented transport representation for a MATLAB table. Use
`table_to_dataframe` and `dataframe_to_table` to convert DataFrames explicitly.
"""
struct TableWire
    variable_names::Vector{String}
    variable_types::Vector{String}
    columns::Vector{Any}
    row_count::Int64
end

const TABLE_COLUMN_TYPES = Dict{String,Type}(
    "logical" => Bool, "string" => String,
    "double" => Float64, "single" => Float32,
    "int8" => Int8, "uint8" => UInt8,
    "int16" => Int16, "uint16" => UInt16,
    "int32" => Int32, "uint32" => UInt32,
    "int64" => Int64, "uint64" => UInt64,
    "complex_double" => ComplexF64, "complex_single" => ComplexF32,
)

function _validate_table_wire(wire::TableWire)
    n = length(wire.variable_names)
    length(wire.variable_types) == n && length(wire.columns) == n ||
        throw(ArgumentError("Table names, types and columns must have matching lengths"))
    length(unique(wire.variable_names)) == n ||
        throw(ArgumentError("Table variable names must be unique"))
    wire.row_count >= 0 || throw(ArgumentError("Table row count must be nonnegative"))
    n == 0 && wire.row_count != 0 &&
        throw(ArgumentError("A DataFrame cannot represent rows without columns"))
    for (name, typename, column) in zip(wire.variable_names, wire.variable_types, wire.columns)
        T = get(TABLE_COLUMN_TYPES, typename, nothing)
        T === nothing && throw(ArgumentError("Unsupported table column type '$typename' for '$name'"))
        column isa Vector{T} ||
            throw(ArgumentError("Table column '$name' does not match type '$typename'"))
        length(column) == wire.row_count ||
            throw(ArgumentError("Table column '$name' does not match the row count"))
    end
    return wire
end

function _ConvertToJulia.convert_matfrostarray(
    ::Type{TableWire}, value::_Types.MATFrostArrayAbstract,
)
    value isa _Types.MATFrostArrayStruct ||
        throw(ArgumentError("Expected a scalar TableWire struct"))
    _ConvertToJulia.validate_array_dimensions(TableWire, value)
    _ConvertToJulia.validate_fieldnames(TableWire, value)
    field(name) = _ConvertToJulia.get_matfrostarray_element(value, name, 1)
    names = _ConvertToJulia.convert_matfrostarray(Vector{String}, field(:variable_names))
    types = _ConvertToJulia.convert_matfrostarray(Vector{String}, field(:variable_types))
    rows = _ConvertToJulia.convert_matfrostarray(Int64, field(:row_count))
    raw_columns = field(:columns)
    values = if raw_columns isa _Types.MATFrostArrayCell
        raw_columns.values
    elseif raw_columns isa _Types.MATFrostArrayEmpty
        _Types.MATFrostArrayAbstract[]
    else
        throw(ArgumentError("Table columns must be a cell array"))
    end
    length(names) == length(types) == length(values) ||
        throw(ArgumentError("Table names, types and columns must have matching lengths"))
    columns = Any[]
    for (name, typename, raw) in zip(names, types, values)
        T = get(TABLE_COLUMN_TYPES, typename, nothing)
        T === nothing && throw(ArgumentError("Unsupported table column type '$typename' for '$name'"))
        push!(columns, _ConvertToJulia.convert_matfrostarray(Vector{T}, raw))
    end
    return _validate_table_wire(TableWire(names, types, columns, rows))
end

function _dataframes_module()
    Base.find_package("DataFrames") === nothing &&
        throw(ArgumentError("DataFrames.jl must be installed in the active Julia environment"))
    return Base.require(Main, :DataFrames)
end

"""
    table_to_dataframe(wire::TableWire) -> MATFrostHandle

Create a Julia DataFrame from a table wire and retain it in the handle store.
DataFrames.jl must be available in the active Julia environment.
"""
function table_to_dataframe(wire::TableWire)
    _validate_table_wire(wire)
    dataframes = _dataframes_module()
    return Base.invokelatest(_table_to_dataframe, dataframes, wire)
end

function _table_to_dataframe(dataframes::Module, wire::TableWire)
    frame = dataframes.DataFrame(wire.columns, Symbol.(wire.variable_names))
    return store_handle(frame)
end

"""
    dataframe_to_table(frame_or_handle) -> TableWire

Explicitly materialize a DataFrame or handle as a table wire. Only supported
primitive column types are transferred; missing and other types are rejected.
"""
function dataframe_to_table(frame)
    dataframes = _dataframes_module()
    return Base.invokelatest(_dataframe_to_table, dataframes, frame)
end

dataframe_to_table(handle::MATFrostHandle) = dataframe_to_table(resolve_handle(handle))

function _dataframe_to_table(dataframes::Module, frame)
    frame isa dataframes.AbstractDataFrame ||
        throw(ArgumentError("Expected a DataFrame, got $(typeof(frame))"))
    names = String.(propertynames(frame))
    types = String[]
    columns = Any[]
    for name in names
        column = frame[!, name]
        T = eltype(column)
        match = findfirst(t -> t === T, TABLE_COLUMN_TYPES)
        match === nothing &&
            throw(ArgumentError("Unsupported table column type $T for '$name'; missing values are not supported"))
        push!(types, match)
        push!(columns, collect(column))
    end
    return _validate_table_wire(TableWire(names, types, columns, Int64(dataframes.nrow(frame))))
end
