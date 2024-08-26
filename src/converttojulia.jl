module _ConvertToJulia

using ..MATFrost: _MATFrostArray as MATFrostArray
using ..MATFrost: _MATFrostException as MATFrostException

function new_array(::Type{T}, dims::Ptr{Csize_t}, nel::Csize_t) where {T}
    T(undef, ntuple(i -> ifelse(i <= nel, unsafe_load(dims, i), Csize_t(1)), ndims(T)))
end


const new_array_c = @cfunction(new_array, Any, (Any, Ptr{Csize_t}, Csize_t))

function new_primitive_array(T, dims::Ptr{Csize_t}, ndims::Csize_t, data::Ptr{Cvoid})
    a = new_array(T, dims, ndims)
    unsafe_copyto!(pointer(a), reinterpret(Ptr{eltype(T)}, data), length(a))
    a
end


const LOGICAL = Int32(0)

const CHAR = Int32(1)

const MATLAB_STRING = Int32(2)

const DOUBLE = Int32(3)
const SINGLE = Int32(4)

const INT8 = Int32(5)
const UINT8 = Int32(6)
const INT16 = Int32(7)
const UINT16 = Int32(8)
const INT32 = Int32(9)
const UINT32 = Int32(10)
const INT64 = Int32(11)
const UINT64 = Int32(12)

const COMPLEX_DOUBLE = Int32(13)
const COMPLEX_SINGLE = Int32(14)

const COMPLEX_INT8 = Int32(15)
const COMPLEX_UINT8 = Int32(16)
const COMPLEX_INT16 = Int32(17)
const COMPLEX_UINT16 = Int32(18)
const COMPLEX_INT32 = Int32(19)
const COMPLEX_UINT32 = Int32(20)
const COMPLEX_INT64 = Int32(21)
const COMPLEX_UINT64 = Int32(22)

const CELL = Int32(23)
const STRUCT = Int32(24)

const OBJECT = Int32(25)
const VALUE_OBJECT = Int32(26)
const HANDLE_OBJECT_REF = Int32(27)
const ENUM = Int32(28)
const SPARSE_LOGICAL = Int32(29)
const SPARSE_DOUBLE = Int32(30)
const SPARSE_COMPLEX_DOUBLE = Int32(31)



abstract type MATLABType end

struct MATLABLogical <: MATLABType end
struct MATLABString  <: MATLABType end
struct MATLABDouble  <: MATLABType end
struct MATLABSingle  <: MATLABType end

struct MATFrostArrayTyped{T <: MATLABType}
    mfa::MATFrostArray
end


type_compatible(::Type{Bool}, mfa::MATFrostArray) = mfa.type == LOGICAL
type_compatible(::Type{String}, mfa::MATFrostArray) = mfa.type == MATLAB_STRING
type_compatible(::Type{T}, mfa::MATFrostArray) where {T<:Array{String}} = mfa.type == MATLAB_STRING

type_compatible(::Type{T}, mfa::MATFrostArray) where {T<:Tuple} = mfa.type == CELL
type_compatible(::Type{T}, mfa::MATFrostArray) where {T<:Array{<:Union{Array, Tuple}}} = mfa.type == CELL

type_compatible(::Type{T}, mfa::MATFrostArray) where {T<:NamedTuple} = mfa.type == STRUCT
type_compatible(::Type{T}, mfa::MATFrostArray) where {T} = mfa.type == STRUCT
type_compatible(::Type{T}, mfa::MATFrostArray) where {T<:Array} = mfa.type == STRUCT

type_compatible(::Type{Array{T, N}}, mfa::MATFrostArray) where {T<:Number, N} = type_compatible(T, mfa)

type_compatible(::Type{Float64}, mfa::MATFrostArray) = mfa.type == DOUBLE
type_compatible(::Type{Float32}, mfa::MATFrostArray) = mfa.type == SINGLE

type_compatible(::Type{Int8}, mfa::MATFrostArray)   = mfa.type == INT8
type_compatible(::Type{UInt8}, mfa::MATFrostArray)  = mfa.type == UINT8
type_compatible(::Type{Int16}, mfa::MATFrostArray)  = mfa.type == INT16
type_compatible(::Type{UInt16}, mfa::MATFrostArray) = mfa.type == UINT16
type_compatible(::Type{Int32}, mfa::MATFrostArray)  = mfa.type == INT32
type_compatible(::Type{UInt32}, mfa::MATFrostArray) = mfa.type == UINT32
type_compatible(::Type{Int64}, mfa::MATFrostArray)  = mfa.type == INT64
type_compatible(::Type{UInt64}, mfa::MATFrostArray) = mfa.type == UINT64

