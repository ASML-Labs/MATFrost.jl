using Test
using MATFrost
using Demographics
using MATFrostDemographicsExt

@testset "Demographics integration loaded" begin
    @test isdefined(Main, :MATFrostDemographicsExt)
    @test MATFrost.use_matfrost_handle(Demographics.Country)
end

include("extension.jl")
include("handles.jl")