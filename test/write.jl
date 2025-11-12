module WriteTest

using Test
using JET

using ..Types
using ..BufferPrimitives

using MATFrost: MATFrost
using MATFrost._Write: write_matfrostarray!, write_matfrostarray_empty!, write_matfrostarray_primitive!, write_matfrostarray_string!, write_matfrostarray_cell!, write_matfrostarray_struct!
using MATFrost._Read: read_matfrostarray!
using MATFrost._Stream: BufferedUDS, Buffer
using MATFrost._Types
using MATFrost._Constants


"""
Deep equality check for comparing values
"""
function deepequal(a::T, b::T) where {T<:Union{Number, String, Array{<:Number}, Array{String}}}
    return a==b
end

function deepequal(a::Array, b::Array)
    typeof(a) == typeof(b) || return false
    size(a) == size(b)     || return false
    for i in eachindex(a)
        deepequal(a[i], b[i]) || return false
    end
    return true
end

function deepequal(a, b)
    typeof(a) == typeof(b) || return false
    N = fieldcount(typeof(a))
    for i in 1:N
        deepequal(getfield(a, i), getfield(b, i)) || return false
    end
    return true
end

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


buffer = Buffer(Vector{UInt8}(undef, 2 << 16), 0, 0)
stream = BufferedUDS(C_NULL, buffer, buffer)

function test_write_read_roundtrip(marr::MATFrostArrayAbstract)
    _clearbuffer!(buffer)
    write_matfrostarray!(stream, marr)

    v_read = read_matfrostarray!(stream)

    return deepequal(marr, v_read)
end


primitive_tests = (
    (Bool, true),
    (Bool, false),
    (Float32, Float32(4321.1)),
    (Float64, 4321.4321),
    (Int8,  Int8(-21)),
    (UInt8,  UInt8(21)),
    (Int16,  Int16(-4321)),
    (UInt16, UInt16(4321)),
    (Int32,  Int32(-433421)),
    (UInt32, UInt32(43321)),
    (Int64,  Int64(-4323421)),
    (UInt64, UInt64(4323421)),
    (Complex{Float32}, Complex{Float32}(1.0, 2.0)),
    (Complex{Float64}, Complex{Float64}(1.0, 2.0)),
    (Complex{Int8}, Complex{Int8}(1, 2)),
    (Complex{UInt8}, Complex{UInt8}(1, 2)),
    (Complex{Int16}, Complex{Int16}(1, 2)),
    (Complex{UInt16}, Complex{UInt16}(1, 2)),
    (Complex{Int32}, Complex{Int32}(1, 2)),
    (Complex{UInt32}, Complex{UInt32}(1, 2)),
    (Complex{Int64}, Complex{Int64}(1, 2)),
    (Complex{UInt64}, Complex{UInt64}(1, 2)),
)


@testset "Write-Empty" begin
    @testset "Write-EmptyArray" begin
        marr = MATFrostArrayEmpty()
        @test test_write_read_roundtrip(marr)
    end
end


@testset "Write-Primitives-$(pt[1])" for pt in primitive_tests

    @testset "Write-Scalar" begin
        marr = MATFrostArrayPrimitive{pt[1]}([1], pt[1][pt[2]])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-Vector" begin
        vals = pt[1][pt[2], pt[2], pt[2]]
        marr = MATFrostArrayPrimitive{pt[1]}([3], vals)
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-Matrix" begin
        v = pt[2]
        vals = pt[1][v v v; v v v]
        marr = MATFrostArrayPrimitive{pt[1]}([2, 3], vec(vals))
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-3D-Array" begin
        v = pt[2]
        vals = reshape(pt[1][v, v, v, v, v, v, v, v, v, v, v, v], (2, 3, 2))
        marr = MATFrostArrayPrimitive{pt[1]}([2, 3, 2], vec(vals))
        @test test_write_read_roundtrip(marr)
    end
end


@testset "Write-Strings" begin

    @testset "Write-Scalar-String" begin
        marr = MATFrostArrayString([1], ["hello"])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-String-Vector" begin
        marr = MATFrostArrayString([3], ["hello", "world", "test"])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-String-Matrix" begin
        marr = MATFrostArrayString([2, 2], ["a", "b", "c", "d"])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-Empty-String" begin
        marr = MATFrostArrayString([1], [""])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-Unicode-String" begin
        marr = MATFrostArrayString([1], ["Hello 世界 🚀"])
        @test test_write_read_roundtrip(marr)
    end
