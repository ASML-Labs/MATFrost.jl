using Test
using UUIDs
using MATFrost

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

end