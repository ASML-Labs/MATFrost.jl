using Test
using MATFrost
using MATFrost._ConvertToMATLAB
using MATFrost._Types

module TestConvertToMATLABExtension
import MATFrost: convert_to_matlab

struct FakeMatlabObject
    value::Int
end

struct FakeJuliaObject
    value::Int
end

convert_to_matlab(value::FakeJuliaObject) = FakeMatlabObject(value.value)
end

module GeometryExampleToMATLAB
export Point

struct Point
    x::Float64
    y::Float64
end

end

module MATFrostGeometryToMATLABExt

using MATFrost
using ..GeometryExampleToMATLAB

function MATFrost.convert_to_matlab_extension(p::GeometryExampleToMATLAB.Point)
    return Dict("__type__" => "Point", "x" => p.x, "y" => p.y)
end

end

@testset "convert_matfrostarray Vector{NamedTuple}" begin
    v = NamedTuple[(a = 1, b = "x"), (a = 2, b = "y")]
    result = MATFrost._ConvertToMATLAB.convert_matfrostarray(v)
    @test result isa MATFrostArrayCell
    @test length(result.values) == 2
    @test result.values[1] isa MATFrostArrayCell || result.values[1] isa MATFrostArrayStruct
end

@testset "convert_to_matlab extension points" begin
    @testset "identity fallback" begin
        value = Dict("answer" => 42)
        @test convert_to_matlab(value) === value
        @test convert_to_matlab(nothing) === nothing
    end

    @testset "external dispatch extension" begin
        julia_value = TestConvertToMATLABExtension.FakeJuliaObject(42)
        matlab_value = convert_to_matlab(julia_value)

        @test matlab_value isa TestConvertToMATLABExtension.FakeMatlabObject
        @test matlab_value.value == 42
    end
end

@testset "convert_to_matlab_extension custom hooks" begin
    point = GeometryExampleToMATLAB.Point(1.0, 2.0)
    matlab_repr = MATFrost.convert_to_matlab_extension(point)

    @test matlab_repr["__type__"] == "Point"
    @test matlab_repr["x"] == 1.0
    @test matlab_repr["y"] == 2.0
end
