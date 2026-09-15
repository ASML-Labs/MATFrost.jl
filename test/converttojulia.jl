using Test
using MATFrost

module TestConvertToJuliaExtension
import MATFrost: convert_from_matlab

struct FakeMatlabObject
    value::Int
end

struct FakeJuliaObject
    value::Int
end

convert_from_matlab(value::FakeMatlabObject) = FakeJuliaObject(value.value)
end

module GeometryExampleToJulia
export Point
export distance

struct Point
    x::Float64
    y::Float64
end

distance(p::Point) = hypot(p.x, p.y)

end

module MATFrostGeometryToJuliaExt

using MATFrost
using ..GeometryExampleToJulia

function MATFrost.convert_from_matlab_extension(x::Dict{String,Any})
    get(x, "__type__", nothing) == "Point" || return x
    return GeometryExampleToJulia.Point(Float64(x["x"]), Float64(x["y"]))
end

end

using .GeometryExampleToJulia

@testset "convert_from_matlab extension points" begin
    @testset "identity fallback" begin
        value = Dict("answer" => 42)
        @test convert_from_matlab(value) === value
        @test convert_from_matlab(nothing) === nothing
    end

    @testset "external dispatch extension" begin
        matlab_value = TestConvertToJuliaExtension.FakeMatlabObject(42)
        julia_value = convert_from_matlab(matlab_value)

        @test julia_value isa TestConvertToJuliaExtension.FakeJuliaObject
        @test julia_value.value == 42
    end

    @testset "fallback is not implicitly recursive" begin
        nested_value = [Dict("value" => 1)]
        @test convert_from_matlab(nested_value) === nested_value
    end
end

@testset "convert_from_matlab_extension custom hooks" begin
    matlab_repr = Dict(
        "__type__" => "Point",
        "x" => 3.0,
        "y" => 4.0,
    )

    point = MATFrost.convert_from_matlab_extension(matlab_repr)
    @test point isa Point
    @test point == Point(3.0, 4.0)
    @test distance(point) == 5.0
end

@testset "convert_from_matlab_extension unsupported values pass through" begin
    value = Dict("name" => "example")
    @test MATFrost.convert_from_matlab_extension(value) === value
end