end


@testset "Write-Cells" begin

    @testset "Write-Cell-Scalar" begin
        inner = MATFrostArrayPrimitive{Float64}([1], [1.0])
        marr = MATFrostArrayCell([1], [inner])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-Cell-Mixed-Types" begin
        inner1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        inner2 = MATFrostArrayString([1], ["test"])
        inner3 = MATFrostArrayPrimitive{Int32}([1], Int32[42])
        marr = MATFrostArrayCell([3], [inner1, inner2, inner3])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-Cell-Nested" begin
        inner1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        inner2 = MATFrostArrayString([1], ["test"])
        nested_cell = MATFrostArrayCell([2], [inner1, inner2])
        outer = MATFrostArrayCell([1], [nested_cell])
        @test test_write_read_roundtrip(outer)
    end

    @testset "Write-Cell-Matrix" begin
        inner1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        inner2 = MATFrostArrayPrimitive{Float64}([1], [2.0])
        inner3 = MATFrostArrayPrimitive{Float64}([1], [3.0])
        inner4 = MATFrostArrayPrimitive{Float64}([1], [4.0])
        marr = MATFrostArrayCell([2, 2], [inner1, inner2, inner3, inner4])
        @test test_write_read_roundtrip(marr)
    end
end


@testset "Write-Structs" begin

    @testset "Write-Struct-Scalar-SingleField" begin
        field_val = MATFrostArrayPrimitive{Float64}([1], [42.0])
        marr = MATFrostArrayStruct([1], [:value], [field_val])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-Struct-Scalar-MultipleFields" begin
        field1 = MATFrostArrayPrimitive{Float64}([1], [42.0])
        field2 = MATFrostArrayString([1], ["test"])
        field3 = MATFrostArrayPrimitive{Int32}([1], Int32[123])
        marr = MATFrostArrayStruct([1], [:x, :name, :id], [field1, field2, field3])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-Struct-Vector" begin
        # Two struct elements with two fields each
        field1_elem1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        field2_elem1 = MATFrostArrayString([1], ["first"])
        field1_elem2 = MATFrostArrayPrimitive{Float64}([1], [2.0])
        field2_elem2 = MATFrostArrayString([1], ["second"])
        marr = MATFrostArrayStruct([2], [:value, :name], [field1_elem1, field2_elem1, field1_elem2, field2_elem2])
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-Struct-Nested" begin
        # Inner struct
        inner_field = MATFrostArrayPrimitive{Float64}([1], [99.0])
        inner_struct = MATFrostArrayStruct([1], [:inner_val], [inner_field])

        # Outer struct containing the inner struct
        outer_field1 = MATFrostArrayPrimitive{Float64}([1], [42.0])
        outer_struct = MATFrostArrayStruct([1], [:outer_val, :nested], [outer_field1, inner_struct])
        @test test_write_read_roundtrip(outer_struct)
    end

    @testset "Write-Struct-Matrix" begin
        # 2x2 matrix of structs with one field each
        field1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        field2 = MATFrostArrayPrimitive{Float64}([1], [2.0])
        field3 = MATFrostArrayPrimitive{Float64}([1], [3.0])
        field4 = MATFrostArrayPrimitive{Float64}([1], [4.0])
        marr = MATFrostArrayStruct([2, 2], [:value], [field1, field2, field3, field4])
        @test test_write_read_roundtrip(marr)
    end
end


@testset "Write-EdgeCases" begin

    @testset "Write-LargeArray" begin
        large_vals = collect(Float64(i) for i in 1:10000)
        marr = MATFrostArrayPrimitive{Float64}([10000], large_vals)
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-HighDimensional" begin
        vals = collect(Float64(i) for i in 1:120)
        marr = MATFrostArrayPrimitive{Float64}([2, 3, 4, 5], vals)
        @test test_write_read_roundtrip(marr)
    end

    @testset "Write-ZeroInDimension" begin
        marr = MATFrostArrayPrimitive{Float64}([0], Float64[])
        _clearbuffer!(buffer)
        write_matfrostarray!(stream, marr)
        v_read = read_matfrostarray!(stream)
        # Zero-dimension arrays are read back as empty arrays
        @test v_read isa MATFrostArrayEmpty
    end
end

end
