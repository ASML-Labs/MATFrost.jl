module _ConvertToJulia

using .._Types
using .._Constants


supported_number_type(::Type{T}) where T = isprimitivetype(T)
supported_number_type(::Type{Complex{T}}) where T = isprimitivetype(T)


@noinline function convert_matfrostarray(::Type{T}, @nospecialize(marr::MATFrostArrayAbstract))::T where {T<:Number}
    if !supported_number_type(T)
        throw(unsupported_datatype_exception(T))
    end
    if marr isa MATFrostArrayPrimitive{T}
        validate_array_dimensions(T, marr)
        marr.values[1]
    elseif marr isa MATFrostArrayEmpty
        throw(not_scalar_value_exception(T, Int64[0]))
    else
        throw(incompatible_datatypes_exception(T, marr))
    end
end


@noinline function convert_matfrostarray(::Type{Array{T,N}}, @nospecialize(marr::MATFrostArrayAbstract))::Array{T,N} where {T<:Number, N}
    if !supported_number_type(T)
        throw(unsupported_datatype_exception(T))
    end
    if marr isa MATFrostArrayPrimitive{T}
        validate_array_dimensions(Array{T,N}, marr)
        if marr.values isa Array{T,N}
            return marr.values
        else
            dims = array_dims(marr.dims, Val{N}())
            return reshape(marr.values, dims)
        end
    elseif marr isa MATFrostArrayEmpty
        return empty_array(Array{T,N})
    else
        throw(incompatible_datatypes_exception(Array{T,N}, marr))
    end
end

"""
Convert to String
"""
@noinline function convert_matfrostarray(::Type{String}, @nospecialize(marr::MATFrostArrayAbstract))::String
    if marr isa MATFrostArrayString
        validate_array_dimensions(String, marr)
        marr.values[1]
    elseif marr isa MATFrostArrayEmpty
        throw(not_scalar_value_exception(String, Int64[0]))
    else
        throw(incompatible_datatypes_exception(String, marr))
    end
end

"""
Convert to Arrays of Strings
"""
@noinline function convert_matfrostarray(::Type{Array{String,N}}, @nospecialize(marr::MATFrostArrayAbstract))::Array{String,N} where {N}
    if marr isa MATFrostArrayString
        validate_array_dimensions(Array{String,N}, marr)
        if marr.values isa Array{String,N}
            return marr.values
        else
            dims = array_dims(marr.dims, Val{N}())
            return reshape(marr.values, dims)
        end
    elseif marr isa MATFrostArrayEmpty
        return empty_array(Array{String,N})
    else
        throw(incompatible_datatypes_exception(Array{String,N}, marr))
    end
end


"""
Convert to 0-size Tuples
"""
@noinline function convert_matfrostarray(::Type{Tuple{}}, @nospecialize(marr::MATFrostArrayAbstract))::Tuple{}
    if marr isa MATFrostArrayCell
        validate_array_dimensions(Tuple{}, marr)
        return ()
    elseif marr isa MATFrostArrayEmpty
        return ()
    else
        throw(incompatible_datatypes_exception(Tuple{}, marr))
    end

end

"""
Convert to Tuples
"""
@generated function convert_matfrostarray(::Type{T}, @nospecialize(marr::MATFrostArrayAbstract))::T where {T<:Tuple}
    quote
        if marr isa MATFrostArrayCell
            validate_array_dimensions(T, marr)

            T(($((
                quote
                    try
                        convert_matfrostarray($(fieldtype(T, fi)), marr.values[$fi])
                    catch e
                        if e isa MATFrostConversionException
                            push!(e.stacktrace, $fi)
                            rethrow(e)
                        else
                            rethrow(e)
                        end
                    end
                end for fi in 1:fieldcount(T)
            )...),))
        elseif marr isa MATFrostArrayEmpty
            throw(not_scalar_value_exception(T, Int64[0]))
        else
            throw(incompatible_datatypes_exception(T, marr))
        end

    end
end

