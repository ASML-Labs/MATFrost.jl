module MATFrost
using Artifacts
using TOML

struct _MATFrostArray
    type::Cint
    ndims::Csize_t
    dims::Ptr{Csize_t}
    data::Ptr{Cvoid}
    nfields::Csize_t
    fieldnames::Ptr{Cstring}
end

struct _MATFrostException <: Exception 
    id::String
    message::String
end

include("converttojulia.jl")
include("converttomatlab.jl")
include("juliacall.jl")
include("install.jl")

end
