module ConstantsTest

using Test
using JET

using MATFrost._Constants
using MATFrost._Types


@testset "Constants-Values-Uniqueness" begin

    @testset "All-Constants-Are-Unique" begin
        constants = [
            LOGICAL, CHAR, MATLAB_STRING,
            DOUBLE, SINGLE,
            INT8, UINT8, INT16, UINT16, INT32, UINT32, INT64, UINT64,
            COMPLEX_DOUBLE, COMPLEX_SINGLE,
            COMPLEX_INT8, COMPLEX_UINT8, COMPLEX_INT16, COMPLEX_UINT16,
            COMPLEX_INT32, COMPLEX_UINT32, COMPLEX_INT64, COMPLEX_UINT64,
            CELL, STRUCT,
            OBJECT, VALUE_OBJECT, HANDLE_OBJECT_REF, ENUM,
            SPARSE_LOGICAL, SPARSE_DOUBLE, SPARSE_COMPLEX_DOUBLE
        ]

        # Check all constants are unique
        @test length(constants) == length(unique(constants))
    end

    @testset "Constants-Are-Int32" begin
        @test LOGICAL isa Int32
        @test DOUBLE isa Int32
        @test MATLAB_STRING isa Int32
        @test CELL isa Int32
        @test STRUCT isa Int32
    end

    @testset "Constants-Sequential-Values" begin
        @test LOGICAL == Int32(0)
        @test CHAR == Int32(1)
        @test MATLAB_STRING == Int32(2)
        @test DOUBLE == Int32(3)
        @test SINGLE == Int32(4)
        @test INT8 == Int32(5)
        @test UINT8 == Int32(6)
        @test CELL == Int32(23)
        @test STRUCT == Int32(24)
    end
end


@testset "MatlabType-Julia-Primitives" begin

    @testset "MatlabType-Bool" begin
        @test matlab_type(Bool) == LOGICAL
    end

    @testset "MatlabType-String" begin
        @test matlab_type(String) == MATLAB_STRING
    end

    @testset "MatlabType-Float32" begin
        @test matlab_type(Float32) == SINGLE
    end

    @testset "MatlabType-Float64" begin
        @test matlab_type(Float64) == DOUBLE
    end

    @testset "MatlabType-Int8" begin
        @test matlab_type(Int8) == INT8
    end

    @testset "MatlabType-UInt8" begin
        @test matlab_type(UInt8) == UINT8
    end

    @testset "MatlabType-Int16" begin
        @test matlab_type(Int16) == INT16
    end

    @testset "MatlabType-UInt16" begin
        @test matlab_type(UInt16) == UINT16
    end

    @testset "MatlabType-Int32" begin
        @test matlab_type(Int32) == INT32
    end

    @testset "MatlabType-UInt32" begin
        @test matlab_type(UInt32) == UINT32
    end

    @testset "MatlabType-Int64" begin
        @test matlab_type(Int64) == INT64
    end

    @testset "MatlabType-UInt64" begin
        @test matlab_type(UInt64) == UINT64
    end

    @testset "MatlabType-Complex-Float32" begin
        @test matlab_type(Complex{Float32}) == COMPLEX_SINGLE
    end

    @testset "MatlabType-Complex-Float64" begin
        @test matlab_type(Complex{Float64}) == COMPLEX_DOUBLE
    end

    @testset "MatlabType-Complex-Int8" begin
        @test matlab_type(Complex{Int8}) == COMPLEX_INT8
    end

    @testset "MatlabType-Complex-UInt8" begin
        @test matlab_type(Complex{UInt8}) == COMPLEX_UINT8
    end

    @testset "MatlabType-Complex-Int16" begin
        @test matlab_type(Complex{Int16}) == COMPLEX_INT16
    end

    @testset "MatlabType-Complex-UInt16" begin
        @test matlab_type(Complex{UInt16}) == COMPLEX_UINT16
    end

    @testset "MatlabType-Complex-Int32" begin
        @test matlab_type(Complex{Int32}) == COMPLEX_INT32
    end

    @testset "MatlabType-Complex-UInt32" begin
        @test matlab_type(Complex{UInt32}) == COMPLEX_UINT32
    end

    @testset "MatlabType-Complex-Int64" begin
        @test matlab_type(Complex{Int64}) == COMPLEX_INT64
    end

    @testset "MatlabType-Complex-UInt64" begin
        @test matlab_type(Complex{UInt64}) == COMPLEX_UINT64
    end
end