"""
Convert to structs/namedtuples
"""
@generated function convert_matfrostarray(::Type{T}, @nospecialize(marr::MATFrostArrayAbstract))::T where T
    if isstructtype(T)
        quote
            if marr isa MATFrostArrayStruct
                validate_array_dimensions(T, marr)
                validate_fieldnames(T, marr)     
                convert_matfrostarray_struct_object(T, marr, 1)
            elseif marr isa MATFrostArrayEmpty
                throw(not_scalar_value_exception(T, Int64[0]))
            else
                throw(incompatible_datatypes_exception(T, marr))
            end

        end
    else
        quote
            throw(unsupported_datatype_exception(T))
        end
    end
end

empty_array(::Type{Array{T,N}}) where {T,N} = Array{T,N}(undef, ntuple(_-> 0, Val{N}()))

"""
Convert to arrays of structs/namedtuples
"""
@generated function convert_matfrostarray(::Type{Array{T,N}}, @nospecialize(marr::MATFrostArrayAbstract))::Array{T,N} where {T,N}
    if isstructtype(T)
        quote
            if marr isa MATFrostArrayStruct
                validate_array_dimensions(Array{T,N}, marr)
                validate_fieldnames(T, marr)     

                dims = array_dims(marr.dims, Val{N}())
                arr = Array{T,N}(undef, dims)
                for i in eachindex(arr)
                    try
                        arr[i] = convert_matfrostarray_struct_object(T, marr, i)
                    catch e
                        if e isa MATFrostConversionException
                            push!(e.stacktrace, i)
                            rethrow(e)
                        else
                            rethrow(e)
                        end
                    end
                end
                return arr
            elseif marr isa MATFrostArrayEmpty
                return empty_array(Array{T,N})
            else
                throw(incompatible_datatypes_exception(Array{T,N}, marr))
            end
        end
    else
        quote
            throw(unsupported_datatype_exception(T))
        end
    end
end


"""
Convert to arrays of arrays/tuples
"""
@generated function convert_matfrostarray(::Type{Array{T,N}}, @nospecialize(marr::MATFrostArrayAbstract))::Array{T,N} where {T<:Union{Array, Tuple},N}
    quote
        if marr isa MATFrostArrayCell
            validate_array_dimensions(Array{T,N}, marr)

            dims = array_dims(marr.dims, Val{N}())
            arr = Array{T,N}(undef, dims)
            for i in eachindex(arr)
                try
                    arr[i] = convert_matfrostarray(T, marr.values[i])
                catch e
                    if e isa MATFrostConversionException
                        push!(e.stacktrace, i)
                        rethrow(e)
                    else
                        rethrow(e)
                    end
                end
            end
            return arr
        elseif marr isa MATFrostArrayEmpty
            return empty_array(Array{T,N})
        else
            throw(incompatible_datatypes_exception(Array{T,N}, marr))
        end
    end
end


function array_dims(dims::Vector{Int64}, ::Val{N}) where N
    ntuple(Val{N}()) do i
        if i <= length(dims)
            dims[i]
        else
            1
        end
    end
end

# Special rules for vectors.
function array_dims(dims::Vector{Int64}, ::Val{1})
    if length(dims)==0
        (0,)
    else
        (prod(dims; init=1),)
    end
end




"""
Convert single struct object (Struct/NamedTuple)
"""
@generated function convert_matfrostarray_struct_object(::Type{T}, marr::MATFrostArrayStruct, i::Int64) where {T}

    conversions = (quote 
        try
            convert_matfrostarray($(fieldtype(T, fi)), get_matfrostarray_element(marr, fieldname(T, $fi), i))
        catch e
            if e isa MATFrostConversionException
                push!(e.stacktrace, fieldname(T, $fi))
                rethrow(e)
            else
                rethrow(e)
            end
        end
    end for fi in 1:fieldcount(T))

    
    if T <: NamedTuple
        quote
            T(($(conversions...),))
        end  
    else # Regular struct
        quote
            T($(conversions...),)
        end  
    end

end



function get_matfrostarray_element(marr::MATFrostArrayStruct, fn::Symbol, i::Int64)
    fns = marr.fieldnames
    for fni in eachindex(fns)
        if fns[fni] == fn
            return marr.values[fni + length(fns) * (i-1)]
        end
    end
    throw("Cannot find field")
end




