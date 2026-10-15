function convert_from_matlab(
    ::Type{Geometry.Point},
    value::MATFrost._Types.MATFrostArrayString,
)
    return Geometry.Point(only(value.values))
end
