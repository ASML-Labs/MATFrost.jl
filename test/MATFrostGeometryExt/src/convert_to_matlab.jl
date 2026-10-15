function convert_to_matlab(dataframe::DataFrame)
    columns = Any[collect(column) for column in eachcol(dataframe)]
    return DataFrameWire(
        String.(names(dataframe)),
        [_matlab_variable_type(eltype(column)) for column in eachcol(dataframe)],
        columns,
    )
end

_matlab_variable_type(::Type{<:AbstractString}) = "string"
_matlab_variable_type(::Type{<:Bool}) = "logical"
_matlab_variable_type(::Type{<:Integer}) = "int64"
_matlab_variable_type(::Type{<:AbstractFloat}) = "double"
_matlab_variable_type(::Type) = "unsupported"