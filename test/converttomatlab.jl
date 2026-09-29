using Test
using MATFrost._ConvertToMATLAB
using MATFrost._Types

@testset "convert_matfrostarray Vector{NamedTuple}" begin
    v = NamedTuple[(a = 1, b = "x"), (a = 2, b = "y")]
    result = MATFrost._ConvertToMATLAB.convert_matfrostarray(v)
    @test result isa MATFrostArrayCell
    @test length(result.values) == 2
    @test result.values[1] isa MATFrostArrayCell || result.values[1] isa MATFrostArrayStruct
end
