

module IncompatiableDataTypesTest

using Test
using ..Types
using ..BufferPrimitives
using MATFrost._Read2: read_matfrostarray!
using MATFrost._Types

stream = IOBuffer()

struct StructTest1
    a::Float64
    b::Int64
    d::String
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

    (String, "TestString"),

    (StructTest1, StructTest1(3.0, 3, "FEFE")),

    (Tuple{Float64, Int64, String}, (3.0, 3, "FEFE"))


    
)


@testset "IncompatibleDatatype-Type target: $(pt[1])" for pt in primitive_tests
    pt_ex = (pt2 for pt2 in primitive_tests if pt2 != pt)
    @testset "Type source: $(pt2[1])" for pt2 in pt_ex

        @testset "Scalar-Target" begin
            _clearbuffer!(stream)
            _writebuffermatfrostarray!(stream, pt2[2])
            _addbuffer!(stream, 20)
            @test read_matfrostarray!(stream, pt[1]).x.x isa MATFrostException
            @test bytesavailable(stream) == 20
        end
        
        @testset "Vector-Target" begin
            _clearbuffer!(stream)
            _writebuffermatfrostarray!(stream, pt2[2])
            _addbuffer!(stream, 20)
            @test read_matfrostarray!(stream, Vector{pt[1]}).x.x isa MATFrostException
            @test bytesavailable(stream) == 20
        end
        
        @testset "Matrix-Target" begin
            _clearbuffer!(stream)
            _writebuffermatfrostarray!(stream, pt2[2])
            _addbuffer!(stream, 20)
            @test read_matfrostarray!(stream, Array{pt[1],2}).x.x isa MATFrostException
            @test bytesavailable(stream) == 20
        end
    end


end

end