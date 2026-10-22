module MATFrostGeometryExt

using DataFrames
using MATFrost

import MATFrost: convert_to_matlab

export DataFrameWire
export activate

"""
Entry point for loading this package into a running MATFrost server, which only imports the
root modules named in a call. Importing it registers the `convert_to_matlab` methods below.
"""
activate() = nothing

"""
Wire representation of a tabular value. Materialized as a `table` on the MATLAB side.
"""
struct DataFrameWire
    dataType::String
    variable_names::Vector{String}
    variable_types::Vector{String}
    columns::Vector{Any}
end

function DataFrameWire(df::AbstractDataFrame)
    DataFrameWire(
        "matfrost_table",
        String[string(n) for n in names(df)],
        String[string(eltype(c)) for c in eachcol(df)],
        Any[collect(c) for c in eachcol(df)],
    )
end

convert_to_matlab(df::AbstractDataFrame) = DataFrameWire(df)

end