using Test
using MATFrost._Types
using MATFrost._Read: read_matfrostarray!
using MATFrost._Write: write_matfrostarray!

const _toMATLAB = MATFrost._ConvertToMATLAB.convert_matfrostarray
const _toJulia  = MATFrost._ConvertToJulia.convert_matfrostarray

# Serialize to the MATFrost wire format and read it back, as the MATLAB side would receive it.
function _wire_roundtrip(marr::MATFrostArrayAbstract)
    io = IOBuffer()
    write_matfrostarray!(io, marr)
    seekstart(io)
    read_matfrostarray!(io)
end

_same(a::MATFrostArrayPrimitive{T}, b::MATFrostArrayPrimitive{T}) where T = a.dims == b.dims && a.values == b.values
_same(a::MATFrostArrayString, b::MATFrostArrayString) = a.dims == b.dims && a.values == b.values
_same(::MATFrostArrayEmpty, ::MATFrostArrayEmpty) = true
_same(a, b) = false

@testset "Julia -> MATLAB: non-Array AbstractArrays are materialized" begin
    # Each value must convert exactly like its dense `Array` equivalent, not as a struct of internals.
    cases = Any[
        [1.0, -2.0, 3.0] .> 0,                 # BitVector (result of any broadcast comparison)
        trues(2, 3),                           # BitMatrix
        falses(2, 2, 2),                       # BitArray{3}
        1:5,                                   # UnitRange{Int64}
        0.0:0.5:2.0,                           # StepRangeLen{Float64}
        Int32(1):Int32(2):Int32(9),            # StepRange{Int32}
        view([1.0, 2.0, 3.0, 4.0], 2:3),       # contiguous SubArray
        view([1 2 3; 4 5 6], :, [1, 3]),       # non-contiguous SubArray
        [1 2; 3 4]',                           # Adjoint
        transpose(ComplexF64[1+2im 3; 4 5im]), # Transpose of complex
        reshape(1:6, 2, 3),                    # ReshapedArray
        view(["a", "b", "c"], 2:3),            # SubArray of String
    ]
    for v in cases
        @testset "$(typeof(v))" begin
            expected = _toMATLAB(Array(v))
            got = _toMATLAB(v)
            @test !(got isa MATFrostArrayStruct)
            @test _same(got, expected)
            @test _same(_wire_roundtrip(got), expected)
        end
    end

    @testset "BitArray becomes MATLAB logical" begin
        got = _toMATLAB(BitVector([true, false, true]))
        @test got isa MATFrostArrayPrimitive{Bool}
        @test got.dims == [3]
        @test got.values == [true, false, true]
    end

    @testset "empty AbstractArrays become empty" begin
        @test _toMATLAB(1:0) isa MATFrostArrayEmpty
        @test _toMATLAB(falses(0)) isa MATFrostArrayEmpty
    end

    @testset "nested inside structs, tuples and cells" begin
        nt = (mask = [1, 2, 3] .> 1, idx = 1:3)
        m = _toMATLAB(nt)
        @test m isa MATFrostArrayStruct
        @test m.values[1] isa MATFrostArrayPrimitive{Bool}
        @test m.values[1].values == [false, true, true]
        @test m.values[2] isa MATFrostArrayPrimitive{Int64}
        @test m.values[2].values == [1, 2, 3]

        c = _toMATLAB((1:2, trues(1)))
        @test c isa MATFrostArrayCell
        @test c.values[1] isa MATFrostArrayPrimitive{Int64}
        @test c.values[2] isa MATFrostArrayPrimitive{Bool}
    end

    @testset "arrays whose elements are BitArrays, ranges or views become cells" begin
        for v in Any[[trues(2), falses(3)], [1:2, 3:5], [view([1.0, 2.0, 3.0], 1:2)]]
            m = _toMATLAB(v)
            @test m isa MATFrostArrayCell
            @test length(m.values) == length(v)
            for (el, mel) in zip(v, m.values)
                @test _same(mel, _toMATLAB(Array(el)))
            end
        end
    end
end

@testset "MATLAB -> Julia: logical arrays to BitArray" begin
    @testset "BitVector" begin
        marr = MATFrostArrayPrimitive{Bool}(Int64[3], Bool[true, false, true])
        v = _toJulia(BitVector, marr)
        @test v isa BitVector
        @test v == BitVector([true, false, true])
    end

    @testset "BitMatrix keeps column-major layout" begin
        marr = MATFrostArrayPrimitive{Bool}(Int64[2, 3], Bool[true, false, false, true, true, false])
        v = _toJulia(BitMatrix, marr)
        @test v isa BitMatrix
        @test v == Bool[true false true; false true false]
    end

    @testset "empty" begin
        v = _toJulia(BitVector, MATFrostArrayEmpty())
        @test v isa BitVector
        @test isempty(v)
    end

    @testset "wrong datatype is rejected" begin
        marr = MATFrostArrayPrimitive{Float64}(Int64[2], Float64[1.0, 0.0])
        @test_throws MATFrostConversionException _toJulia(BitVector, marr)
    end

    @testset "wrong dimensions are rejected" begin
        marr = MATFrostArrayPrimitive{Bool}(Int64[2, 2], Bool[true, false, true, false])
        @test_throws MATFrostConversionException _toJulia(BitVector, marr)
    end

    @testset "round trip Julia -> MATLAB -> Julia" begin
        b = rand(Bool, 4, 5) |> BitMatrix
        @test _toJulia(BitMatrix, _wire_roundtrip(_toMATLAB(b))) == b
    end

    @testset "MATLAB-shaped dims (row and column vectors)" begin
        for dims in ([3, 1], [1, 3])
            marr = MATFrostArrayPrimitive{Bool}(Int64[dims...], Bool[true, false, true])
            @test _toJulia(BitVector, marr) == BitVector([true, false, true])
        end
    end

    @testset "cell of logicals to Vector{BitVector}" begin
        cell = MATFrostArrayCell(Int64[1, 2], MATFrostArrayAbstract[
            MATFrostArrayPrimitive{Bool}(Int64[1, 2], Bool[true, false]),
            MATFrostArrayPrimitive{Bool}(Int64[1, 1], Bool[true])])
        v = _toJulia(Vector{BitVector}, _wire_roundtrip(cell))
        @test v isa Vector{BitVector}
        @test v == [BitVector([true, false]), BitVector([true])]

        vv = [trues(2), falses(3)]
        @test _toJulia(Vector{BitVector}, _wire_roundtrip(_toMATLAB(vv))) == vv
    end
end
