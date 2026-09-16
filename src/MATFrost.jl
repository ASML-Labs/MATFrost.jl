module MATFrost

using Artifacts
using TOML
using Sockets

function matfrostserve end
function convert_from_matlab end
function convert_to_matlab end
function convert_from_matlab_extension end
function convert_to_matlab_extension end

include("types.jl")
include("constants.jl")
include("read.jl")
include("converttojulia.jl")
include("converttomatlab.jl")
include("write.jl")
include("server.jl")
include("example.jl")
include("install.jl")

export convert_from_matlab,
    convert_to_matlab, convert_from_matlab_extension, convert_to_matlab_extension
end
