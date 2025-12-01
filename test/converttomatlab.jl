module ConvertToMATLABTest

using Test
using JET

using ..Types

using MATFrost: MATFrost
using MATFrost._ConvertToMATLAB: convert_matfrostarray, unsupported_datatype_exception
using MATFrost._Types
using MATFrost._Constants


"""
Deep equality check for MATFrostArrayAbstract types
"""
function deepequal(a::MATFrostArrayAbstract, b::MATFrostArrayAbstract)
    typeof(a) == typeof(b) || return false
    if a isa MATFrostArrayEmpty
        return true
    elseif a isa MATFrostArrayPrimitive
        return a.dims == b.dims && a.values == b.values
    elseif a isa MATFrostArrayString
        return a.dims == b.dims && a.values == b.values
    elseif a isa MATFrostArrayCell
        a.dims == b.dims || return false
        length(a.values) == length(b.values) || return false
        for i in eachindex(a.values)
            deepequal(a.values[i], b.values[i]) || return false
        end
        return true
    elseif a isa MATFrostArrayStruct
        a.dims == b.dims || return false
        a.fieldnames == b.fieldnames || return false
        length(a.values) == length(b.values) || return false
        for i in eachindex(a.values)
            deepequal(a.values[i], b.values[i]) || return false
        end
        return true
    end
    return false
end


@testset "ConvertToMATLAB-Primitives-Scalars" begin

    @testset "Convert-Bool-Scalar" begin
        result = convert_matfrostarray(true)
        expected = MATFrostArrayPrimitive{Bool}([1], [true])
        @test deepequal(result, expected)
    end

    @testset "Convert-Float32-Scalar" begin
        result = convert_matfrostarray(Float32(42.5))
        expected = MATFrostArrayPrimitive{Float32}([1], [Float32(42.5)])
        @test deepequal(result, expected)
    end

    @testset "Convert-Float64-Scalar" begin
        result = convert_matfrostarray(42.5)
        expected = MATFrostArrayPrimitive{Float64}([1], [42.5])
        @test deepequal(result, expected)
    end

    @testset "Convert-Int8-Scalar" begin
        result = convert_matfrostarray(Int8(-42))
        expected = MATFrostArrayPrimitive{Int8}([1], [Int8(-42)])
        @test deepequal(result, expected)
    end

    @testset "Convert-UInt8-Scalar" begin
        result = convert_matfrostarray(UInt8(42))
        expected = MATFrostArrayPrimitive{UInt8}([1], [UInt8(42)])
        @test deepequal(result, expected)
    end

    @testset "Convert-Int16-Scalar" begin
        result = convert_matfrostarray(Int16(-1234))
        expected = MATFrostArrayPrimitive{Int16}([1], [Int16(-1234)])
        @test deepequal(result, expected)
    end

    @testset "Convert-UInt16-Scalar" begin
        result = convert_matfrostarray(UInt16(1234))
        expected = MATFrostArrayPrimitive{UInt16}([1], [UInt16(1234)])
        @test deepequal(result, expected)
    end

    @testset "Convert-Int32-Scalar" begin
        result = convert_matfrostarray(Int32(-123456))
        expected = MATFrostArrayPrimitive{Int32}([1], [Int32(-123456)])
        @test deepequal(result, expected)
    end

    @testset "Convert-UInt32-Scalar" begin
        result = convert_matfrostarray(UInt32(123456))
        expected = MATFrostArrayPrimitive{UInt32}([1], [UInt32(123456)])
        @test deepequal(result, expected)
    end

    @testset "Convert-Int64-Scalar" begin
        result = convert_matfrostarray(Int64(-123456789))
        expected = MATFrostArrayPrimitive{Int64}([1], [Int64(-123456789)])
        @test deepequal(result, expected)
    end

    @testset "Convert-UInt64-Scalar" begin
        result = convert_matfrostarray(UInt64(123456789))
        expected = MATFrostArrayPrimitive{UInt64}([1], [UInt64(123456789)])
        @test deepequal(result, expected)
    end

    @testset "Convert-Complex-Float32-Scalar" begin
        result = convert_matfrostarray(Complex{Float32}(1.0, 2.0))
        expected = MATFrostArrayPrimitive{Complex{Float32}}([1], [Complex{Float32}(1.0, 2.0)])
        @test deepequal(result, expected)
    end

    @testset "Convert-Complex-Float64-Scalar" begin
        result = convert_matfrostarray(Complex{Float64}(1.0, 2.0))
        expected = MATFrostArrayPrimitive{Complex{Float64}}([1], [Complex{Float64}(1.0, 2.0)])
        @test deepequal(result, expected)
    end

    @testset "Convert-Complex-Int32-Scalar" begin
        result = convert_matfrostarray(Complex{Int32}(1, 2))
        expected = MATFrostArrayPrimitive{Complex{Int32}}([1], [Complex{Int32}(1, 2)])
        @test deepequal(result, expected)
    end
