module _Constants


export matlab_type, matlab_type_name, matlab_type_nospecialize

export sizeof_matlab_primitive

export LOGICAL, CHAR, MATLAB_STRING,
    DOUBLE, SINGLE,
    INT8, UINT8, INT16, UINT16, INT32, UINT32, INT64, UINT64,
    COMPLEX_DOUBLE, COMPLEX_SINGLE,
    COMPLEX_INT8, COMPLEX_UINT8, COMPLEX_INT16, COMPLEX_UINT16,
    COMPLEX_INT32, COMPLEX_UINT32, COMPLEX_INT64, COMPLEX_UINT64,
    CELL, STRUCT, 
    OBJECT, VALUE_OBJECT, HANDLE_OBJECT_REF, ENUM, 
    SPARSE_LOGICAL, SPARSE_DOUBLE, SPARSE_COMPLEX_DOUBLE

using .._Types

const LOGICAL = Int32(0)  # 0x00

const CHAR = Int32(1)  # 0x01

const MATLAB_STRING = Int32(2)  # 0x02

const DOUBLE = Int32(3)  # 0x03
const SINGLE = Int32(4)  # 0x04

const INT8 = Int32(5)  # 0x05
const UINT8 = Int32(6)  # 0x06
const INT16 = Int32(7)  # 0x07
const UINT16 = Int32(8)  # 0x08
const INT32 = Int32(9)  # 0x09
const UINT32 = Int32(10)  # 0x0a
const INT64 = Int32(11)  # 0x0b
const UINT64 = Int32(12)  # 0x0c

const COMPLEX_DOUBLE = Int32(13)  # 0x0d
const COMPLEX_SINGLE = Int32(14)  # 0x0e

const COMPLEX_INT8 = Int32(15)  # 0x0f
const COMPLEX_UINT8 = Int32(16)  # 0x10
const COMPLEX_INT16 = Int32(17)  # 0x11
const COMPLEX_UINT16 = Int32(18)  # 0x12
const COMPLEX_INT32 = Int32(19)  # 0x13
const COMPLEX_UINT32 = Int32(20)  # 0x14
const COMPLEX_INT64 = Int32(21)  # 0x15
const COMPLEX_UINT64 = Int32(22)  # 0x16

const CELL = Int32(23)  # 0x17
const STRUCT = Int32(24)  # 0x18

const OBJECT = Int32(25)  # 0x19
const VALUE_OBJECT = Int32(26)  # 0x1a
const HANDLE_OBJECT_REF = Int32(27)  # 0x1b
const ENUM = Int32(28)  # 0x1c

const SPARSE_LOGICAL = Int32(29)  # 0x1d
const SPARSE_DOUBLE = Int32(30)  # 0x1e
const SPARSE_COMPLEX_DOUBLE = Int32(31)  # 0x1f



matlab_type(::Type{T}) where {T} = STRUCT

matlab_type(::Type{T}) where {T<:Tuple} = CELL
matlab_type(::Type{T}) where {T<:Array{<:Union{Array,Tuple}}} = CELL


matlab_type(::Type{Bool}) = LOGICAL

matlab_type(::Type{String}) = MATLAB_STRING

matlab_type(::Type{Float32}) = SINGLE
matlab_type(::Type{Float64}) = DOUBLE

matlab_type(::Type{UInt8})   = UINT8
matlab_type(::Type{Int8})    = INT8
matlab_type(::Type{UInt16})   = UINT16
matlab_type(::Type{Int16})    = INT16
matlab_type(::Type{UInt32})   = UINT32
matlab_type(::Type{Int32})    = INT32
matlab_type(::Type{UInt64})   = UINT64
matlab_type(::Type{Int64})    = INT64

matlab_type(::Type{Complex{Float32}}) = COMPLEX_SINGLE
matlab_type(::Type{Complex{Float64}}) = COMPLEX_DOUBLE

matlab_type(::Type{Complex{UInt8}})   = COMPLEX_UINT8
matlab_type(::Type{Complex{Int8}})    = COMPLEX_INT8
matlab_type(::Type{Complex{UInt16}})   = COMPLEX_UINT16
matlab_type(::Type{Complex{Int16}})    = COMPLEX_INT16
matlab_type(::Type{Complex{UInt32}})   = COMPLEX_UINT32
matlab_type(::Type{Complex{Int32}})    = COMPLEX_INT32
matlab_type(::Type{Complex{UInt64}})   = COMPLEX_UINT64
matlab_type(::Type{Complex{Int64}})    = COMPLEX_INT64

matlab_type(::Type{Array{T, N}}) where {T <: Union{Number, String}, N} = matlab_type(T)

matlab_type(::MATFrostArrayEmpty) = DOUBLE
matlab_type(::MATFrostArrayStruct) = STRUCT
matlab_type(::MATFrostArrayCell) = CELL
matlab_type(::MATFrostArrayString) = matlab_type(String)
matlab_type(::MATFrostArrayPrimitive{T}) where {T} = matlab_type(T)


