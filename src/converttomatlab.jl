
module _ConvertToMATLAB

using .._Types
using .._Constants

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


@generated function convert_matfrostarray(structval::T) where {T}
    quote
        
        values=MATFrostArrayAbstract[$((
            :(convert_matfrostarray(structval.$fn)) for fn in fieldnames(T)
        )...)]
        MATFrostArrayStruct(Int64[1], Symbol[fieldnames(T)...], values)

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
    quote
        
        values = MATFrostArrayAbstract[
            convert_matfrostarray(el) for el in tup
        ]

        MATFrostArrayCell(Int64[length(tup)], values)

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