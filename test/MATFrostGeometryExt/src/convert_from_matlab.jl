function convert_from_matlab(
    ::Type{Geometry.Point},
    value::MATFrost.MATFrostArrayString,
)
    return Geometry.Point(only(value.values))
end