@testset "MatlabType-Julia-Arrays" begin

    @testset "MatlabType-Array-Float64" begin
        @test matlab_type(Array{Float64, 1}) == DOUBLE
        @test matlab_type(Array{Float64, 2}) == DOUBLE
        @test matlab_type(Array{Float64, 3}) == DOUBLE
    end

    @testset "MatlabType-Array-Int32" begin
        @test matlab_type(Array{Int32, 1}) == INT32
        @test matlab_type(Array{Int32, 2}) == INT32
    end

    @testset "MatlabType-Array-Bool" begin
        @test matlab_type(Array{Bool, 1}) == LOGICAL
        @test matlab_type(Array{Bool, 2}) == LOGICAL
    end

    @testset "MatlabType-Array-String" begin
        @test matlab_type(Array{String, 1}) == MATLAB_STRING
        @test matlab_type(Array{String, 2}) == MATLAB_STRING
    end

    @testset "MatlabType-Array-Complex" begin
        @test matlab_type(Array{Complex{Float64}, 1}) == COMPLEX_DOUBLE
        @test matlab_type(Array{Complex{Float32}, 1}) == COMPLEX_SINGLE
        @test matlab_type(Array{Complex{Int32}, 2}) == COMPLEX_INT32
    end
end


@testset "MatlabType-Julia-Composites" begin

    @testset "MatlabType-Tuple" begin
        @test matlab_type(Tuple{Float64, Int32}) == CELL
        @test matlab_type(Tuple{Float64}) == CELL
        @test matlab_type(Tuple{}) == CELL
    end

    @testset "MatlabType-Array-Of-Arrays" begin
        @test matlab_type(Array{Array{Float64, 1}, 1}) == CELL
        @test matlab_type(Array{Array{Int32, 1}, 2}) == CELL
    end

    @testset "MatlabType-Array-Of-Tuples" begin
        @test matlab_type(Array{Tuple{Float64, Int32}, 1}) == CELL
    end

    @testset "MatlabType-Struct" begin
        struct TestStruct
            x::Float64
            y::Int32
        end
        @test matlab_type(TestStruct) == STRUCT
    end
end


@testset "MatlabType-MATFrostArrayAbstract" begin

    @testset "MatlabType-MATFrostArrayEmpty" begin
        marr = MATFrostArrayEmpty()
        @test matlab_type(marr) == DOUBLE
    end

    @testset "MatlabType-MATFrostArrayStruct" begin
        field = MATFrostArrayPrimitive{Float64}([1], [42.0])
        marr = MATFrostArrayStruct([1], [:x], [field])
        @test matlab_type(marr) == STRUCT
    end

    @testset "MatlabType-MATFrostArrayCell" begin
        inner = MATFrostArrayPrimitive{Float64}([1], [1.0])
        marr = MATFrostArrayCell([1], [inner])
        @test matlab_type(marr) == CELL
    end

    @testset "MatlabType-MATFrostArrayString" begin
        marr = MATFrostArrayString([1], ["hello"])
        @test matlab_type(marr) == MATLAB_STRING
    end

    @testset "MatlabType-MATFrostArrayPrimitive-Bool" begin
        marr = MATFrostArrayPrimitive{Bool}([1], [true])
        @test matlab_type(marr) == LOGICAL
    end

    @testset "MatlabType-MATFrostArrayPrimitive-Float64" begin
        marr = MATFrostArrayPrimitive{Float64}([1], [42.0])
        @test matlab_type(marr) == DOUBLE
    end

    @testset "MatlabType-MATFrostArrayPrimitive-Float32" begin
        marr = MATFrostArrayPrimitive{Float32}([1], [Float32(42.0)])
        @test matlab_type(marr) == SINGLE
    end

    @testset "MatlabType-MATFrostArrayPrimitive-Int32" begin
        marr = MATFrostArrayPrimitive{Int32}([1], Int32[42])
        @test matlab_type(marr) == INT32
    end

    @testset "MatlabType-MATFrostArrayPrimitive-Complex-Float64" begin
        marr = MATFrostArrayPrimitive{Complex{Float64}}([1], [Complex{Float64}(1.0, 2.0)])
        @test matlab_type(marr) == COMPLEX_DOUBLE
    end
end


