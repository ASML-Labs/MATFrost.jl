using Test
using MATFrost
using MATFrost._Types

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

module TestTypedConversionExtension

import MATFrost: convert_from_matlab

using MATFrost._Types

struct LabeledValue
    label::String
end

convert_from_matlab(::Type{LabeledValue}, marr::MATFrostArrayString) =
    LabeledValue(marr.values[1])

end

@testset "MATFrost conversion extension points" begin

    @testset "convert_to_matlab identity fallback" begin

        value = Dict("answer" => 42)

        @test convert_to_matlab(value) === value
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

    @testset "type-aware wire conversion hook" begin

        marr = MATFrostArrayString(Int64[1], ["PointLabel"])

        value = convert_from_matlab(TestTypedConversionExtension.LabeledValue, marr)

        @test value isa TestTypedConversionExtension.LabeledValue

        @test value.label == "PointLabel"

    end

    @testset "typed fallback uses built-in conversion" begin

        marr = MATFrostArrayPrimitive{Int64}(Int64[1], Int64[7])

        @test convert_from_matlab(Int64, marr) == 7

    end

end
