using Test
using UUIDs
using TOML
using MATFrost
using MATFrost._Types

if VERSION >= v"1.11"
    using MATFrostGeometryExt
end

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

    @testset "Opt-in handle conversion" begin
        object = HandleTestType("Amsterdam")

        converted =
            MATFrost._ConvertToMATLAB.convert_matfrostarray(object)

        @test converted isa MATFrostArrayStruct
        @test converted.fieldnames == Symbol[:dataType, :id, :typename]
        @test converted.values[1].values[1] == "matfrost_handle"
        @test converted.values[3].values[1] == string(HandleTestType)

        restored =
            MATFrost._ConvertToJulia.convert_matfrostarray(
                HandleTestType,
                converted,
            )

        @test restored === object
        @test restored.value == "Amsterdam"

        @test MATFrost.release_handle(
            UUID(converted.values[2].values[1]),
        )
    end

    @testset "reject incompatible handle target" begin
        object = HandleTestType("Amsterdam")
        converted =
            MATFrost._ConvertToMATLAB.convert_matfrostarray(object)

        @test_throws MATFrostConversionException begin
            MATFrost._ConvertToJulia.convert_matfrostarray(
                String,
                converted,
            )
        end

        MATFrost.release_all_handles!()
    end
end

if VERSION >= v"1.11"
@testset "Geometry handle extension" begin
    @test !isdefined(Main, :Geometry)

    @eval Main using Geometry

    geometry_project = TOML.parsefile(
        joinpath(dirname(pathof(Geometry)), "..", "Project.toml"),
    )
    @test !haskey(get(geometry_project, "deps", Dict{String,Any}()), "MATFrost")
    @test MATFrost.use_matfrost_handle(Geometry.Point)

    point = Geometry.Point("Amsterdam")
    converted = MATFrost._ConvertToMATLAB.convert_matfrostarray(point)
    @test converted isa MATFrostArrayStruct
    @test converted.values[3].values[1] == string(Geometry.Point)

    restored = MATFrost._ConvertToJulia.convert_matfrostarray(
        Geometry.Point,
        converted,
    )
    @test restored === point
    @test Geometry.get_label(restored) == "Amsterdam"

    try
        nothing
    finally
        MATFrost.release_all_handles!()
    end
end
end