using Test
using UUIDs
using MATFrost

struct HandleTestType
    value::String
end

MATFrost.use_matfrost_handle(
    ::Type{HandleTestType},
) = true
@testset "MATFrost handles" begin

    @testset "store and resolve" begin
        obj = Ref(42)

        handle = MATFrost.store_handle(obj)

        @test handle isa MATFrostHandle
        @test handle.id isa UUID

        resolved = resolve_handle(handle)

        @test resolved === obj

        @test MATFrost.release_handle(handle)
    end

    @testset "release" begin
        handle = MATFrost.store_handle(Ref(123))

        @test MATFrost.release_handle(handle)

        @test_throws ArgumentError resolve_handle(handle)

        @test !MATFrost.release_handle(handle)
    end

    @testset "release all" begin
        h1 = MATFrost.store_handle(Ref(1))
        h2 = MATFrost.store_handle(Ref(2))

        MATFrost.release_all_handles!()

        @test_throws ArgumentError resolve_handle(h1)
        @test_throws ArgumentError resolve_handle(h2)
    end

    @testset "default handle trait" begin
        struct DummyType
        end

        @test !use_matfrost_handle(Int64)
        @test !use_matfrost_handle(String)
        @test !use_matfrost_handle(DummyType)
    end

    @testset "Opt-in handle conversion" begin
        object = HandleTestType("Amsterdam")

        converted =
            MATFrost._ConvertToMATLAB.convert_matfrostarray(object)

        @test converted isa MATFrost.MATFrostHandle
        @test converted.typename == string(HandleTestType)

        restored =
            MATFrost._ConvertToJulia.convert_matfrostarray(
                HandleTestType,
                converted,
            )

        @test restored === object
        @test restored.value == "Amsterdam"

        @test MATFrost.release_handle(converted)
    end

    @testset "reject incompatible handle target" begin
    object = HandleTestType("Amsterdam")
    handle = MATFrost.store_handle(object)

    @test_throws ArgumentError begin
        MATFrost._ConvertToJulia.convert_matfrostarray(
            String,
            handle,
        )
    end

    @test MATFrost.release_handle(handle)
end
@testset "reject incompatible handle target" begin
    object = HandleTestType("Amsterdam")
    handle = MATFrost.store_handle(object)

    @test_throws ArgumentError begin
        MATFrost._ConvertToJulia.convert_matfrostarray(
            String,
            handle,
        )
    end

    @test MATFrost.release_handle(handle)
end
end

#= @testset "Handle consumers" begin

    using Geometry
    using MATFrostGeometryExt

    @testset "Geometry.Point opt-in" begin

        @test use_matfrost_handle(Geometry.Point)

        point = Geometry.Point("Amsterdam")

        handle = MATFrost.store_handle(point)

        @test resolve_handle(handle) === point

        @test Geometry.get_label(
            resolve_handle(handle)
        ) == "Amsterdam"

        @test MATFrost.release_handle(handle)

    end
end
=#