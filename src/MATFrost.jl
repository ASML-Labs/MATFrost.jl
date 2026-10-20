module MATFrost

using Artifacts
using TOML
using Sockets

function matfrostserve end



include("types.jl")
include("constants.jl")
include("handles.jl")


include("read.jl")
include("converttojulia.jl")
include("converttomatlab.jl")
include("write.jl")

include("server.jl")

include("example.jl")

include("install.jl")

export MATFrostHandle
export use_matfrost_handle
export release_handle
export release_all_handles!

end
