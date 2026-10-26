using DataFrames

@testset "convert_to_matlab hook" begin

    @testset "default is identity" begin
        country = Country("Netherlands", 33481.0)

        @test MATFrost.convert_to_matlab(country) === country
    end

    @testset "Country dataframe maps onto DataFrameWire" begin
        country = Country("Netherlands", 33481.0)

        add_city!(country, "Amsterdam", 934526)
        add_city!(country, "Rotterdam", 672960)

        wire = MATFrost.convert_to_matlab(dataframe(country))

        @test wire isa MATFrostDemographicsExt.DataFrameWire
        @test wire.dataType == "matfrost_table"

        @test wire.variable_names == ["name", "population"]

        @test wire.columns[1] == ["Amsterdam", "Rotterdam"]
        @test wire.columns[2] == [934526, 672960]
    end

end