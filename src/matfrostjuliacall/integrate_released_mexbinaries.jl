MEX_VERSION = "0.4.0"

using ArtifactUtils
import Pkg

add_artifact!(
    joinpath(@__FILE__, "..", "..", "..", "Artifacts.toml"), 
    "matfrost-mex", 
    "https://github.com/ASML-Labs/MATFrost.jl/releases/download/matfrost-mex-v" * MEX_VERSION * "/matfrost-mex-v" * MEX_VERSION * "-win-x64.tar.gz", 
    force=true, 
    platform=Pkg.BinaryPlatforms.Windows(:x86_64))
