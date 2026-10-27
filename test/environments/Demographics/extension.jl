@testset "convert_to_matlab hook" begin
    country = Country("Netherlands", 33481.0)

    add_city!(country, "Amsterdam", 934526)
    add_city!(country, "Rotterdam", 672960)

    df = dataframe(country)

    wire = MATFrost.convert_to_matlab(df)

    @test wire isa MATFrostDemographicsExt.DataFrameWire

    @test wire.dataType == "matfrost_table"

    @test wire.variable_names == ["name", "population"]

    @test wire.columns[1] == ["Amsterdam", "Rotterdam"]
    @test wire.columns[2] == [934526, 672960]
end