module MATFrostTestExt

using MATFrost

import MATFrost:
    convert_from_matlab_extension,
    convert_to_matlab_extension

struct Point
    label::String
end

function convert_from_matlab_extension(
    ::Type{Point},
    value::MATFrost._Types.MATFrostArrayString,
)
    Point(value.values[1])
end

convert_to_matlab_extension(
    value::Point,
) = value.label

get_label(point::Point) = point.label

end