@testset "MatlabType-NoSpecialize" begin

    @testset "NoSpecialize-Empty" begin
        marr = MATFrostArrayEmpty()
        @test matlab_type_nospecialize(marr) == DOUBLE
    end

    @testset "NoSpecialize-Struct" begin
        field = MATFrostArrayPrimitive{Float64}([1], [42.0])
        marr = MATFrostArrayStruct([1], [:x], [field])
        @test matlab_type_nospecialize(marr) == STRUCT
    end

    @testset "NoSpecialize-Cell" begin
        inner = MATFrostArrayPrimitive{Float64}([1], [1.0])
        marr = MATFrostArrayCell([1], [inner])
        @test matlab_type_nospecialize(marr) == CELL
    end

    @testset "NoSpecialize-String" begin
        marr = MATFrostArrayString([1], ["hello"])
        @test matlab_type_nospecialize(marr) == MATLAB_STRING
    end

    @testset "NoSpecialize-Bool" begin
        marr = MATFrostArrayPrimitive{Bool}([1], [true])
        @test matlab_type_nospecialize(marr) == LOGICAL
    end

    @testset "NoSpecialize-Float64" begin
        marr = MATFrostArrayPrimitive{Float64}([1], [42.0])
        @test matlab_type_nospecialize(marr) == DOUBLE
    end

    @testset "NoSpecialize-Float32" begin
        marr = MATFrostArrayPrimitive{Float32}([1], [Float32(42.0)])
        @test matlab_type_nospecialize(marr) == SINGLE
    end

    @testset "NoSpecialize-Int8" begin
        marr = MATFrostArrayPrimitive{Int8}([1], Int8[42])
        @test matlab_type_nospecialize(marr) == INT8
    end

    @testset "NoSpecialize-Complex-Float64" begin
        marr = MATFrostArrayPrimitive{Complex{Float64}}([1], [Complex{Float64}(1.0, 2.0)])
        @test matlab_type_nospecialize(marr) == COMPLEX_DOUBLE
    end

    @testset "NoSpecialize-All-Primitives" begin
        types_and_constants = [
            (Bool, LOGICAL),
            (Float64, DOUBLE),
            (Float32, SINGLE),
            (Int8, INT8),
            (UInt8, UINT8),
            (Int16, INT16),
            (UInt16, UINT16),
            (Int32, INT32),
            (UInt32, UINT32),
            (Int64, INT64),
            (UInt64, UINT64),
            (Complex{Float64}, COMPLEX_DOUBLE),
            (Complex{Float32}, COMPLEX_SINGLE),
            (Complex{Int8}, COMPLEX_INT8),
            (Complex{UInt8}, COMPLEX_UINT8),
            (Complex{Int16}, COMPLEX_INT16),
            (Complex{UInt16}, COMPLEX_UINT16),
            (Complex{Int32}, COMPLEX_INT32),
            (Complex{UInt32}, COMPLEX_UINT32),
            (Complex{Int64}, COMPLEX_INT64),
            (Complex{UInt64}, COMPLEX_UINT64),
        ]

        for (T, expected_const) in types_and_constants
            marr = MATFrostArrayPrimitive{T}([1], T[zero(T)])
            @test matlab_type_nospecialize(marr) == expected_const
        end
    end
end


@testset "MatlabTypeName" begin

    @testset "TypeName-Logical" begin
        @test matlab_type_name(LOGICAL) == "logical"
    end

    @testset "TypeName-Char" begin
        @test matlab_type_name(CHAR) == "char"
    end

    @testset "TypeName-String" begin
        @test matlab_type_name(MATLAB_STRING) == "string"
    end

    @testset "TypeName-Double" begin
        @test matlab_type_name(DOUBLE) == "double"
    end

    @testset "TypeName-Single" begin
        @test matlab_type_name(SINGLE) == "single"
    end

    @testset "TypeName-Int8" begin
        @test matlab_type_name(INT8) == "int8"
    end

    @testset "TypeName-UInt8" begin
        @test matlab_type_name(UINT8) == "uint8"
    end

    @testset "TypeName-Int16" begin
        @test matlab_type_name(INT16) == "int16"
    end

    @testset "TypeName-UInt16" begin
        @test matlab_type_name(UINT16) == "uint16"
    end

    @testset "TypeName-Int32" begin
        @test matlab_type_name(INT32) == "int32"
    end

    @testset "TypeName-UInt32" begin
        @test matlab_type_name(UINT32) == "uint32"
    end

    @testset "TypeName-Int64" begin
        @test matlab_type_name(INT64) == "int64"
    end

    @testset "TypeName-UInt64" begin
        @test matlab_type_name(UINT64) == "uint64"
    end

    @testset "TypeName-Complex-Single" begin
        @test matlab_type_name(COMPLEX_SINGLE) == "complex single"
    end

    @testset "TypeName-Complex-Double" begin
        @test matlab_type_name(COMPLEX_DOUBLE) == "complex double"
    end

    @testset "TypeName-Complex-Int8" begin
        @test matlab_type_name(COMPLEX_INT8) == "complex int8"
    end

    @testset "TypeName-Complex-UInt8" begin
        @test matlab_type_name(COMPLEX_UINT8) == "complex uint8"
    end

    @testset "TypeName-Cell" begin
        @test matlab_type_name(CELL) == "cell"
    end

    @testset "TypeName-Struct" begin
        @test matlab_type_name(STRUCT) == "struct"
    end

    @testset "TypeName-Object" begin
        @test matlab_type_name(OBJECT) == "object"
    end

    @testset "TypeName-Unknown" begin
        @test matlab_type_name(Int32(-1)) == "unknown"
        @test matlab_type_name(Int32(999)) == "unknown"
    end
