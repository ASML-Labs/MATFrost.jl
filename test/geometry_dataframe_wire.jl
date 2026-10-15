using Geometry
using MATFrostGeometryExt

@testset "Geometry DataFrame wire conversion" begin
    dataframe = Geometry.points_dataframe()
    wire = MATFrost.convert_to_matlab(dataframe)

    @test wire.variable_names == ["label", "kind", "population"]
    @test wire.variable_types == ["string", "string", "int64"]
    @test wire.columns == Any[
        ["Amsterdam", "Eindhoven", "Veldhoven"],
        ["city", "city", "village"],
        Int64[931_298, 246_443, 45_829],
    ]
end