"""
Tuple array dimension validation
"""
function validate_array_dimensions(::Type{T}, marr::MATFrostArrayAbstract) where {T<:Tuple}
    if length(marr.values) != fieldcount(T)
        throw(incompatible_tuple_shape_exception(T, marr.dims))
    end
    nothing
end

"""
Scalar array dimension validation
"""
function validate_array_dimensions(::Type{T}, marr::MATFrostArrayAbstract) where {T}
    nel = prod(marr.dims;init=1)
    if nel != 1
        throw(not_scalar_value_exception(T, marr.dims))
    end
    nothing
end

"""
Special validation for 0-dim arrays.
"""
function validate_array_dimensions(::Type{Array{T, 0}}, marr::MATFrostArrayAbstract) where {T} 
    if length(marr.dims) == 0
        return nothing
    end

    for dim in marr.dims
        if dim == 0
            return nothing
        end
    end
    throw(incompatible_array_dimensions_exception(Array{T, 0}, marr.dims))
end

"""
Special validation for vectors. Allow for row vectors, or 1x1xN vectors.
"""
function validate_array_dimensions(::Type{Vector{T}}, marr::MATFrostArrayAbstract) where {T}
    highdims = 0
    for dim in marr.dims
        if dim > 1
            highdims += 1
        end
    end
    if highdims > 1
        throw(incompatible_array_dimensions_exception(Vector{T}, marr.dims))
    end
    nothing
end

"""
Validation for arrays of Ndim>=2. 
"""
function validate_array_dimensions(::Type{Array{T,N}}, marr::MATFrostArrayAbstract) where {T,N}
    for i in (N+1):length(marr.dims)
        if marr.dims[i] > 1  
            throw(incompatible_array_dimensions_exception(Array{T, N}, marr.dims))
        end
    end
    nothing
end


function validate_fieldnames(::Type{T}, marr::MATFrostArrayStruct) where {T}
    for fn in fieldnames(T)
        if !(fn in marr.fieldnames)
            throw(missing_fields_exception(T, marr.fieldnames))
        end
    end
    nothing
end





"""
Pre-generated typenames used in error messages. As `string` is not type-stable.
"""
@generated function _typename(::Type{T}) where T
    :($(string(T)))
end

"""
Pre-generated typenames used in error messages. As `string` is not type-stable.
"""
@generated function _fieldtypenames(::Type{T}) where T
    :(String[$((:(_typename($(ft))) for ft in fieldtypes(T))...)])
end



@noinline function incompatible_datatypes_exception(::Type{T}, @nospecialize(marr::MATFrostArrayAbstract)) where {T}
    typename = _typename(T)
    matlab_type_expected = matlab_type(T)
    matlab_type_actual = matlab_type_nospecialize(marr)
    incompatible_datatypes_exception(typename, matlab_type_actual, matlab_type_expected)
end


@noinline function incompatible_datatypes_exception(typename::String, matlab_type_actual::Int32, matlab_type_expected::Int32)
    MATFrostConversionException(
        "matfrostjulia:conversion:incompatibleDatatypes",
"""
Input conversion error:

Converting to: $(typename) 

Incompatible datatypes conversion:
    Actual MATLAB type:   $(matlab_type_name(matlab_type_actual))[]
    Expected MATLAB type: $(matlab_type_name(matlab_type_expected))[]
""",
Any[]
)
end



@noinline function not_scalar_value_exception(::Type{T}, dims::Vector{Int64}) where T
    typename = _typename(T)
    not_scalar_value_exception(typename, dims)
end

@noinline function not_scalar_value_exception(typename::String, dims::Vector{Int64})
    # actual_shape = join((string(unsafe_load(mfa.dims, i)) for i in 1:mfa.ndims), ", ")
        dimsprint = ((string(dim) * ", ") for dim in dims)

    MATFrostConversionException(
        "matfrostjulia:conversion:notScalarValue",
"""
Input conversion error:

Converting to: $(typename) 

Not scalar value:
    Actual array numel:        $(prod(dims; init=1))
    Actual array dimensions:   ($(dimsprint...)) 
    Expected array dimensions: (1, 1)
""",
Any[]
)
end



