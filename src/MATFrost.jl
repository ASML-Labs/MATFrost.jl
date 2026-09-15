module MATFrost

using Artifacts
using TOML
using Sockets

function matfrostserve end



include("types.jl")
include("constants.jl")


include("read.jl")
include("converttojulia.jl")
include("converttomatlab.jl")
include("conversion.jl")
include("write.jl")
include("server.jl")
include("example.jl")
include("install.jl")


export convert_from_matlab, convert_to_matlab
end
