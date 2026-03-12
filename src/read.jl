module _Read

using .._Types
using .._Constants



struct MATFrostArrayHeader
    type :: Int32
    dims :: Vector{Int64}
    nel  :: Int64
end

function read_vector(io::IO, values::Vector{T}) where {T}
    unsafe_read(io, reinterpret(Ptr{UInt8}, pointer(values)), sizeof(T) * length(values))
    values
end

function read_string!(io::IO) :: String
    nb = read(io, Int64)
    sarr = Vector{UInt8}(undef, nb)
    read_vector(io, sarr)
    transcode(String, sarr)
end

function read_matfrostarray_header!(io::IO) :: MATFrostArrayHeader
    type = read(io, Int32)
    ndims = read(io, Int64)
    dims = Int64[read(io, Int64) for _ in 1:ndims]
    nel  = prod(dims; init=1)
    MATFrostArrayHeader(type, dims, nel)
end

@noinline function read_matfrostarray_primitive!(io::IO, header::MATFrostArrayHeader, ::Type{T}) :: MATFrostArrayPrimitive{T}  where {T<:Number}
    values = Vector{T}(undef, header.nel)
    read_vector(io, values)
    MATFrostArrayPrimitive{T}(header.dims, values)
end

@noinline function read_matfrostarray_string!(io::IO, header::MATFrostArrayHeader) :: MATFrostArrayString
    values = String[read_string!(io) for _ in 1:header.nel]
    MATFrostArrayString(header.dims, values)
end

@noinline function read_matfrostarray_struct!(io::IO, header::MATFrostArrayHeader)::MATFrostArrayStruct
    nfields = read(io, Int64)
    fns = Symbol[Symbol(read_string!(io)) for _ in 1:nfields]
    
    values = MATFrostArrayAbstract[
        read_matfrostarray!(io) for _ in 1:(nfields*header.nel)
    ]

    MATFrostArrayStruct(header.dims, fns, values)
end

@noinline function read_matfrostarray_cell!(io::IO, header::MATFrostArrayHeader)::MATFrostArrayCell
    values = MATFrostArrayAbstract[
        read_matfrostarray!(io) for _ in 1:header.nel
    ]
    MATFrostArrayCell(header.dims, values)
    
end

# Discard bytes from IO stream
const CLEAR_BUFFER = Vector{UInt8}(undef, 2<<15)

@noinline function discard!(io::IO, nb::Int64)
    br = 0
    p = pointer(CLEAR_BUFFER)
    while (br < nb)
        nr = min(length(CLEAR_BUFFER), nb-br)
        readbytes!(io, CLEAR_BUFFER, nr)
        br += nr
    end
    nothing
end

@noinline function read_matfrostarray!(io::IO) :: MATFrostArrayAbstract
    header = read_matfrostarray_header!(io)

    if header.nel == 0
        if header.type == STRUCT
            nfields = read(io, Int64)
            for _ in 1:nfields
                nb = read(io, Int64)
                discard!(io, nb)
            end
        end
        return MATFrostArrayEmpty()
    end


    if header.type == STRUCT
        read_matfrostarray_struct!(io, header)

    elseif header.type == CELL
        read_matfrostarray_cell!(io, header)

    elseif header.type == MATLAB_STRING
        read_matfrostarray_string!(io, header)
        
    elseif header.type == LOGICAL
        read_matfrostarray_primitive!(io, header, Bool)
    elseif header.type == DOUBLE
        read_matfrostarray_primitive!(io, header, Float64)
    elseif header.type == SINGLE
        read_matfrostarray_primitive!(io, header, Float32)

    elseif header.type == COMPLEX_DOUBLE
        read_matfrostarray_primitive!(io, header, Complex{Float64})
    elseif header.type == COMPLEX_SINGLE
        read_matfrostarray_primitive!(io, header, Complex{Float32})
    elseif header.type == INT8
        read_matfrostarray_primitive!(io, header, Int8)
    elseif header.type == UINT8
        read_matfrostarray_primitive!(io, header, UInt8)
    elseif header.type == INT16
        read_matfrostarray_primitive!(io, header, Int16)
    elseif header.type == UINT16
        read_matfrostarray_primitive!(io, header, UInt16)
    elseif header.type == INT32
        read_matfrostarray_primitive!(io, header, Int32)
    elseif header.type == UINT32
        read_matfrostarray_primitive!(io, header, UInt32)
    elseif header.type == INT64
        read_matfrostarray_primitive!(io, header, Int64)
    elseif header.type == UINT64
        read_matfrostarray_primitive!(io, header, UInt64)

    elseif header.type == COMPLEX_INT8
        read_matfrostarray_primitive!(io, header, Complex{Int8})
    elseif header.type == COMPLEX_UINT8
        read_matfrostarray_primitive!(io, header, Complex{UInt8})
    elseif header.type == COMPLEX_INT16
        read_matfrostarray_primitive!(io, header, Complex{Int16})
    elseif header.type == COMPLEX_UINT16
        read_matfrostarray_primitive!(io, header, Complex{UInt16})
    elseif header.type == COMPLEX_INT32
        read_matfrostarray_primitive!(io, header, Complex{Int32})
    elseif header.type == COMPLEX_UINT32
        read_matfrostarray_primitive!(io, header, Complex{UInt32})
    elseif header.type == COMPLEX_INT64
        read_matfrostarray_primitive!(io, header, Complex{Int64})
    elseif header.type == COMPLEX_UINT64
        read_matfrostarray_primitive!(io, header, Complex{UInt64})
    else
        error("Unrecoverable crash - MATFrost communication channel corrupted at read side")
    end

end



end