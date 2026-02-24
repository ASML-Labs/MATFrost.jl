

module _Stream

function read! end
function write! end
function flush! end

const AF_UNIX = Cint(1)
const SOCK_STREAM = Cint(1)
const SOMAXCONN = Cint(0x7fffffff)

const FD_TYPE = UInt64
const INVALID_SOCKET = UInt64(0)

const SOCKADDR_UN = @NamedTuple{sun_family::UInt16, sun_path::NTuple{256,UInt8}}

function memcpy_mat(pdest::Ptr{UInt8}, psrc::Ptr{UInt8}, nb::Integer)
    @ccall memcpy(pdest::Ptr{UInt8}, psrc::Ptr{UInt8}, nb::Csize_t)::Cvoid
end

function uds_socket()
    fd = @ccall "Ws2_32.dll".socket(
        AF_UNIX::Cint, 
        SOCK_STREAM::Cint, 
        Int32(0)::Cint)::FD_TYPE

    if fd != INVALID_SOCKET
        return fd
    end

    throw("Cannot start socket")
end

function uds_init()
    wsadata=Ref{NTuple{408, UInt8}}()

    rc = @ccall "Ws2_32.dll".WSAStartup(
        UInt16(0x0202)::UInt16, 
        wsadata::Ref{NTuple{408, UInt8}})::Cint

    if rc != 0 
        throw("WSAStartup failed: $(rc)");
    end

end

function uds_bind(socket_fd::FD_TYPE, path::String)

    pathu8 = transcode(UInt8, path)

    sun_path = ntuple(Val{256}()) do i
        if i <= length(pathu8)
            pathu8[i]
        else
            UInt8(0)
        end 
    end
    
    socket_addr = SOCKADDR_UN((UInt16(AF_UNIX), sun_path))

    socket_addr_ref = Ref{SOCKADDR_UN}(socket_addr)
    rc = @ccall "Ws2_32.dll".bind(
        socket_fd::FD_TYPE, 
        socket_addr_ref::Ref{SOCKADDR_UN}, 
        Cint(sizeof(SOCKADDR_UN))::Cint)::Cint

    if rc != 0
        throw("Cannot bind to socket $(path)")
    end
end

function uds_connect(socket_fd::FD_TYPE, path::String)
    pathu8 = transcode(UInt8, path)

    sun_path = ntuple(Val{256}()) do i
        if i <= length(pathu8)
            pathu8[i]
        else
            UInt8(0)
        end 
    end
    
    socket_addr = SOCKADDR_UN((UInt16(AF_UNIX), sun_path))
    socket_addr_ref = Ref{SOCKADDR_UN}(socket_addr)

    @ccall "Ws2_32.dll".connect(
        socket_fd::FD_TYPE, 
        socket_addr_ref::Ref{SOCKADDR_UN}, 
        Cint(sizeof(SOCKADDR_UN))::Cint)::Cint
end

function uds_listen(socket_fd::FD_TYPE)
    rc = @ccall "Ws2_32.dll".listen(
        socket_fd::FD_TYPE, 
        SOMAXCONN::Cint)::Cint

    if rc != 0
        throw("Cannot listen to socket")
    end
end

function uds_accept(socket_fd::FD_TYPE)
    client_fd = @ccall "Ws2_32.dll".accept(
        socket_fd::FD_TYPE,
        C_NULL::Ptr{Cvoid},
        C_NULL::Ptr{Cvoid})::FD_TYPE

    if client_fd != INVALID_SOCKET
        return client_fd
    end

    throw("Error at accepting client socket")
end

function uds_read(socket_fd::FD_TYPE, data::Ptr{UInt8}, nb::Int64)
    rc = @ccall "Ws2_32.dll".recv(
        socket_fd::FD_TYPE, 
        data::Ptr{UInt8}, 
        Cint(nb)::Cint,
        Cint(0)::Cint)::Cint
    if rc > 0
        return rc
    else
        error("Server killed")
    end
end

function uds_write(socket_fd::FD_TYPE, data::Ptr{UInt8}, nb::Int64)
    sent = @ccall "Ws2_32.dll".send(
        socket_fd::FD_TYPE, 
        data::Ptr{UInt8}, 
        Cint(nb)::Cint,
        Cint(0)::Cint)::Cint

    if sent > 0
        return sent
    else
        error("Server killed")
    end
