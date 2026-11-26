using MATFrost
using DataFrames
using Test

@testset "DataFrame table transport" begin
    encode = MATFrost._ConvertToMATLAB.convert_matfrostarray
    decode = MATFrost._ConvertToJulia.convert_matfrostarray
    frame = DataFrame(
        identifier=Int64[1, 2], measurement=Float32[1.5, NaN],
        valid=Bool[true, false], label=String["a", "β"],
        complex=ComplexF64[1 + 2im, 3 - 4im],
    )
    for original in (frame, frame[1:0, :], DataFrame(), frame[1:1, :])
        wire = MATFrost.dataframe_to_table(original)
        handle = MATFrost.table_to_dataframe(decode(MATFrost.TableWire, encode(wire)))
        try
            @test isequal(MATFrost.resolve_handle(handle), original)
            @test decode(DataFrame, encode(handle)) === MATFrost.resolve_handle(handle)
            @test isequal(MATFrost.dataframe_to_table(handle).columns, wire.columns)
        finally
            @test MATFrost.release_handle(handle)
        end
        @test_throws ArgumentError MATFrost.dataframe_to_table(handle)
    end

    for T in (Bool, Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64,
              Float32, Float64, ComplexF32, ComplexF64, String)
        values = T === String ? T["x"] : T[1]
        original = DataFrame(column=values)
        handle = MATFrost.table_to_dataframe(decode(MATFrost.TableWire,
            encode(MATFrost.dataframe_to_table(original))))
        try
            @test isequal(MATFrost.resolve_handle(handle), original)
        finally
            MATFrost.release_handle(handle)
        end
    end

    @test_throws ArgumentError MATFrost.dataframe_to_table(DataFrame(x=Union{Missing,Int}[1, missing]))
    @test_throws ArgumentError MATFrost.dataframe_to_table(DataFrame(x=Any[1, "x"]))
    @test_throws ArgumentError MATFrost.dataframe_to_table(123)
    @test_throws ArgumentError MATFrost.table_to_dataframe(
        MATFrost.TableWire(["x"], ["int64"], Any[Int64[1]], 2))
    @test_throws ArgumentError MATFrost.table_to_dataframe(
        MATFrost.TableWire(["x", "x"], ["int64", "int64"], Any[Int64[1], Int64[2]], 1))
    @test_throws ArgumentError MATFrost.table_to_dataframe(
        MATFrost.TableWire(String[], String[], Any[], 1))
    @test_throws ArgumentError decode(MATFrost.TableWire, encode(
        MATFrost.TableWire(["x"], ["unsupported"], Any[Int64[1]], 1)))
end
