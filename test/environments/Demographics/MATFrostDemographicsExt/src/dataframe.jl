using DataFrames

import MATFrost: convert_to_matlab

struct DataFrameWire
    dataType::String
    variable_names::Vector{String}
    columns::Vector{Vector}
end

function convert_to_matlab(df::DataFrame)
    DataFrameWire(
        "matfrost_table",
        String.(names(df)),
        [collect(df[!, col]) for col in names(df)],
    )
end