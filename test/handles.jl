using Test
using UUIDs
using MATFrost

mutable struct TransportHandleValue
    value::Int64
end

struct OtherTransportHandleValue
    value::Int64
end

struct PlainTransportValue
    value::Int64
end

MATFrost.use_matfrost_handle(::Type{TransportHandleValue}) = true
MATFrost.use_matfrost_handle(::Type{OtherTransportHandleValue}) = true

@testset "MATFrost handles" begin

    @testset "store and resolve" begin
        obj = Ref(42)

        handle = MATFrost.store_handle(obj)

        @test handle isa MATFrost.MATFrostHandle
        @test handle.id isa UUID

        resolved = MATFrost.resolve_handle(handle)

        @test resolved === obj

        @test MATFrost.release_handle(handle)
    end

    @testset "release" begin
        handle = MATFrost.store_handle(Ref(123))

        @test MATFrost.release_handle(handle)

        @test_throws ArgumentError MATFrost.resolve_handle(handle)

        @test !MATFrost.release_handle(handle)
    end

    @testset "release stored nothing" begin
        previous_count = MATFrost.handle_count()
        handle = MATFrost.store_handle(nothing)

        @test MATFrost.resolve_handle(handle) === nothing
        @test MATFrost.release_handle(handle.id)
        @test MATFrost.handle_count() == previous_count
        @test !MATFrost.release_handle(handle)
        @test_throws ArgumentError MATFrost.resolve_handle(handle)
    end

    @testset "release all" begin
        h1 = MATFrost.store_handle(Ref(1))
        h2 = MATFrost.store_handle(Ref(2))

        MATFrost.release_all_handles!()

        @test_throws ArgumentError MATFrost.resolve_handle(h1)
        @test_throws ArgumentError MATFrost.resolve_handle(h2)
    end

    @testset "default handle trait" begin
        struct DummyType
        end

        @test !MATFrost.use_matfrost_handle(Int64)
        @test !MATFrost.use_matfrost_handle(String)
        @test !MATFrost.use_matfrost_handle(DummyType)
    end

    @testset "handle transport" begin
        to_matlab = MATFrost._ConvertToMATLAB.convert_matfrostarray
        to_julia = MATFrost._ConvertToJulia.convert_matfrostarray
        object = TransportHandleValue(42)
        wire = to_matlab(object)

        try
            @test wire isa MATFrost._Types.MATFrostArrayStruct
            @test wire.fieldnames == Symbol[:dataType, :id, :typename]
            @test wire.values[1].values[1] == "matfrost_handle"
            @test wire.values[3].values[1] == string(TransportHandleValue)
            @test to_julia(TransportHandleValue, wire) === object

            restored = to_julia(TransportHandleValue, wire)
            restored.value = 100
            @test object.value == 100

            buffer = IOBuffer()
            MATFrost._Write.write_matfrostarray!(buffer, wire)
            seekstart(buffer)
            restored_wire = MATFrost._Read.read_matfrostarray!(buffer)
            @test bytesavailable(buffer) == 0
            @test to_julia(TransportHandleValue, restored_wire) === object
            @test_throws ArgumentError to_julia(OtherTransportHandleValue, wire)

            invalid_wire = MATFrost._Types.MATFrostArrayStruct(
                wire.dims, wire.fieldnames, copy(wire.values),
            )
            invalid_wire.values[1] = to_matlab("invalid_handle_marker")
            @test_throws ArgumentError to_julia(TransportHandleValue, invalid_wire)

            missing_marker = MATFrost._Types.MATFrostArrayStruct(
                wire.dims, wire.fieldnames[2:end], wire.values[2:end],
            )
            @test_throws ArgumentError to_julia(TransportHandleValue, missing_marker)

            handle = to_julia(MATFrost.MATFrostHandle, wire)
            @test MATFrost.release_handle(handle)
            @test_throws ArgumentError to_julia(TransportHandleValue, wire)

            unknown = MATFrost.MATFrostHandle(uuid4(), string(TransportHandleValue))
            @test_throws ArgumentError to_julia(TransportHandleValue, to_matlab(unknown))

            plain = PlainTransportValue(7)
            plain_wire = to_matlab(plain)
            @test plain_wire.fieldnames == Symbol[:value]
            @test to_julia(PlainTransportValue, plain_wire) == plain
        finally
            MATFrost.release_all_handles!()
        end
    end

end