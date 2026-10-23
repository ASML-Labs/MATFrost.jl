module GeometryExt

using Geometry
using MATFrost

MATFrost.use_matfrost_handle(::Type{Geometry.Point}) = true

end