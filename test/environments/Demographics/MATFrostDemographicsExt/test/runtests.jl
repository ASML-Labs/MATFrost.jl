
using Test
using MATFrost
using Demographics
using MATFrostDemographicsExt

@testset "MATFrostDemographicsExt" begin

    @test MATFrost.use_matfrost_handle(Country)

    country = Country("Netherlands", 33481.0)

    add_city!(country, "Amsterdam", 934526)
    add_city!(country, "Rotterdam", 672960)

    converted =
        MATFrost._ConvertToMATLAB.convert_matfrostarray(country)

    @test converted isa MATFrost.MATFrostHandle
end