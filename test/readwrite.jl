module BufferPrimitives

export _writebuffer!, _writebuffermatfrostarray!, _readbuffer!, _clearbuffer!, _addbuffer!

using ..Types

"""
This file contains inefficiently written code to map julia objects to matfrostarray. 
This scripts will write purely to buffer (and increase if unsufficient size)
"""
function _writebuffer!(io::IOBuffer, v::T) where T
    Base.write(io, v)
end

function _writebuffer!(io::IOBuffer, arr::Array{T,N}) where {T,N}
    Base.write(io, arr)
end

function _writebuffer!(io::IOBuffer, s::String)
    _writebuffer!(io, Int64(ncodeunits(s)))
    Base.write(io, s)
end


"""
Primitive arrays
"""
function _writebuffermatfrostarray!(io::IOBuffer, arr::Array{T,N}) where {T <: Number,N}
    _writebuffer!(io, expected_matlab_type(Array{T,N}))
    _writebuffer!(io, Int64(N))
    dims = size(arr)
    for dim in dims
        _writebuffer!(io, Int64(dim))
    end
    _writebuffer!(io, arr)
end

"""
String arrays
"""
function _writebuffermatfrostarray!(io::IOBuffer, arr::Array{String,N}) where {N}
    _writebuffer!(io, expected_matlab_type(Array{String,N}))
    _writebuffer!(io, Int64(N))
    dims = size(arr)
    for dim in dims
        _writebuffer!(io, Int64(dim))
    end
    for s in arr
        _writebuffer!(io,s)
    end
end


"""
Struct arrays and Named tuple arrays
"""
function _writebuffermatfrostarray!(io::IOBuffer, arr::Array{T,N}) where {T,N}
    _writebuffer!(io, expected_matlab_type(Array{T,N}))
    _writebuffer!(io, Int64(N))
    dims = size(arr)
    for dim in dims
        _writebuffer!(io, Int64(dim))
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
function _writebuffermatfrostarray!(io::IOBuffer, tup::T) where {T <: Tuple}
    _writebuffer!(io, expected_matlab_type(T))
    _writebuffer!(io, Int64(1))
    _writebuffer!(io, Int64(length(tup)))

    for el in tup
        _writebuffermatfrostarray!(io, el)
    end
    
end


"""
Tuple arrays and Array of arrays
"""
function _writebuffermatfrostarray!(io::IOBuffer, arr::Array{T,N}) where {T <: Union{Array, Tuple}, N}
    _writebuffer!(io, expected_matlab_type(Array{T,N}))
    _writebuffer!(io, Int64(N))
    dims = size(arr)
    for dim in dims
        _writebuffer!(io, Int64(dim))
    end
    for i in eachindex(arr)
        el = arr[i]
        _writebuffermatfrostarray!(io, el)
    end
end



"""
Map scalar to array
"""
function _writebuffermatfrostarray!(io::IOBuffer, v::T) where {T}
    _writebuffermatfrostarray!(io, T[v])
end




function _readbuffer!(io::IOBuffer, ::Type{T}) where T
    Base.read(io, T)
end

# Transfer data from write buffer to read buffer for testing, adding padding
function _addbuffer!(io::IOBuffer, padding_bytes::Int=0)
    # Get current data
    seekstart(io)
    data = read(io)
    
    # Clear and rewrite with padding
    seekstart(io)
    truncate(io, 0)
    Base.write(io, data)
    
    # Add padding
    if padding_bytes > 0
        Base.write(io, zeros(UInt8, padding_bytes))
    end
    
    # Reset to start for reading
    seekstart(io)
end

function _clearbuffer!(io::IOBuffer)
    seekstart(io)
    truncate(io, 0)
end

end