end


@testset "ConvertToMATLAB-Primitives-Arrays" begin

    @testset "Convert-Float64-Vector" begin
        arr = [1.0, 2.0, 3.0]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayPrimitive{Float64}([3], arr)
        @test deepequal(result, expected)
    end

    @testset "Convert-Float64-Matrix" begin
        arr = [1.0 2.0; 3.0 4.0]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayPrimitive{Float64}([2, 2], vec(arr))
        @test deepequal(result, expected)
    end

    @testset "Convert-Float64-3D-Array" begin
        arr = reshape(collect(Float64(i) for i in 1:24), (2, 3, 4))
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayPrimitive{Float64}([2, 3, 4], vec(arr))
        @test deepequal(result, expected)
    end

    @testset "Convert-Int32-Vector" begin
        arr = Int32[1, 2, 3, 4, 5]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayPrimitive{Int32}([5], arr)
        @test deepequal(result, expected)
    end

    @testset "Convert-Bool-Vector" begin
        arr = [true, false, true, false]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayPrimitive{Bool}([4], arr)
        @test deepequal(result, expected)
    end

    @testset "Convert-Complex-Float64-Vector" begin
        arr = [Complex{Float64}(1.0, 2.0), Complex{Float64}(3.0, 4.0)]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayPrimitive{Complex{Float64}}([2], arr)
        @test deepequal(result, expected)
    end

    @testset "Convert-Empty-Float64-Array" begin
        arr = Float64[]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayEmpty()
        @test deepequal(result, expected)
    end
end


@testset "ConvertToMATLAB-Strings" begin

    @testset "Convert-String-Scalar" begin
        result = convert_matfrostarray("hello")
        expected = MATFrostArrayString([1], ["hello"])
        @test deepequal(result, expected)
    end

    @testset "Convert-String-Empty" begin
        result = convert_matfrostarray("")
        expected = MATFrostArrayString([1], [""])
        @test deepequal(result, expected)
    end

    @testset "Convert-String-Unicode" begin
        result = convert_matfrostarray("Hello 世界 🚀")
        expected = MATFrostArrayString([1], ["Hello 世界 🚀"])
        @test deepequal(result, expected)
    end

    @testset "Convert-String-Vector" begin
        arr = ["hello", "world", "test"]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayString([3], arr)
        @test deepequal(result, expected)
    end

    @testset "Convert-String-Matrix" begin
        arr = ["a" "b"; "c" "d"]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayString([2, 2], vec(arr))
        @test deepequal(result, expected)
    end

    @testset "Convert-Empty-String-Array" begin
        arr = String[]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayEmpty()
        @test deepequal(result, expected)
    end
end


