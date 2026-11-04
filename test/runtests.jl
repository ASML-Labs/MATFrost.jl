using MATFrost
using Test


include("read.jl")
# include("composites.jl")
include("server.jl")
include("converttomatlab.jl")
if VERSION >= v"1.12"
    include("static_inference.jl")
end

include("simulate_communication.jl")

include("handles.jl")
include("package_configuration.jl")
include("extensions.jl")
# include("primitives.jl")
# include("incompatible_datatypes.jl")




