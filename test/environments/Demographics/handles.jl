@testset "Demographics handle extension" begin

    @test MATFrost.use_matfrost_handle(Demographics.Country)

    country = Country("Netherlands", 33481.0)

    converted = MATFrost._ConvertToMATLAB.convert_matfrostarray(country)

    @test converted isa MATFrost._Types.MATFrostArrayStruct
    @test converted.values[3].values[1] == string(Demographics.Country)

    restored = MATFrost._ConvertToJulia.convert_matfrostarray(
        Demographics.Country,
        converted,
    )

    @test restored === country
    @test restored.name == "Netherlands"
    @test restored.area == 33481.0

    try
        nothing
    finally
        MATFrost.release_all_handles!()
    end
end