end


@testset "SizeofMatlabPrimitive" begin

    @testset "Sizeof-Logical" begin
        @test sizeof_matlab_primitive(LOGICAL) == 1
    end

    @testset "Sizeof-Double" begin
        @test sizeof_matlab_primitive(DOUBLE) == 8
    end

    @testset "Sizeof-Single" begin
        @test sizeof_matlab_primitive(SINGLE) == 4
    end

    @testset "Sizeof-Int8" begin
        @test sizeof_matlab_primitive(INT8) == 1
    end

    @testset "Sizeof-UInt8" begin
        @test sizeof_matlab_primitive(UINT8) == 1
    end

    @testset "Sizeof-Int16" begin
        @test sizeof_matlab_primitive(INT16) == 2
    end

    @testset "Sizeof-UInt16" begin
        @test sizeof_matlab_primitive(UINT16) == 2
    end

    @testset "Sizeof-Int32" begin
        @test sizeof_matlab_primitive(INT32) == 4
    end

    @testset "Sizeof-UInt32" begin
        @test sizeof_matlab_primitive(UINT32) == 4
    end

    @testset "Sizeof-Int64" begin
        @test sizeof_matlab_primitive(INT64) == 8
    end

    @testset "Sizeof-UInt64" begin
        @test sizeof_matlab_primitive(UINT64) == 8
    end

    @testset "Sizeof-Complex-Double" begin
        @test sizeof_matlab_primitive(COMPLEX_DOUBLE) == 16
    end

    @testset "Sizeof-Complex-Single" begin
        @test sizeof_matlab_primitive(COMPLEX_SINGLE) == 8
    end

    @testset "Sizeof-Complex-Int8" begin
        @test sizeof_matlab_primitive(COMPLEX_INT8) == 2
    end

    @testset "Sizeof-Complex-UInt8" begin
        @test sizeof_matlab_primitive(COMPLEX_UINT8) == 2
    end

    @testset "Sizeof-Complex-Int16" begin
        @test sizeof_matlab_primitive(COMPLEX_INT16) == 4
    end

    @testset "Sizeof-Complex-UInt16" begin
        @test sizeof_matlab_primitive(COMPLEX_UINT16) == 4
    end

    @testset "Sizeof-Complex-Int32" begin
        @test sizeof_matlab_primitive(COMPLEX_INT32) == 8
    end

    @testset "Sizeof-Complex-UInt32" begin
        @test sizeof_matlab_primitive(COMPLEX_UINT32) == 8
    end

    @testset "Sizeof-Complex-Int64" begin
        @test sizeof_matlab_primitive(COMPLEX_INT64) == 16
    end

    @testset "Sizeof-Complex-UInt64" begin
        @test sizeof_matlab_primitive(COMPLEX_UINT64) == 16
    end

    @testset "Sizeof-NonPrimitive" begin
        @test sizeof_matlab_primitive(CELL) == 0
        @test sizeof_matlab_primitive(STRUCT) == 0
        @test sizeof_matlab_primitive(Int32(-1)) == 0
    end
end


@testset "Type-Mapping-Bidirectional-Consistency" begin

    @testset "Consistency-Primitives" begin
        types = [
            Bool, Float32, Float64,
            Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64,
            Complex{Float32}, Complex{Float64},
            Complex{Int8}, Complex{UInt8}, Complex{Int16}, Complex{UInt16},
            Complex{Int32}, Complex{UInt32}, Complex{Int64}, Complex{UInt64}
        ]

        for T in types
            type_code = matlab_type(T)
            type_name = matlab_type_name(type_code)

            # Verify type_code is unique and valid
            @test type_code != Int32(-1)
            @test type_name != "unknown"
        end
    end

    @testset "Consistency-Composites" begin
        # String
        @test matlab_type_name(matlab_type(String)) == "string"

        # Cell
        @test matlab_type_name(matlab_type(Tuple{Float64})) == "cell"

        # Struct (generic)
        struct TestStruct2
            x::Float64
        end
        @test matlab_type_name(matlab_type(TestStruct2)) == "struct"
    end
end

end
