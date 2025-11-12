module ConversionExceptionsTest

using Test
using JET

using MATFrost
using MATFrost._ConvertToJulia: convert_matfrostarray, incompatible_datatypes_exception, not_scalar_value_exception, incompatible_array_dimensions_exception, incompatible_tuple_shape_exception, missing_fields_exception, unsupported_datatype_exception
using MATFrost._ConvertToMATLAB
using MATFrost._Types
using MATFrost._Constants


@testset "Exception-IncompatibleDatatypes" begin

    @testset "Exception-Number-To-String" begin
        marr = MATFrostArrayPrimitive{Float64}([1], [42.0])

        try
            convert_matfrostarray(String, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleDatatypes"
            @test occursin("String", e.message)
            @test occursin("double", e.message)
            @test occursin("string", e.message)
        end
    end

    @testset "Exception-String-To-Number" begin
        marr = MATFrostArrayString([1], ["hello"])

        try
            convert_matfrostarray(Float64, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleDatatypes"
            @test occursin("Float64", e.message)
            @test occursin("string", e.message)
            @test occursin("double", e.message)
        end
    end

    @testset "Exception-Cell-To-Primitive" begin
        inner = MATFrostArrayPrimitive{Float64}([1], [1.0])
        marr = MATFrostArrayCell([1], [inner])

        try
            convert_matfrostarray(Float64, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleDatatypes"
            @test occursin("Float64", e.message)
            @test occursin("cell", e.message)
        end
    end

    @testset "Exception-Struct-To-Primitive" begin
        field = MATFrostArrayPrimitive{Float64}([1], [42.0])
        marr = MATFrostArrayStruct([1], [:x], [field])

        try
            convert_matfrostarray(Float64, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleDatatypes"
            @test occursin("Float64", e.message)
            @test occursin("struct", e.message)
        end
    end
end


@testset "Exception-NotScalarValue" begin

    @testset "Exception-Array-To-Scalar" begin
        marr = MATFrostArrayPrimitive{Float64}([3], [1.0, 2.0, 3.0])

        try
            convert_matfrostarray(Float64, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:notScalarValue"
            @test occursin("Float64", e.message)
            @test occursin("Not scalar value", e.message)
            @test occursin("3", e.message)  # numel
        end
    end

    @testset "Exception-Matrix-To-Scalar" begin
        marr = MATFrostArrayPrimitive{Float64}([2, 3], collect(Float64(i) for i in 1:6))

        try
            convert_matfrostarray(Float64, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:notScalarValue"
            @test occursin("Float64", e.message)
            @test occursin("6", e.message)  # numel = 2*3
        end
    end

    @testset "Exception-Empty-To-Scalar-Struct" begin
        struct TestStruct1
            x::Float64
        end

        marr = MATFrostArrayEmpty()

        try
            convert_matfrostarray(TestStruct1, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:notScalarValue"
            @test occursin("TestStruct1", e.message)
            @test occursin("0", e.message)  # numel
        end
    end
end


@testset "Exception-IncompatibleArrayDimensions" begin

    @testset "Exception-Matrix-To-Vector" begin
        marr = MATFrostArrayPrimitive{Float64}([2, 3], collect(Float64(i) for i in 1:6))

        try
            convert_matfrostarray(Vector{Float64}, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleArrayDimensions"
            @test occursin("Vector{Float64}", e.message)
            @test occursin("Array dimensions incompatible", e.message)
        end
    end

    @testset "Exception-3D-To-Matrix" begin
        marr = MATFrostArrayPrimitive{Float64}([2, 3, 4], collect(Float64(i) for i in 1:24))

        try
            convert_matfrostarray(Matrix{Float64}, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleArrayDimensions"
            # Matrix{Float64} is the same as Array{Float64, 2} but with different syntax
            @test occursin("Matrix{Float64}", e.message)
        end
    end

    @testset "Exception-Non-0D-To-0D-Array" begin
        marr = MATFrostArrayPrimitive{Float64}([2], [1.0, 2.0])

        try
            convert_matfrostarray(Array{Float64, 0}, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleArrayDimensions"
            @test occursin("Array{Float64, 0}", e.message)
        end
    end
end


@testset "Exception-IncompatibleTupleShape" begin

    @testset "Exception-Wrong-Tuple-Length" begin
        inner1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        inner2 = MATFrostArrayPrimitive{Float64}([1], [2.0])
        inner3 = MATFrostArrayPrimitive{Float64}([1], [3.0])
        marr = MATFrostArrayCell([3], [inner1, inner2, inner3])

        try
            convert_matfrostarray(Tuple{Float64, Float64}, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleArrayDimensions"
            @test occursin("Tuple{Float64, Float64}", e.message)
            @test occursin("Expected array numel:      2", e.message)
        end
    end

    @testset "Exception-Tuple-Too-Short" begin
        inner1 = MATFrostArrayPrimitive{Float64}([1], [1.0])
        marr = MATFrostArrayCell([1], [inner1])

        try
            convert_matfrostarray(Tuple{Float64, Float64, Float64}, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleArrayDimensions"
            @test occursin("Tuple{Float64, Float64, Float64}", e.message)
            @test occursin("Expected array numel:      3", e.message)
        end
    end
end


@testset "Exception-MissingFields" begin

    @testset "Exception-Struct-Missing-One-Field" begin
        struct TestStruct2
            x::Float64
            y::Int32
        end

        # Struct only has 'x', missing 'y'
        field_x = MATFrostArrayPrimitive{Float64}([1], [42.0])
        marr = MATFrostArrayStruct([1], [:x], [field_x])

        try
            convert_matfrostarray(TestStruct2, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:missingFields"
            @test occursin("TestStruct2", e.message)
            @test occursin("Missing fields", e.message)
            @test occursin("y", e.message)
        end
    end

    @testset "Exception-Struct-Missing-Multiple-Fields" begin
        struct TestStruct3
            x::Float64
            y::Int32
            z::String
        end

        # Struct only has 'x', missing 'y' and 'z'
        field_x = MATFrostArrayPrimitive{Float64}([1], [42.0])
        marr = MATFrostArrayStruct([1], [:x], [field_x])

        try
            convert_matfrostarray(TestStruct3, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:missingFields"
            @test occursin("TestStruct3", e.message)
            @test occursin("y", e.message)
            @test occursin("z", e.message)
        end
    end

    @testset "Exception-NamedTuple-Missing-Field" begin
        field_x = MATFrostArrayPrimitive{Float64}([1], [42.0])
        marr = MATFrostArrayStruct([1], [:x], [field_x])

        try
            convert_matfrostarray(NamedTuple{(:x, :y), Tuple{Float64, Int32}}, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:missingFields"
            @test occursin("NamedTuple", e.message)
            @test occursin("y", e.message)
        end
    end
end


@testset "Exception-UnsupportedDatatype-ToJulia" begin

    @testset "Exception-Union-Type" begin
        marr = MATFrostArrayPrimitive{Float64}([1], [42.0])

        try
            # Union types are not supported
            convert_matfrostarray(Union{Float64, Nothing}, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:unsupportedDatatype"
            @test occursin("Union", e.message)
            @test occursin("not supported", e.message)
        end
    end

    @testset "Exception-Any-Type" begin
        marr = MATFrostArrayPrimitive{Float64}([1], [42.0])

        try
            convert_matfrostarray(Any, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:unsupportedDatatype"
            @test occursin("Any", e.message)
        end
    end
end


@testset "Exception-UnsupportedDatatype-ToMATLAB" begin

    @testset "Exception-BigInt" begin
        try
            MATFrost._ConvertToMATLAB.convert_matfrostarray(BigInt(123))
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:unsupportedDatatype"
            @test occursin("BigInt", e.message)
            @test occursin("not supported", e.message)
        end
    end

    @testset "Exception-BigFloat" begin
        try
            MATFrost._ConvertToMATLAB.convert_matfrostarray(BigFloat(123.456))
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:unsupportedDatatype"
            @test occursin("BigFloat", e.message)
        end
    end
end


@testset "Exception-Stacktrace" begin

    @testset "Exception-Nested-Struct-Field" begin
        struct InnerStruct
            value::String  # This will cause the error
        end
        struct OuterStruct
            x::Float64
            nested::InnerStruct
        end

        # Create struct with nested field that has wrong type
        inner_field = MATFrostArrayPrimitive{Float64}([1], [99.0])  # Should be String
        inner_struct = MATFrostArrayStruct([1], [:value], [inner_field])
        outer_field1 = MATFrostArrayPrimitive{Float64}([1], [42.0])
        marr = MATFrostArrayStruct([1], [:x, :nested], [outer_field1, inner_struct])

        try
            convert_matfrostarray(OuterStruct, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleDatatypes"
            # Check that stacktrace contains field names
            @test length(e.stacktrace) >= 1
            @test :value in e.stacktrace || :nested in e.stacktrace
        end
    end

    @testset "Exception-Array-Element-Error" begin
        struct TestStruct4
            value::String
        end

        # Create array where one element has wrong type
        field1 = MATFrostArrayString([1], ["correct"])
        field2 = MATFrostArrayPrimitive{Float64}([1], [99.0])  # Wrong type
        marr = MATFrostArrayStruct([2], [:value], [field1, field2])

        try
            convert_matfrostarray(Vector{TestStruct4}, marr)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostConversionException
            @test e.id == "matfrostjulia:conversion:incompatibleDatatypes"
            # Check that stacktrace contains element index
            @test length(e.stacktrace) >= 1
        end
    end
end


@testset "Exception-MessageFormat" begin

    @testset "Exception-Contains-Type-Information" begin
        marr = MATFrostArrayPrimitive{Float64}([1], [42.0])

        try
            convert_matfrostarray(String, marr)
            @test false
        catch e
            @test e isa MATFrostConversionException
            # Message should contain both actual and expected types
            @test occursin("Converting to:", e.message)
            @test occursin("String", e.message)
            @test occursin("Actual MATLAB type:", e.message)
            @test occursin("Expected MATLAB type:", e.message)
        end
    end

    @testset "Exception-Contains-Dimension-Information" begin
        marr = MATFrostArrayPrimitive{Float64}([2, 3], collect(Float64(i) for i in 1:6))

        try
            convert_matfrostarray(Float64, marr)
            @test false
        catch e
            @test e isa MATFrostConversionException
            # Message should contain dimension information
            @test occursin("Actual array numel:", e.message)
            @test occursin("6", e.message)
            @test occursin("Actual array dimensions:", e.message)
        end
    end

    @testset "Exception-Contains-Field-Information" begin
        struct TestStruct5
            x::Float64
            y::Int32
        end

        field_x = MATFrostArrayPrimitive{Float64}([1], [42.0])
        marr = MATFrostArrayStruct([1], [:x], [field_x])

        try
            convert_matfrostarray(TestStruct5, marr)
            @test false
        catch e
            @test e isa MATFrostConversionException
            # Message should contain field information
            @test occursin("Missing fields:", e.message)
            @test occursin("y", e.message)
            @test occursin("Actual fields:", e.message)
            @test occursin("Expected fields:", e.message)
        end
    end
end

end