@noinline function matlab_type_nospecialize(@nospecialize(marr::MATFrostArrayAbstract))::Int32
    if marr isa MATFrostArrayEmpty
        matlab_type(marr)
    
    elseif marr isa MATFrostArrayStruct
        matlab_type(marr)
    elseif marr isa MATFrostArrayString
        matlab_type(marr)
    elseif marr isa MATFrostArrayCell
        matlab_type(marr)

    elseif marr isa MATFrostArrayPrimitive{Bool}
        matlab_type(marr)

    elseif marr isa MATFrostArrayPrimitive{Float64}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Float32}
        matlab_type(marr)

        
    elseif marr isa MATFrostArrayPrimitive{Complex{Float64}}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{Float32}}
        matlab_type(marr)

    elseif marr isa MATFrostArrayPrimitive{Int8}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{UInt8}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Int16}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{UInt16}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Int32}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{UInt32}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Int64}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{UInt64}
        matlab_type(marr)

    elseif marr isa MATFrostArrayPrimitive{Complex{Int8}}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{UInt8}}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{Int16}}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{UInt16}}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{Int32}}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{UInt32}}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{Int64}}
        matlab_type(marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{UInt64}}
        matlab_type(marr)
    else
        Int32(-1)
    end
end


function matlab_type_name(type::Int32)
    if type == LOGICAL
        "logical"

    elseif type == CHAR
        "char"
    elseif type == MATLAB_STRING
        "string"

    elseif type == SINGLE
        "single"
    elseif type == DOUBLE
        "double"

    elseif type == INT8
        "int8"
    elseif type == UINT8
        "uint8"
    elseif type == INT16
        "int16"
    elseif type == UINT16
        "uint16"
    elseif type == INT32
        "int32"
    elseif type == UINT32
        "uint32"
    elseif type == INT64
        "int64"
    elseif type == UINT64
        "uint64"

    elseif type == COMPLEX_SINGLE
        "complex single"
    elseif type == COMPLEX_DOUBLE
        "complex double"

    elseif type == COMPLEX_INT8
        "complex int8"
    elseif type == COMPLEX_UINT8
        "complex uint8"
    elseif type == COMPLEX_INT16
        "complex int16"
    elseif type == COMPLEX_UINT16
        "complex uint16"
    elseif type == COMPLEX_INT32
        "complex int32"
    elseif type == COMPLEX_UINT32
        "complex uint32"
    elseif type == COMPLEX_INT64
        "complex int64"
    elseif type == COMPLEX_UINT64
        "complex uint64"

    elseif type == CELL
        "cell"
    elseif type == STRUCT
        "struct"
        
    elseif type == OBJECT
        "object"
    elseif type == VALUE_OBJECT
        "value object"
    elseif type == HANDLE_OBJECT_REF
        "handle object ref"
    elseif type == SPARSE_LOGICAL
        "sparse logical"
    elseif type == SPARSE_DOUBLE
        "sparse double"
    elseif type == SPARSE_COMPLEX_DOUBLE
        "sparse complex double"
    else
        "unknown"
    end
end


const PRIMITIVE_TYPES_AND_SIZE = (
    (LOGICAL, 1), 
    (DOUBLE, 8), (SINGLE, 4), 
    (INT8, 1), (UINT8, 1), (INT16, 2), (UINT16,2), (INT32,4), (UINT32,4), (INT64,8), (UINT64,8),
    (COMPLEX_DOUBLE, 16), (COMPLEX_SINGLE,8),
    (COMPLEX_INT8, 2), (COMPLEX_UINT8, 2), (COMPLEX_INT16, 4), (COMPLEX_UINT16,4), (COMPLEX_INT32,8), (COMPLEX_UINT32,8), (COMPLEX_INT64,16), (COMPLEX_UINT64,16),
)

function sizeof_matlab_primitive(type::Int32)
    if type == LOGICAL
        1
    elseif type == DOUBLE
        8
    elseif type == SINGLE
        4
    elseif type == INT8
        1
    elseif type == UINT8
        1
    elseif type == INT16
        2
    elseif type == UINT16
        2
    elseif type == INT32
        4
    elseif type == UINT32
        4
    elseif type == INT64
        8
    elseif type == UINT64
        8
    elseif type == COMPLEX_DOUBLE
        16
    elseif type == COMPLEX_SINGLE
        8
    elseif type == COMPLEX_INT8
        2
    elseif type == COMPLEX_UINT8
        2
    elseif type == COMPLEX_INT16
        4
    elseif type == COMPLEX_UINT16
        4
    elseif type == COMPLEX_INT32
        8
    elseif type == COMPLEX_UINT32
        8
    elseif type == COMPLEX_INT64
        16
    elseif type == COMPLEX_UINT64
        16
    else
        0
    end

end

end