type_compatible(::Type{Complex{Float64}}, mfa::MATFrostArray) = mfa.type == COMPLEX_DOUBLE
type_compatible(::Type{Complex{Float32}}, mfa::MATFrostArray) = mfa.type == COMPLEX_SINGLE

type_compatible(::Type{Complex{Int8}}, mfa::MATFrostArray)   = mfa.type == COMPLEX_INT8
type_compatible(::Type{Complex{UInt8}}, mfa::MATFrostArray)  = mfa.type == COMPLEX_UINT8
type_compatible(::Type{Complex{Int16}}, mfa::MATFrostArray)  = mfa.type == COMPLEX_INT16
type_compatible(::Type{Complex{UInt16}}, mfa::MATFrostArray) = mfa.type == COMPLEX_UINT16
type_compatible(::Type{Complex{Int32}}, mfa::MATFrostArray)  = mfa.type == COMPLEX_INT32
type_compatible(::Type{Complex{UInt32}}, mfa::MATFrostArray) = mfa.type == COMPLEX_UINT32
type_compatible(::Type{Complex{Int64}}, mfa::MATFrostArray)  = mfa.type == COMPLEX_INT64
type_compatible(::Type{Complex{UInt64}}, mfa::MATFrostArray) = mfa.type == COMPLEX_UINT64


function array_type_name(mfa::MATFrostArray)
    if mfa.type == LOGICAL
        "logical"

    elseif mfa.type == CHAR
        "char"
    elseif mfa.type == MATLAB_STRING
        "string"

    elseif mfa.type == SINGLE
        "single"
    elseif mfa.type == DOUBLE
        "double"

    elseif mfa.type == INT8
        "int8"
    elseif mfa.type == UINT8
        "uint8"
    elseif mfa.type == INT16
        "int16"
    elseif mfa.type == UINT16
        "uint16"
    elseif mfa.type == INT32
        "int32"
    elseif mfa.type == UINT32
        "uint32"
    elseif mfa.type == INT64
        "int64"
    elseif mfa.type == UINT64
        "uint64"

    elseif mfa.type == COMPLEX_SINGLE
        "complex single"
    elseif mfa.type == COMPLEX_DOUBLE
        "complex double"

    elseif mfa.type == COMPLEX_INT8
        "complex int8"
    elseif mfa.type == COMPLEX_UINT8
        "complex uint8"
    elseif mfa.type == COMPLEX_INT16
        "complex int16"
    elseif mfa.type == COMPLEX_UINT16
        "complex uint16"
    elseif mfa.type == COMPLEX_INT32
        "complex int32"
    elseif mfa.type == COMPLEX_UINT32
        "complex uint32"
    elseif mfa.type == COMPLEX_INT64
        "complex int64"
    elseif mfa.type == COMPLEX_UINT64
        "complex uint64"

    elseif mfa.type == CELL
        "cell"
    elseif mfa.type == STRUCT
        "struct"
        
    elseif mfa.type == OBJECT
        "object"
    elseif mfa.type == VALUE_OBJECT
        "value object"
    elseif mfa.type == HANDLE_OBJECT_REF
        "handle object ref"
    elseif mfa.type == SPARSE_LOGICAL
        "sparse logical"
    elseif mfa.type == SPARSE_DOUBLE
        "sparse double"
    elseif mfa.type == SPARSE_COMPLEX_DOUBLE
        "sparse complex double"
    else
        "unknown"
    end
end
expected_matlab_type(::Type{T}) where {T} = "struct"

expected_matlab_type(::Type{T}) where {T<:Tuple} = "cell"
expected_matlab_type(::Type{T}) where {T<:Array{<:Union{Array,Tuple}}} = "cell"

expected_matlab_type(::Type{String}) = "string"

expected_matlab_type(::Type{Float32}) = "single"
expected_matlab_type(::Type{Float64}) = "double"

expected_matlab_type(::Type{UInt8})   = "uint8"
expected_matlab_type(::Type{Int8})    = "int8"
expected_matlab_type(::Type{UInt16})   = "uint16"
expected_matlab_type(::Type{Int16})    = "int16"
expected_matlab_type(::Type{UInt32})   = "uint32"
expected_matlab_type(::Type{Int32})    = "int32"
expected_matlab_type(::Type{UInt64})   = "uint64"
expected_matlab_type(::Type{Int64})    = "int64"

