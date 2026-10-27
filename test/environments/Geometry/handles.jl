@testset "Geometry handle extension" begin

    @test MATFrost.use_matfrost_handle(Geometry.Point)

    point = Geometry.Point("Amsterdam")
    converted = MATFrost._ConvertToMATLAB.convert_matfrostarray(point)
    @test converted isa MATFrost._Types.MATFrostArrayStruct
    @test converted.values[3].values[1] == string(Geometry.Point)

    restored = MATFrost._ConvertToJulia.convert_matfrostarray(
        Geometry.Point,
        converted,
    )
    @test restored === point
    @test Geometry.get_label(restored) == "Amsterdam"

    try
        nothing
    finally
        MATFrost.release_all_handles!()
    end
end