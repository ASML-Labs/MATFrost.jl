module MATFrostGeometryExt

using Geometry
using MATFrost

import MATFrost: convert_from_matlab_extension

export activate

activate() = nothing

function convert_from_matlab_extension(
    ::Type{Geometry.Point},
    value::MATFrost._Types.MATFrostArrayString,
)
    return Geometry.Point(only(value.values))
end

end