expected_matlab_type(::Type{Complex{Float32}}) = "complex single"
expected_matlab_type(::Type{Complex{Float64}}) = "complex double"

expected_matlab_type(::Type{Complex{UInt8}})   = "complex uint8"
expected_matlab_type(::Type{Complex{Int8}})    = "complex int8"
expected_matlab_type(::Type{Complex{UInt16}})   = "complex uint16"
expected_matlab_type(::Type{Complex{Int16}})    = "complex int16"
expected_matlab_type(::Type{Complex{UInt32}})   = "complex uint32"
expected_matlab_type(::Type{Complex{Int32}})    = "complex int32"
expected_matlab_type(::Type{Complex{UInt64}})   = "complex uint64"
expected_matlab_type(::Type{Complex{Int64}})    = "complex int64"

function incompatible_datatypes_exception(::Type{T}, mfa::MATFrostArray) where {T}
    MATFrostException(
        "matfrostjulia:conversion:incompatibleDatatypes",
        "Converting to: " * string(T) * "\n\nNo conversion defined:\n    Actual MATLAB type:   " * array_type_name(mfa) * "[]\n    Expected MATLAB type: " * expected_matlab_type(T) * "[]")
end

function is_empty_array(mfa::MATFrostArray)
    if mfa.ndims == 0
        return true
    end
    any(unsafe_load(mfa.dims, i) == 0 for i in 1:mfa.ndims)
end

function empty_array(::Type{T}) where {T<:Array}
    T(undef, ntuple(_-> 0, Val(ndims(T))))
end

function is_scalar_value(mfa::MATFrostArray)
    if mfa.ndims == 0
        return false
    end
    for i in 1:mfa.ndims
        if unsafe_load(mfa.dims, i) != 1
            return false
        end
    end
    return true
end

function not_scalar_value_exception(::Type{T}, mfa::MATFrostArray) where {T}
    actual_shape = join((string(unsafe_load(mfa.dims, i)) for i in 1:mfa.ndims), ", ")

    MATFrostException(
        "matfrostjulia:conversion:notScalarValue",
"""
Converting to: $(T) 

Not scalar value:
    Actual array dimensions:   ($actual_shape) 
    Expected array dimensions: (1, 1)
""")
end

function array_dimensions_compatible(::Type{T}, mfa::MATFrostArray) where {T}
    for i in (ndims(T)+1):mfa.ndims
        if unsafe_load(mfa.dims, i) != 1
            return false
        end
    end
    return true
end

function incompatible_array_dimensions_exception(::Type{T}, mfa::MATFrostArray) where {T}
    actual_shape = join((string(unsafe_load(mfa.dims, i)) for i in 1:mfa.ndims), ", ")
    
    actual_numdims = maximum(ifelse(unsafe_load(mfa.dims, i) != 1, i, 0) for i in 1:mfa.ndims)

    expected_array_dimensions = ifelse(ndims(T) == 1,
        "1 (column-vector); dimensions=(:, 1)", 
        "$(ndims(T)); dimensions=($( join((":" for _ in 1:ndims(T)), ", ") ))")

    MATFrostException(
        "matfrostjulia:conversion:incompatibleArrayDimensions",
"""
Converting to: $(string(T)) 

Array dimensions incompatible:
    Actual array dimensions:   numdims=$(string(actual_numdims)); dimensions=($(actual_shape))
    Expected array dimensions: numdims=$(expected_array_dimensions)
""")
end



function convert_to_julia(::Type{T}, mfa::MATFrostArray) where {T<:Number}
    if !is_scalar_value(mfa)
        throw(not_scalar_value_exception(T, mfa))
    end
    if !type_compatible(T, mfa)
        throw(incompatible_datatypes_exception(T, mfa))
    end
    unsafe_load(reinterpret(Ptr{T}, mfa.data))
end

function convert_to_julia(::Type{T}, mfa::MATFrostArray) where {T<:Array{<:Number}}
    if is_empty_array(mfa)
        return empty_array(T)
    end
    if !array_dimensions_compatible(T, mfa)
        throw(incompatible_array_dimensions_exception(T, mfa))
    end
    if !type_compatible(T, mfa)
        throw(incompatible_datatypes_exception(T, mfa))
    end
    ptr = reinterpret(Ptr{eltype(T)}, mfa.data)
    arr = new_array(T, mfa.dims, mfa.ndims)
    unsafe_copyto!(pointer(arr), ptr, length(arr))
    arr  