end

function uds_close(socket_fd::FD_TYPE)
    @ccall "Ws2_32.dll".closesocket(
        socket_fd::FD_TYPE)::Cint
end


mutable struct Buffer
    data::Vector{UInt8}
    position::Int64
    available::Int64
end

struct BufferedUDS
    socket_fd::FD_TYPE
    input::Buffer
    output::Buffer
end

@noinline function flush!(socket::BufferedUDS)  
    out = socket.output
    while (out.available > out.position) 
        bw = uds_write(socket.socket_fd, pointer(out.data) + out.position, out.available - out.position)
        out.position += bw
    end
    out.position = 0
    out.available = 0
    nothing
end

@noinline function write!(socket::BufferedUDS, data::Ptr{UInt8}, nb::Int64)
    out = socket.output
    bw = min(length(out.data) - out.available, nb);
    memcpy_mat(pointer(out.data) + out.available, data, bw);
    out.available += bw

    if (bw >= nb) 
        return
    end

    flush!(socket)

    while (nb - bw >= length(out.data)) 
        bwn = uds_write(
            socket.socket_fd, 
            data + bw, 
            length(out.data))
        bw += bwn
    end

    if (bw < nb) 
        out.position  = 0
        out.available = nb - bw
        memcpy_mat(pointer(out.data), data+bw, out.available);
    end
    nothing
end

@noinline function write!(socket::BufferedUDS, v::T) where {T<:Number}
    out = socket.output

    if (length(out.data) - out.available < sizeof(T))
        flush!(socket)
    end

    unsafe_store!(reinterpret(Ptr{T}, pointer(out.data) + out.available), v)
    out.available += sizeof(T)

    nothing
end

@noinline function write!(socket::BufferedUDS, arr::Array{T}) where {T<:Number}
    write!(socket, reinterpret(Ptr{UInt8}, pointer(arr)), sizeof(T)*length(arr))
    nothing
end

@noinline function write!(socket::BufferedUDS, v::String)
    nb = ncodeunits(v)
    write!(socket, Int64(nb))
    write!(socket, pointer(v), nb)
    nothing
end

@noinline function read!(socket::BufferedUDS, data::Ptr{UInt8}, nb::Int64)
    in = socket.input
    br = 0
    while (br < nb)
        if (in.available - in.position > 0) 
            brn = min(in.available - in.position, nb - br)
            memcpy_mat(data + br, pointer(in.data) + in.position, brn)
            in.position += brn
            br += brn
        elseif (nb - br >= length(in.data))
            brn = uds_read(socket.socket_fd, data + br, length(in.data))
            br += brn
        else
            brn = uds_read(socket.socket_fd, pointer(in.data), length(in.data))
            in.position = 0
            in.available = brn
         end
    end
    nothing
end

@noinline function read!(socket::BufferedUDS, arr::Array{T}) where {T <: Number}
    read!(socket, reinterpret(Ptr{UInt8}, pointer(arr)), sizeof(T) * length(arr))
    arr
end

@noinline function read!(socket::BufferedUDS, ::Type{T}) :: T where {T <: Number}
    in = socket.input
    if in.available - in.position >= sizeof(T)
        v = unsafe_load(reinterpret(Ptr{T}, pointer(in.data) + in.position))
        in.position += sizeof(T)
        return v
    else
        v = Ref{T}()
        read!(socket, reinterpret(Ptr{UInt8}, pointer_from_objref(v)), sizeof(T))
        return v[]
    end
end

@noinline function read!(socket::BufferedUDS, ::Type{String}) :: String
    nb = read!(socket, Int64)
    sarr = Vector{UInt8}(undef, nb)
    read!(socket, sarr)
    transcode(String, sarr)
end

const CLEAR_BUFFER = Vector{UInt8}(undef, 2<<15)

@noinline function discard!(socket::BufferedUDS, nb::Int64)
    br = 0
    p = pointer(CLEAR_BUFFER)
    while (br < nb)
        nr = min(length(CLEAR_BUFFER), nb-br)
        read!(socket, p, nr)
        br += nr
    end
    nothing
end




end