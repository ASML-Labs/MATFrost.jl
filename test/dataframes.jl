using Test
using DataFrames
using MATFrost
using MATFrost._Types
using MATFrostGeometryExt

using Geometry

struct PlainStruct
    label::String
    count::Int64
end

@testset "convert_to_matlab hook" begin

    @testset "default is identity" begin
        @test MATFrost.convert_to_matlab(42) === 42
        @test MATFrost.convert_to_matlab("Amsterdam") == "Amsterdam"
        @test MATFrost.convert_to_matlab(Geometry.Point("Amsterdam")) ==
            Geometry.Point("Amsterdam")
    end

    @testset "DataFrame maps onto DataFrameWire" begin
        df = Geometry.points_dataframe()
        wire = MATFrost.convert_to_matlab(df)

        @test wire isa MATFrostGeometryExt.DataFrameWire
        @test wire.dataType == "matfrost_table"
        @test wire.variable_names == ["label", "kind"]
        @test wire.variable_types == ["String", "String"]
        @test length(wire.columns) == 2
        @test wire.columns[1] == ["Amsterdam", "Eindhoven", "Veldhoven"]
        @test wire.columns[2] == ["city", "city", "city"]
    end

    @testset "views and subsets are supported" begin
        df = Geometry.points_dataframe()
        wire = MATFrost.convert_to_matlab(@view df[2:3, :])

        @test wire.variable_names == ["label", "kind"]
        @test wire.columns[1] == ["Eindhoven", "Veldhoven"]
    end

    @testset "mixed column types are preserved" begin
        wire = MATFrost.convert_to_matlab(
            DataFrame(label = ["a", "b"], count = Int64[1, 2], ratio = [0.5, 1.5]),
        )

        @test wire.variable_names == ["label", "count", "ratio"]
        @test wire.variable_types == ["String", "Int64", "Float64"]
        @test wire.columns[2] == Int64[1, 2]
        @test wire.columns[3] == [0.5, 1.5]
    end
end

@testset "DataFrame marshalling" begin

    @testset "wire struct layout" begin
        arr = MATFrost._ConvertToMATLAB.convert_matfrostarray(
            Geometry.points_dataframe(),
        )

        @test arr isa MATFrostArrayStruct
        @test arr.dims == Int64[1]
        @test arr.fieldnames ==
            Symbol[:dataType, :variable_names, :variable_types, :columns]

        datatype = arr.values[1]
        @test datatype isa MATFrostArrayString
        @test datatype.values == ["matfrost_table"]

        names = arr.values[2]
        @test names isa MATFrostArrayString
        @test names.values == ["label", "kind"]

        columns = arr.values[4]
        @test columns isa MATFrostArrayCell
        @test length(columns.values) == 2
        @test columns.values[1] isa MATFrostArrayString
        @test columns.values[1].dims == Int64[3]
        @test columns.values[1].values == ["Amsterdam", "Eindhoven", "Veldhoven"]
    end

    @testset "numeric columns marshal as primitives" begin
        arr = MATFrost._ConvertToMATLAB.convert_matfrostarray(
            DataFrame(count = Int64[1, 2, 3]),
        )

        column = arr.values[4].values[1]
        @test column isa MATFrostArrayPrimitive{Int64}
        @test column.dims == Int64[3]
        @test column.values == Int64[1, 2, 3]
    end

    @testset "nested in a struct" begin
        arr = MATFrost._ConvertToMATLAB.convert_matfrostarray(
            (payload = Geometry.points_dataframe(),),
        )

        nested = arr.values[1]
        @test nested isa MATFrostArrayStruct
        @test nested.values[1].values == ["matfrost_table"]
    end

    @testset "hook does not disturb plain structs" begin
        arr = MATFrost._ConvertToMATLAB.convert_matfrostarray(
            PlainStruct("Amsterdam", 3),
        )

        @test arr isa MATFrostArrayStruct
        @test arr.fieldnames == Symbol[:label, :count]
        @test arr.values[1].values == ["Amsterdam"]
    end
end
