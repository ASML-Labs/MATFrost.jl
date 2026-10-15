module Geometry

using DataFrames

export Point
export get_label
export points_dataframe

struct Point
    label::String
end

get_label(point::Point) = point.label

function points_dataframe()
    return DataFrame(
        label = ["Amsterdam", "Eindhoven", "Veldhoven"],
        kind = ["city", "city", "village"],
        population = Int64[931_298, 246_443, 45_829],
    )
end

end
