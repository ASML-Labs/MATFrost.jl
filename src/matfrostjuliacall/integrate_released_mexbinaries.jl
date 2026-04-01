
import Pkg
using SHA

import Pkg

using MATFrost

MATFROST_VERSION = ARGS[1]
MEX_ZIP = ARGS[2]

artifact_id = Pkg.Artifacts.create_artifact() do fpath
    run(`tar -xzvf $(MEX_ZIP) -C $(fpath)`)
end

mexzip_sha256 = open(MEX_ZIP) do f
    bytes2hex(sha256(f))
end


Pkg.Artifacts.bind_artifact!(
    joinpath(pkgdir(MATFrost), "Artifacts.toml"), 
    "matfrost-mex",
    artifact_id, 
    download_info=Tuple[(
        "https://github.com/ASML-Labs/MATFrost.jl/releases/download/v" * MATFROST_VERSION * "/matfrost-mex-v" * MATFROST_VERSION * ".tar.gz", 
        mexzip_sha256
    )], force=true)