end




function convert_to_julia(::Type{String}, mfa::MATFrostArray)
    if !is_scalar_value(mfa)
        throw(not_scalar_value_exception(String, mfa))
    end
    if !type_compatible(String, mfa)
        throw(incompatible_datatypes_exception(String, mfa))
    end
    unsafe_string(unsafe_load(reinterpret(Ptr{Cstring}, mfa.data)))
end

function convert_to_julia(::Type{T}, mfa::MATFrostArray) where {T <: Array{String}} 
    if is_empty_array(mfa)
        return empty_array(T)
    end
    if !array_dimensions_compatible(T, mfa)
        throw(incompatible_array_dimensions_exception(T, mfa))
    end
    if !type_compatible(T, mfa)
        throw(incompatible_datatypes_exception(T, mfa))
    end
    arr = new_array(T, mfa.dims, mfa.ndims)
    ptr = reinterpret(Ptr{Cstring}, mfa.data)
    for i in eachindex(arr)
        arr[i] = unsafe_string(unsafe_load(ptr, i))
    end
    arr
end

function convert_to_julia(::Type{T}, mfa::MATFrostArray) where {T<:Array{<:Union{Array, Tuple}}}
    if is_empty_array(mfa)
        return empty_array(T)
    end
    if !array_dimensions_compatible(T, mfa)
        throw(incompatible_array_dimensions_exception(T, mfa))
    end
    if !type_compatible(T, mfa)
        throw(incompatible_datatypes_exception(T, mfa))
    end
    ptr = reinterpret(Ptr{Ptr{MATFrostArray}}, mfa.data)
    arr = new_array(T, mfa.dims, mfa.ndims)
    for i in eachindex(arr)
        arr[i] = convert_to_julia(eltype(T), unsafe_load(unsafe_load(ptr, i)))
    end
    arr
end

function convert_to_julia(::Type{T}, mfafields::NTuple{N, MATFrostArray}) where {T, N}
    T(convert_to_julia.(fieldtypes(T), mfafields)...)
end

function convert_to_julia(::Type{T}, mfafields::NTuple{N, MATFrostArray}) where {T<:NamedTuple, N}
    T(convert_to_julia.(fieldtypes(T), mfafields))
end



function missing_fields_exception(::Type{T}, fieldnames_mat::Vector{Symbol}) where {T}
    missingfields  = join(("    " * string(missingfield)  for missingfield in  fieldnames(T) if !(missingfield in fieldnames_mat)), "\n")
    actualfields   = join(("    " * string(fieldnamemat)  for fieldnamemat in fieldnames_mat), "\n")
    expectedfields = join(("    " * string(fieldnamejl) * "::" * fieldtype for (fieldnamejl, fieldtype)  in zip(fieldnames(T), string.(fieldtypes(T)))), "\n")

    MATFrostException(
        "matfrostjulia:conversion:missingFields",
"""
Converting to: $(string(T))

Input MATLAB struct value is missing fields.
    
Missing fields: 
$(missingfields)

Actual fields:
$(actualfields)

Expected fields:
$(expectedfields)
"""
    )
end        
        
function additional_fields_exception(::Type{T}, fieldnames_mat::Vector{Symbol}) where {T}
    additionalfields  = join(("    " * string(additionalfield)  for additionalfield in fieldnames_mat if !(additionalfield in fieldnames(T) )), "\n")
    actualfields   = join(("    " * string(fieldnamemat)  for fieldnamemat in fieldnames_mat), "\n")
    expectedfields = join(("    " * string(fieldnamejl) * "::" * fieldtype for (fieldnamejl, fieldtype)  in zip(fieldnames(T), string.(fieldtypes(T)))), "\n")

    MATFrostException(
        "matfrostjulia:conversion:additionalFields",
"""
Converting to: $(string(T))

Input MATLAB struct value has additional fields.
    
Additional fields: 
$(additionalfields)

Actual fields:
$(actualfields)

Expected fields:
$(expectedfields)
"""
    )
end        
   

#if !(missingfield in fieldnames(T))


