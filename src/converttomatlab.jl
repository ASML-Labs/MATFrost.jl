
module _ConvertToMATLAB

using UUIDs

using .._Types
using .._Constants

import ..MATFrost: MATFrostHandle, store_handle, use_matfrost_handle,
    HANDLE_MARKER_FIELD, HANDLE_MARKER_VALUE, HANDLE_ID_FIELD, HANDLE_TYPENAME_FIELD

supported_number_type(::Type{T}) where T = isprimitivetype(T)
supported_number_type(::Type{Complex{T}}) where T = isprimitivetype(T)

@noinline function convert_matfrostarray(v::T) where{T <: Number}    
    if !supported_number_type(T)
        throw(unsupported_datatype_exception(T))
    end
    MATFrostArrayPrimitive{T}(Int64[1], T[v])
end

@noinline function convert_matfrostarray(arr::Array{T}) where{T <: Number}
    if !supported_number_type(T)
        throw(unsupported_datatype_exception(T))
    end
    if length(arr) == 0
        return MATFrostArrayEmpty()
    end
    dims = Int64[size(arr)...]
    vals = reshape(arr, (length(arr),))
    MATFrostArrayPrimitive{T}(dims, vals)
end

@noinline function convert_matfrostarray(v::String) 
    MATFrostArrayString(Int64[1], String[v])
end

@noinline function convert_matfrostarray(arr::Array{String})
    if length(arr) == 0
        return MATFrostArrayEmpty()
    end
    dims = Int64[size(arr)...]
    vals = reshape(arr, (length(arr),))
    MATFrostArrayString(dims, vals)
end


@noinline function convert_matfrostarray(id::UUID)
    MATFrostArrayString(Int64[1], String[string(id)])
end

@noinline function convert_matfrostarray(handle::MATFrostHandle)
    MATFrostArrayStruct(
        Int64[1],
        Symbol[HANDLE_MARKER_FIELD, HANDLE_ID_FIELD, HANDLE_TYPENAME_FIELD],
        MATFrostArrayAbstract[
            convert_matfrostarray(HANDLE_MARKER_VALUE),
            convert_matfrostarray(handle.id),
            convert_matfrostarray(handle.typename),
        ],
    )
end

@noinline function convert_matfrostarray(structval::T) where {T}
    if use_matfrost_handle(T)
        return convert_matfrostarray(store_handle(structval))
    end

    surrogate = convert_to_matlab(structval)
    if !isa(surrogate, T)
        return convert_matfrostarray(surrogate)
    end

    return convert_struct_matfrostarray(structval)
end

@generated function convert_struct_matfrostarray(
    structval::T,
) where {T}
    quote
        values = MATFrostArrayAbstract[
            $((
                :(convert_matfrostarray(structval.$fn))
                for fn in fieldnames(T)
            )...)
        ]

        MATFrostArrayStruct(
            Int64[1],
            Symbol[fieldnames(T)...],
            values,
        )
    end
end

@generated function convert_matfrostarray(arr::Array{T,N}) where {T,N}
    if isstructtype(T) && isconcretetype(T)
        quote
            if length(arr) == 0
                return MATFrostArrayEmpty()
            end
            
            values = Vector{MATFrostArrayAbstract}(undef, length(arr)*fieldcount(T))
            i = 0
            for el in arr
                $((:(values[i+$j] = convert_matfrostarray(el.$(fieldname(T,j)))) for j in 1:fieldcount(T))...)
                i += $(fieldcount(T))
            end
            MATFrostArrayStruct(Int64[size(arr)...], Symbol[fieldnames(T)...], values)

        end
    else
        quote    
            if length(arr) == 0
                return MATFrostArrayEmpty()
            end
            values = Vector{MATFrostArrayAbstract}(undef, length(arr))
            for i in eachindex(arr)
                values[i] = convert_matfrostarray(arr[i])
            end
            MATFrostArrayCell(Int64[size(arr)...], values)
        end
    end
end

@generated function convert_matfrostarray(tup::Tuple)
    # Unrolled to avoid runtime dispatch on heterogeneous tuples.
    quote
        values = MATFrostArrayAbstract[
            $((:(convert_matfrostarray(tup[$i])) for i in 1:fieldcount(tup))...)
        ]

        MATFrostArrayCell(Int64[$(fieldcount(tup))], values)
    end

end

@generated function convert_matfrostarray(arr::Array{T,N}) where {T<:Union{Array, Tuple}, N}
    quote
        if length(arr) == 0
            return MATFrostArrayEmpty()
        end
        values = Vector{MATFrostArrayAbstract}(undef, length(arr))
        for i in eachindex(arr)
            values[i] = convert_matfrostarray(arr[i])
        end
        MATFrostArrayCell(Int64[size(arr)...], values)
    end
end

"""
Pre-generated typenames used in error messages. As `string` is not type-stable.
"""
@generated function _typename(::Type{T}) where T
    :($(string(T)))
end


@noinline function unsupported_datatype_exception(typename::String)
    MATFrostConversionException(
        "matfrostjulia:conversion:unsupportedDatatype",
"""
Input conversion error:

Converting to: $(typename) is not supported. Currently not supported are: Union, Any, Abstract or Memory.
""",
Any[]
    )
end 

@noinline function unsupported_datatype_exception(::Type{T}) where T
    typename = _typename(T)
    
    unsupported_datatype_exception(typename)
end



end