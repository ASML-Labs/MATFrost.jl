using Test
using MATFrost

module TestConversionExtension
import MATFrost: convert_from_matlab, convert_to_matlab

struct FakeMatlabObject
    value::Int
end

struct FakeJuliaObject
    value::Int
end

convert_from_matlab(value::FakeMatlabObject) = FakeJuliaObject(value.value)
convert_to_matlab(value::FakeJuliaObject) = FakeMatlabObject(value.value)
end

@testset "MATFrost conversion extension points" begin
    @testset "identity fallback" begin
        value = Dict("answer" => 42)
        @test convert_from_matlab(value) === value
        @test convert_to_matlab(value) === value
        @test convert_from_matlab(nothing) === nothing
        @test convert_to_matlab(nothing) === nothing
    end

    @testset "external dispatch extension" begin
        matlab_value = TestConversionExtension.FakeMatlabObject(42)
        julia_value = convert_from_matlab(matlab_value)

        @test julia_value isa TestConversionExtension.FakeJuliaObject
        @test julia_value.value == 42

        roundtrip_value = convert_to_matlab(julia_value)
        @test roundtrip_value isa TestConversionExtension.FakeMatlabObject
        @test roundtrip_value.value == matlab_value.value
    end

    @testset "fallback is not implicitly recursive" begin
        nested_value = [Dict("value" => 1)]
        @test convert_from_matlab(nested_value) === nested_value
        @test convert_to_matlab(nested_value) === nested_value
    end
end
