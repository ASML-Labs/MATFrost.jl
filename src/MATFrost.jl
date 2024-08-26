module MATFrost
using Scratch

mexdir() = @get_scratch!("mexbin") 

matlabpath() = joinpath(pkgdir(MATFrost), "src", "matlab")

matlabpathexamples() = matlabpath() * ";" * joinpath(pkgdir(MATFrost), "examples", "01-MATFrostHelloWorld")

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

end
