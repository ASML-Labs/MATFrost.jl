module PrimitiveTests

using Test
using ..Types
using ..BufferPrimitives
using MATFrost._Read: read_matfrostarray!


stream = IOBuffer()

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

@testset "Primitives-Behavior-$(pt[1])" for pt in primitive_tests 
    
    @testset "Read-Scalar" begin
        _clearbuffer!(stream)
        _writebuffermatfrostarray!(stream, pt[2])
        _addbuffer!(stream, 20)
        @test read_matfrostarray!(stream, pt[1]) == pt[2]
        @test bytesavailable(stream) == 20
    end

    @testset "Read-ComplexScalar" begin
        _clearbuffer!(stream)
        v = Complex{pt[1]}(pt[2], pt[1](2) * pt[2])
        _writebuffermatfrostarray!(stream, v)
        _addbuffer!(stream, 20)
        @test read_matfrostarray!(stream, Complex{pt[1]}).x.x == v
        @test bytesavailable(stream) == 20
    end

    @testset "Read-Vector" begin
        _clearbuffer!(stream)
        arr = pt[1][pt[2], pt[2]+1, pt[2]+2]
        _writebuffermatfrostarray!(stream, arr)
        _addbuffer!(stream, 20)
        @test read_matfrostarray!(stream, Vector{pt[1]}).x.x == arr
        @test bytesavailable(stream) == 20
        
    end

    @testset "Read-ComplexVector" begin
        _clearbuffer!(stream)
        v = Complex{pt[1]}(pt[2], pt[1](2) * pt[2])
        arr= Complex{pt[1]}[v + 1, v+2, v+3]
        _writebuffermatfrostarray!(stream, arr)
        _addbuffer!(stream, 20)
        @test read_matfrostarray!(stream, Vector{Complex{pt[1]}}).x.x == arr
        @test bytesavailable(stream) == 20
    end

    @testset "Read-Matrix" begin
        _clearbuffer!(stream)
        arr = Matrix{pt[1]}(undef, (3,3))
        for i in eachindex(arr)
            arr[i] = pt[2] + pt[1](i)
        end
        _writebuffermatfrostarray!(stream, arr)
        _addbuffer!(stream, 20)
        @test read_matfrostarray!(stream, Matrix{pt[1]}).x.x == arr
        @test bytesavailable(stream) == 20
        
    end
    

end


@testset "String-Scalar" begin
    _clearbuffer!(stream)
    _writebuffermatfrostarray!(stream, "Test4321")
    _addbuffer!(stream, 20)
    @test read_matfrostarray!(stream, String).x.x == "Test4321"
    @test bytesavailable(stream) == 20
end


@testset "String-Array" begin
    _clearbuffer!(stream)
    _writebuffermatfrostarray!(stream, ["Test4321", "Test1234", "Test6789"])
    _addbuffer!(stream, 20)
    @test read_matfrostarray!(stream, Vector{String}).x.x == ["Test4321", "Test1234", "Test6789"]
    @test bytesavailable(stream) == 20
end


end

# @testset "Primitives-JET-Opt" begin
#     @testset "JET-Opt" begin
#         @test_opt read_matfrostarray!(stream, Int64)
#     end
    
#     @testset "JET-Call" begin
#         @test_call read_matfrostarray!(stream, Int64)
#     end

# end