@testset "ConvertToMATLAB-Structs" begin

    @testset "Convert-Struct-Scalar-SingleField" begin
        struct TestStruct1
            x::Float64
        end
        obj = TestStruct1(42.0)
        result = convert_matfrostarray(obj)

        field_val = MATFrostArrayPrimitive{Float64}([1], [42.0])
        expected = MATFrostArrayStruct([1], [:x], [field_val])
        @test deepequal(result, expected)
    end

    @testset "Convert-Struct-Scalar-MultipleFields" begin
        struct TestStruct2
            x::Float64
            y::Int32
            name::String
        end
        obj = TestStruct2(1.5, Int32(42), "test")
        result = convert_matfrostarray(obj)

        field1 = MATFrostArrayPrimitive{Float64}([1], [1.5])
        field2 = MATFrostArrayPrimitive{Int32}([1], Int32[42])
        field3 = MATFrostArrayString([1], ["test"])
        expected = MATFrostArrayStruct([1], [:x, :y, :name], [field1, field2, field3])
        @test deepequal(result, expected)
    end

    @testset "Convert-Struct-Array" begin
        struct TestStruct3
            value::Float64
        end
        arr = [TestStruct3(1.0), TestStruct3(2.0), TestStruct3(3.0)]
        result = convert_matfrostarray(arr)

        field1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        field2 = MATFrostArrayPrimitive{Float64}([1], [2.0])
        field3 = MATFrostArrayPrimitive{Float64}([1], [3.0])
        expected = MATFrostArrayStruct([3], [:value], [field1, field2, field3])
        @test deepequal(result, expected)
    end

    @testset "Convert-Struct-Matrix" begin
        struct TestStruct4
            val::Int32
        end
        arr = [TestStruct4(Int32(1)) TestStruct4(Int32(2)); TestStruct4(Int32(3)) TestStruct4(Int32(4))]
        result = convert_matfrostarray(arr)

        field1 = MATFrostArrayPrimitive{Int32}([1], Int32[1])
        field2 = MATFrostArrayPrimitive{Int32}([1], Int32[3])
        field3 = MATFrostArrayPrimitive{Int32}([1], Int32[2])
        field4 = MATFrostArrayPrimitive{Int32}([1], Int32[4])
        expected = MATFrostArrayStruct([2, 2], [:val], [field1, field2, field3, field4])
        @test deepequal(result, expected)
    end

    @testset "Convert-Struct-Nested" begin
        struct InnerStruct
            inner_val::Float64
        end
        struct OuterStruct
            outer_val::Int32
            nested::InnerStruct
        end
        obj = OuterStruct(Int32(42), InnerStruct(99.0))
        result = convert_matfrostarray(obj)

        inner_field = MATFrostArrayPrimitive{Float64}([1], [99.0])
        inner_struct = MATFrostArrayStruct([1], [:inner_val], [inner_field])
        outer_field1 = MATFrostArrayPrimitive{Int32}([1], Int32[42])
        expected = MATFrostArrayStruct([1], [:outer_val, :nested], [outer_field1, inner_struct])
        @test deepequal(result, expected)
    end

    @testset "Convert-Empty-Struct-Array" begin
        struct TestStruct5
            x::Float64
        end
        arr = TestStruct5[]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayEmpty()
        @test deepequal(result, expected)
    end
end


@testset "ConvertToMATLAB-Tuples" begin

    @testset "Convert-Tuple-SingleElement" begin
        tup = (42.0,)
        result = convert_matfrostarray(tup)

        inner = MATFrostArrayPrimitive{Float64}([1], [42.0])
        expected = MATFrostArrayCell([1], [inner])
        @test deepequal(result, expected)
    end

    @testset "Convert-Tuple-MultipleElements" begin
        tup = (1.0, "hello", Int32(42))
        result = convert_matfrostarray(tup)

        inner1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        inner2 = MATFrostArrayString([1], ["hello"])
        inner3 = MATFrostArrayPrimitive{Int32}([1], Int32[42])
        expected = MATFrostArrayCell([3], [inner1, inner2, inner3])
        @test deepequal(result, expected)
    end

    @testset "Convert-Tuple-Nested" begin
        tup = (1.0, (2.0, 3.0))
        result = convert_matfrostarray(tup)

        inner1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        nested_inner1 = MATFrostArrayPrimitive{Float64}([1], [2.0])
        nested_inner2 = MATFrostArrayPrimitive{Float64}([1], [3.0])
        nested = MATFrostArrayCell([2], [nested_inner1, nested_inner2])
        expected = MATFrostArrayCell([2], [inner1, nested])
        @test deepequal(result, expected)
    end

    @testset "Convert-Array-Of-Tuples" begin
        arr = [(1.0, 2.0), (3.0, 4.0)]
        result = convert_matfrostarray(arr)

        tuple1_elem1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        tuple1_elem2 = MATFrostArrayPrimitive{Float64}([1], [2.0])
        tuple1 = MATFrostArrayCell([2], [tuple1_elem1, tuple1_elem2])

        tuple2_elem1 = MATFrostArrayPrimitive{Float64}([1], [3.0])
        tuple2_elem2 = MATFrostArrayPrimitive{Float64}([1], [4.0])
        tuple2 = MATFrostArrayCell([2], [tuple2_elem1, tuple2_elem2])

        expected = MATFrostArrayCell([2], [tuple1, tuple2])
        @test deepequal(result, expected)
    end

    @testset "Convert-Empty-Tuple-Array" begin
        arr = Tuple{Float64, Float64}[]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayEmpty()
        @test deepequal(result, expected)
    end
