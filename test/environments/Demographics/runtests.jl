using Test
using MATFrost
using Demographics
using MATFrostDemographicsExt

@testset "Demographics handle integration" begin
    @test MATFrost.use_matfrost_handle(Country)
    @test !MATFrost.use_matfrost_handle(City)

    country = Country("Netherlands", 33481.0)
    wire = MATFrost._ConvertToMATLAB.convert_matfrostarray(country)

    try
        @test wire.fieldnames == Symbol[:dataType, :id, :typename]
        @test wire.values[1].values[1] == "matfrost_handle"
        @test wire.values[3].values[1] == string(Country)
        restored = MATFrost._ConvertToJulia.convert_matfrostarray(Country, wire)
        @test restored === country

        add_city!(restored, "Amsterdam", Int64(934526))
        add_city!(restored, "Rotterdam", Int64(672960))
        @test population(country) == 1607486
        update_city!(restored, "Amsterdam", Int64(950000))
        @test population(country) == 1622960
        remove_city!(restored, "Rotterdam")
        @test population(country) == 950000

        buffer = IOBuffer()
        MATFrost._Write.write_matfrostarray!(buffer, wire)
        seekstart(buffer)
        received = MATFrost._Read.read_matfrostarray!(buffer)
        @test bytesavailable(buffer) == 0
        @test MATFrost._ConvertToJulia.convert_matfrostarray(Country, received) === country

        info = country_info(country)
        info_wire = MATFrost._ConvertToMATLAB.convert_matfrostarray(info)
        @test info_wire.fieldnames == Symbol[:name, :area, :population, :density]
        @test MATFrost._ConvertToJulia.convert_matfrostarray(typeof(info), info_wire) == info

        handle = MATFrost._ConvertToJulia.convert_matfrostarray(MATFrost.MATFrostHandle, wire)
        @test MATFrost.release_handle(handle)
        @test_throws ArgumentError MATFrost._ConvertToJulia.convert_matfrostarray(Country, wire)
    finally
        MATFrost.release_all_handles!()
    end
end