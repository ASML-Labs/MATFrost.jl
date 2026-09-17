module Geometry

export Point
export get_label

struct Point
    label::String
end

get_label(point::Point) = point.label

end