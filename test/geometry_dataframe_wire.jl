using MATFrostGeometryExt

@testset "Geometry DataFrame wire conversion" begin
    dataframe = MATFrostGeometryExt.points_dataframe()
    wire = MATFrost.convert_to_matlab(dataframe)

    @test wire.variable_names == ["label", "kind"]
    @test wire.variable_types == ["string", "string"]
    @test wire.columns == Any[
        ["Amsterdam", "Eindhoven", "Veldhoven"],
        ["city", "city", "city"],
    ]
end
