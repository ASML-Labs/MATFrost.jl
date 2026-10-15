module MATFrostGeometryExt

using DataFrames
using Geometry
using MATFrost

import MATFrost: convert_from_matlab, convert_to_matlab

export activate, DataFrameWire

activate() = nothing

struct DataFrameWire
    variable_names::Vector{String}
    variable_types::Vector{String}
    columns::Vector{Any}
end

include("convert_to_matlab.jl")
include("convert_from_matlab.jl")

end
