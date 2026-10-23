module MATFrost

using Artifacts
using TOML
using Sockets

function matfrostserve end

"""
    convert_to_matlab(value)

Map `value` onto a MATLAB-representable surrogate before it is marshalled.
Return `value` unchanged to use the default struct conversion.
"""
convert_to_matlab(value) = value



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
export convert_to_matlab
export resolve_handle
export release_handle
export release_all_handles!

end