@noinline function incompatible_array_dimensions_exception(::Type{Array{T,N}}, dims::Vector{Int64}) where {T,N}
    typename = _typename(Array{T,N})
    incompatible_array_dimensions_exception(typename, N, dims)
end


@noinline function incompatible_array_dimensions_exception(typename::String, expectednumdims::Int64, dims::Vector{Int64})
    dimsprint = ("$(dim), " for dim in dims)

    MATFrostConversionException(
        "matfrostjulia:conversion:incompatibleArrayDimensions",
"""
Input conversion error:

Converting to: $(typename) 

Array dimensions incompatible:
    Actual array numel:        $(prod(dims; init=1))
    Actual array dimensions:   numdims=$(length(dims)); dimensions=($(dimsprint...))
    Expected array dimensions: numdims=$(expectednumdims)
""",
Any[]
)
end


@noinline function incompatible_tuple_shape_exception(::Type{T}, dims::Vector{Int64}) where {T}
    typename = _typename(T)
    tuplelength = fieldcount(T)
    incompatible_tuple_shape_exception(typename, tuplelength, dims)
end
   
@noinline function incompatible_tuple_shape_exception(typename::String, tuplelength::Int64, dims::Vector{Int64})
    dimsprint = ("$(dim), " for dim in dims)

    MATFrostConversionException(
        "matfrostjulia:conversion:incompatibleArrayDimensions",
"""
Input conversion error:

Converting to: $(typename) 

Array dimensions incompatible:
    Actual array numel:        $(prod(dims; init=1))
    Actual array dimensions:   numdims=$(length(dims)); dimensions=($(dimsprint...))
    Expected array numel:      $(tuplelength)
    Expected array dimensions: numdims=1 (column-vector); dimensions=($(tuplelength), 1)
""",
Any[]
)
end


@noinline function missing_fields_exception(::Type{T}, fieldnames_mat::Vector{Symbol}) where T
    typename = _typename(T)
    fieldnames_jl = Symbol[fieldnames(T)...]
    fieldtypenames = _fieldtypenames(T)
    
    missing_fields_exception(typename, fieldnames_jl, fieldtypenames, fieldnames_mat)

end


@noinline function missing_fields_exception(typename::String, fieldnames_jl::Vector{Symbol}, fieldtypenames::Vector{String}, fieldnames_mat::Vector{Symbol})
    missingfields  = ("    $(fn)\n" for fn in fieldnames_jl if !(fn in fieldnames_mat))
    actualfields   = ("    $(fn)\n"  for fn in fieldnames_mat)
    expectedfields = ("    $(fn)::$(ftn)\n" for (fn, ftn)  in zip(fieldnames_jl, fieldtypenames))

  MATFrostConversionException(
        "matfrostjulia:conversion:missingFields",
"""
Input conversion error:

Converting to: $(typename)

Input MATLAB struct value is missing fields.
    
Missing fields: 
$(missingfields...)

Actual fields:
$(actualfields...)

Expected fields:
$(expectedfields...)
""",
Any[]
    )
end





@noinline function additional_fields_exception(typename::String, fieldnames::Vector{Symbol}, fieldtypenames::Vector{String}, fieldnames_mat::Vector{Symbol})
    additionalfields = ("    $(fn)\n"  for fn in fieldnames_mat if !(fn in fieldnames))
    actualfields =     ("    $(fn)\n"  for fn in fieldnames_mat)
    expectedfields =   ("    $(fn)::$(ftn)\n" for (fn, ftn)  in zip(fieldnames, fieldtypenames))

    MATFrostConversionException(
        "matfrostjulia:conversion:additionalFields",
"""
Input conversion error:

Converting to: $(typename)

Input MATLAB struct value has additional fields.

Additional fields: 
$(additionalfields...)

Actual fields:
$(actualfields...)

Expected fields:
$(expectedfields...)
""",
Any[]
    )
end 

@noinline function additional_fields_exception(::Type{T}, fieldnames_mat::Vector{Symbol}) where T
   typename = _typename(T)
    _fieldnames = Symbol[fieldnames(T)...]
    fieldtypenames = _fieldtypenames(T)
    
    additional_fields_exception(typename, _fieldnames, fieldtypenames, fieldnames_mat)

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