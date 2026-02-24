module BufferPrimitives

export _writebuffer!, _writebuffermatfrostarray!, _readbuffer!, _clearbuffer!

using ..Types
using MATFrost._Stream: BufferedUDS, Buffer

if VERSION < v"1.10"
    function memcpy(pdest::Ptr, psrc::Ptr, nb::Integer)
        @ccall memcpy(pdest::Ptr{UInt8}, psrc::Ptr{UInt8}, nb::Csize_t)::Cvoid
    end
else
    import Base: memcpy
end

"""
This file contains inefficiently written code to map julia objects to matfrostarray. 
This scripts will write purely to buffer (and increase if unsufficient size)
"""
function _writebuffer!(io::Buffer, v::T) where T
    while length(io.data) - io.available < sizeof(T)
        resize!(io.data, 2*length(io.data))
    end

    p = reinterpret(Ptr{T}, pointer(io.data) + io.available)
    unsafe_store!(p, v)
    io.available += sizeof(T)
end

function _writebuffer!(io::Buffer, arr::Array{T,N}) where {T,N}
    nb = length(arr) * sizeof(T)

    while length(io.data) - io.available < nb
        resize!(io.data, 2*length(io.data))
    end

    psrc = reinterpret(Ptr{UInt8}, pointer(arr))
    pdest = pointer(io.data) + io.available
    memcpy(pdest, psrc, nb)
    io.available += nb
end



function _writebuffer!(io::Buffer, s::String)
    _writebuffer!(io, ncodeunits(s))

    while length(io.data) - io.available < ncodeunits(s)
        resize!(io.data, 2*length(io.data))
    end


    psrc = reinterpret(Ptr{UInt8}, pointer(s))
    pdest = pointer(io.data) + io.available

    memcpy(pdest, psrc, ncodeunits(s))

    io.available += ncodeunits(s)

end



"""
Primitive arrays
"""
function _writebuffermatfrostarray!(io::Buffer, arr::Array{T,N}) where {T <: Number,N}
    _writebuffer!(io, expected_matlab_type(Array{T,N}))
    _writebuffer!(io, Int64(N))
    dims = size(arr)
    for dim in dims
        _writebuffer!(io, dim)
    end
    _writebuffer!(io, arr)
end

"""
String arrays
"""
function _writebuffermatfrostarray!(io::Buffer, arr::Array{String,N}) where {N}
    _writebuffer!(io, expected_matlab_type(Array{String,N}))
    _writebuffer!(io, Int64(N))
    dims = size(arr)
    for dim in dims
        _writebuffer!(io, dim)
    end
    for s in arr
        _writebuffer!(io,s)
    end
end


"""
Struct arrays and Named tuple arrays
"""
function _writebuffermatfrostarray!(io::Buffer, arr::Array{T,N}) where {T,N}
    _writebuffer!(io, expected_matlab_type(Array{T,N}))
    _writebuffer!(io, Int64(N))
    dims = size(arr)
    for dim in dims
        _writebuffer!(io, dim)
    end
    _writebuffer!(io, Int64(fieldcount(T)))
    for fn in fieldnames(T)
        _writebuffer!(io, String(fn))
    end
    for i in eachindex(arr)
        el = arr[i]
        for fn in fieldnames(T)
            _writebuffermatfrostarray!(io, getfield(el, fn))
        end

    end
end



"""
Tuple
"""
function _writebuffermatfrostarray!(io::Buffer, tup::T) where {T <: Tuple}
    _writebuffer!(io, expected_matlab_type(T))
    _writebuffer!(io, 1)
    _writebuffer!(io, length(tup))

    for el in tup
        _writebuffermatfrostarray!(io, el)
    end
    
end


"""
Tuple arrays and Array of arrays
"""
function _writebuffermatfrostarray!(io::Buffer, arr::Array{T,N}) where {T <: Union{Array, Tuple}, N}
    _writebuffer!(io, expected_matlab_type(Array{T,N}))
    _writebuffer!(io, Int64(N))
    dims = size(arr)
    for dim in dims
        _writebuffer!(io, dim)
    end
    for i in eachindex(arr)
        el = arr[i]
        _writebuffermatfrostarray!(io, el)
    end
end



"""
Map scalar to array
"""
function _writebuffermatfrostarray!(io::Buffer, v::T) where {T}
    _writebuffermatfrostarray!(io, T[v])
end




function _readbuffer!(io::Buffer, ::Type{T}) where T
    p = reinterpret(Ptr{T}, pointer(io.data) + io.position)
    io.position += sizeof(T)
    unsafe_load(p)
end

function _clearbuffer!(io)
    io.position = 0
    io.available =0 
end

end