end


@testset "ConvertToMATLAB-Arrays-Of-Arrays" begin

    @testset "Convert-Vector-Of-Vectors" begin
        arr = [[1.0, 2.0], [3.0, 4.0, 5.0]]
        result = convert_matfrostarray(arr)

        inner1 = MATFrostArrayPrimitive{Float64}([2], [1.0, 2.0])
        inner2 = MATFrostArrayPrimitive{Float64}([3], [3.0, 4.0, 5.0])
        expected = MATFrostArrayCell([2], [inner1, inner2])
        @test deepequal(result, expected)
    end

    @testset "Convert-Matrix-Of-Vectors" begin
        # Create a proper 2x2 matrix of vectors (not scalars)
        arr = Matrix{Vector{Float64}}(undef, 2, 2)
        arr[1,1] = [1.0]
        arr[2,1] = [3.0]
        arr[1,2] = [2.0]
        arr[2,2] = [4.0]
        result = convert_matfrostarray(arr)

        inner1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        inner2 = MATFrostArrayPrimitive{Float64}([1], [3.0])
        inner3 = MATFrostArrayPrimitive{Float64}([1], [2.0])
        inner4 = MATFrostArrayPrimitive{Float64}([1], [4.0])
        expected = MATFrostArrayCell([2, 2], [inner1, inner2, inner3, inner4])
        @test deepequal(result, expected)
    end

    @testset "Convert-Empty-Array-Of-Arrays" begin
        arr = Vector{Float64}[]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayEmpty()
        @test deepequal(result, expected)
    end
end


@testset "ConvertToMATLAB-Exceptions" begin

    @testset "Exception-Unsupported-Type" begin
        # Test that unsupported types throw appropriate exceptions
        # The function checks isprimitivetype, so types like BigInt won't be supported
        @test_throws MATFrostConversionException convert_matfrostarray(BigInt(123))
    end

    @testset "Exception-Message-Format" begin
        try
            convert_matfrostarray(BigInt(123))
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:unsupportedDatatype"
            @test occursin("BigInt", e.message)
            @test occursin("not supported", e.message)
        end
    end
end


@testset "ConvertToMATLAB-EdgeCases" begin

    @testset "Convert-Single-Element-Array" begin
        arr = [42.0]
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayPrimitive{Float64}([1], [42.0])
        @test deepequal(result, expected)
    end

    @testset "Convert-Large-Array" begin
        arr = collect(Float64(i) for i in 1:10000)
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayPrimitive{Float64}([10000], arr)
        @test deepequal(result, expected)
    end

    @testset "Convert-High-Dimensional-Array" begin
        arr = reshape(collect(Float64(i) for i in 1:120), (2, 3, 4, 5))
        result = convert_matfrostarray(arr)
        expected = MATFrostArrayPrimitive{Float64}([2, 3, 4, 5], vec(arr))
        @test deepequal(result, expected)
    end
end


@testset "convert_matfrostarray Vector{NamedTuple}" begin
    v = NamedTuple[ (a=1, b="x"), (a=2, b="y") ]
    result = convert_matfrostarray(v)
    @test result isa MATFrostArrayCell
    @test length(result.values) == 2
    @test result.values[1] isa MATFrostArrayCell || result.values[1] isa MATFrostArrayStruct
end

end
