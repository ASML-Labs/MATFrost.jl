module ReadTest

using Test
using JET

using ..Types
using ..BufferPrimitives

using MATFrost: MATFrost
using MATFrost._Read: read_matfrostarray!
using MATFrost._Types


"""
Scalar: Number, String
Array: Number, String
"""
function deepequal(a::T, b::T) where {T<:Union{Number, String, Array{<:Number}, Array{String}}} 
    return a==b
end

"""
Array: Structs, NamedTuple, Tuple
"""
function deepequal(a::Array, b::Array)
    typeof(a) == typeof(b) || return false
    size(a) == size(b)     || return false
    for i in eachindex(a)
        deepequal(a[i], b[i]) || return false
    end
    return true
end

"""
Scalar: Structs, NamedTuple, Tuple
"""
function deepequal(a, b)
    typeof(a) == typeof(b) || return false
    N = fieldcount(typeof(a))
    for i in 1:N
        deepequal(getfield(a, i), getfield(b, i)) || return false
    end
    return true
end


primitive_tests = (
    (Float32, Float32(4321)),
    (Float64, 4321.4321),

    (Int8,  Int8(-21)),
    (UInt8,  UInt8(21)),
    (Int16,  Int16(-4321)),
    (UInt16, UInt16(4321)),
    (Int32,  Int32(-433421)),
    (UInt32, UInt32(43321)),
    (Int64,  Int64(-4323421)),
    (UInt64, UInt64(4323421)),
    
    
)

function test_matfrostarray_read(v_write, v_exp)
    buffer = IOBuffer()
    _writebuffermatfrostarray!(buffer, v_write)
    _addbuffer!(buffer, 20)

    v_act = read_matfrostarray!(buffer)

    t_nb_read = bytesavailable(buffer) == 20
    t_v_correct = deepequal(v_act, v_exp)
    return t_nb_read && t_v_correct
end

@testset "Primitives-Behavior-Boolean" begin
    @testset "Read-Scalar" begin
        v_write = true
        v_exp = MATFrostArrayPrimitive{Bool}([1], [true])
        @test test_matfrostarray_read(v_write, v_exp)
    end

    @testset "Read-Vector" begin
        v_write = [true, false, true]
        v_exp = MATFrostArrayPrimitive{Bool}([3], v_write)
        @test test_matfrostarray_read(v_write, v_exp)
    end

    
    @testset "Read-Matrix" begin
        v_write = [true false true; false false true; false false false]
        v_exp = MATFrostArrayPrimitive{Bool}([3,3], vec(v_write))
        @test test_matfrostarray_read(v_write, v_exp)
    end
end


@testset "Primitives-Behavior-$(pt[1])" for pt in primitive_tests 
    
    @testset "Read-Scalar" begin
        v_write = pt[2]
        v_exp = MATFrostArrayPrimitive{pt[1]}([1], [pt[2]])
        @test test_matfrostarray_read(v_write, v_exp)
    end

    @testset "Read-ComplexScalar" begin
        v_write = Complex{pt[1]}(pt[2], pt[1](2) * pt[2])
        v_exp = MATFrostArrayPrimitive{Complex{pt[1]}}([1], [v_write])
        @test test_matfrostarray_read(v_write, v_exp)
    end

    @testset "Read-Vector" begin        
        v_write = pt[1][pt[2], pt[2]+1, pt[2]+2]
        v_exp = MATFrostArrayPrimitive{pt[1]}([3], v_write)
        @test test_matfrostarray_read(v_write, v_exp)

    end

    @testset "Read-ComplexVector" begin
        v = Complex{pt[1]}(pt[2], pt[1](2) * pt[2])
        v_write= Complex{pt[1]}[v + 1, v+2, v+3]
        v_exp = MATFrostArrayPrimitive{Complex{pt[1]}}([3], v_write)
        @test test_matfrostarray_read(v_write, v_exp)
    end

    @testset "Read-Matrix" begin
        v_write = Matrix{pt[1]}(undef, (7,5))
        for i in eachindex(v_write)
            v_write[i] = pt[2] + pt[1](i)
        end
        v_exp = MATFrostArrayPrimitive{pt[1]}([7, 5], vec(v_write))
        @test test_matfrostarray_read(v_write, v_exp)
    end

    @testset "Read-ComplexMatrix" begin
        v_write = Matrix{Complex{pt[1]}}(undef, (5,7))
        for i in eachindex(v_write)
            v_write[i] = Complex{pt[1]}(pt[2], pt[1](i)+3)
        end
        v_exp = MATFrostArrayPrimitive{Complex{pt[1]}}([5, 7], vec(v_write))
        @test test_matfrostarray_read(v_write, v_exp)
    end
    

end

end