function convert_to_julia(::Type{T}, mfa::MATFrostArray) where {T}
    if !is_scalar_value(mfa)
        throw(not_scalar_value_exception(T, mfa))
    end
    if !type_compatible(T, mfa)
        throw(incompatible_datatypes_exception(T, mfa))
    end

    fieldnames_mat = [Symbol(unsafe_string(unsafe_load(mfa.fieldnames, i))) for i in 1:mfa.nfields]
    
    if !all((fieldname_jl in fieldnames_mat) for fieldname_jl in fieldnames(T))
        throw(missing_fields_exception(T, fieldnames_mat))
    end

    if !all((fieldnamemat in fieldnames(T)) for fieldnamemat in fieldnames_mat)
        throw(additional_fields_exception(T, fieldnames_mat))
    end

    order = (fnjl -> Int64(findfirst(fnmat -> fnmat == fnjl, fieldnames_mat))).(fieldnames(T))
    
    mfadata = reinterpret(Ptr{Ptr{MATFrostArray}}, mfa.data)
    
    mfafields = (or -> unsafe_load(unsafe_load(mfadata, or))).(order)

    convert_to_julia(T, mfafields)
end

function convert_to_julia(::Type{T}, mfa::MATFrostArray) where {T<:Array}
    if is_empty_array(mfa)
        return empty_array(T)
    end
    if !array_dimensions_compatible(T, mfa)
        throw(incompatible_array_dimensions_exception(T, mfa))
    end
    if !type_compatible(T, mfa)
        throw(incompatible_datatypes_exception(T, mfa))
    end
    
    fieldnames_mat = [Symbol(unsafe_string(unsafe_load(mfa.fieldnames, i))) for i in 1:mfa.nfields]

    if !all((fieldname_jl in fieldnames_mat) for fieldname_jl in fieldnames(eltype(T)))
        throw(missing_fields_exception(eltype(T), fieldnames_mat))
    end

    if !all((fieldnamemat in fieldnames(eltype(T))) for fieldnamemat in fieldnames_mat)
        throw(additional_fields_exception(eltype(T), fieldnames_mat))
    end
    
    arr = new_array(T, mfa.dims, mfa.ndims) 
    

    order = (fnjl -> Int64(findfirst(fnmat -> fnmat == fnjl, fieldnames_mat))).(fieldnames(eltype(T)))
    mfadata = reinterpret(Ptr{Ptr{MATFrostArray}}, mfa.data)
    
    for j in eachindex(arr)  
        mfafields = (or -> unsafe_load(unsafe_load(mfadata, (j-1)*mfa.nfields + or))).(order)
        arr[j] = convert_to_julia(eltype(T), mfafields)
    end
    arr
end

function incompatible_tuple_shape(::Type{T}, mfa::MATFrostArray) where {T <: Tuple}
    actual_shape = join((string(unsafe_load(mfa.dims, i)) for i in 1:mfa.ndims), ", ")
    
    actual_numdims = maximum(ifelse(unsafe_load(mfa.dims, i) != 1, i, 0) for i in 1:mfa.ndims; init=0)

    MATFrostException(
        "matfrostjulia:conversion:incompatibleArrayDimensions",
"""
Converting to: $(string(T)) 

Array dimensions incompatible:
    Actual array dimensions:   numdims=$(string(actual_numdims)); dimensions=($(actual_shape))
    Expected array dimensions: numdims=1 (column-vector); ($(length(fieldnames(T))), 1)
""")
end

function convert_to_julia(::Type{T}, mfa::MATFrostArray) where {T <: Tuple}
    if !type_compatible(T, mfa)
        throw(incompatible_datatypes_exception(T, mfa))
    end
    if !(ifelse(mfa.ndims >= 1, unsafe_load(mfa.dims,1) == length(fieldnames(T)), false) && all(unsafe_load(mfa.dims, i) == 1 for i in 2:mfa.ndims))
        throw(incompatible_tuple_shape(T, mfa))
    end
    mfadata = reinterpret(Ptr{Ptr{MATFrostArray}}, mfa.data)
    convert_to_julia.(
        fieldtypes(T), 
        ntuple(i-> unsafe_load(unsafe_load(mfadata, i)), Val(length(fieldnames(T))))
    )
end

struct MATFrostOutput
    value::Any
    exception::Bool
end

function convert_to_julia_main(::Type{T}, mfa::MATFrostArray) where {T}
    try
        return MATFrostOutput(convert_to_julia(T, mfa), false)
    catch e
        if isa(e, MATFrostException)
            return MATFrostOutput(e, true)
        else
            return MATFrostOutput(MATFrostException("MATFrost crashed", sprint(showerror, e, catch_backtrace())), true)
        end
    end

end


const convert_to_julia_c() = @cfunction(convert_to_julia_main, Any, (Any, MATFrostArray))




end