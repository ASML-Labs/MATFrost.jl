"""
The bootstrap script for launching the matfrostserver.
"""

println("Starting MATFrost server")

MATFROST_MATLAB_VERSION = v"0.5.0"

try
    using MATFrost
catch _
    import Pkg
    Pkg.instantiate()
    try
        using MATFrost
    catch _
        Pkg.add(name="MATFrost", version=MATFROST_MATLAB_VERSION)
        using MATFrost
    end
end

let
    # Verify MATLAB MATFrost version is synchronized with Julia MATFrost version.
    MATFROST_JULIA_VERSION = if VERSION >= v"1.9"
        pkgversion(MATFrost)
    else
        using TOML
        project = TOML.parsefile(joinpath(pkgdir(MATFrost), "Project.toml"))
        VersionNumber(project["version"])
    end

    if MATFROST_MATLAB_VERSION > MATFROST_JULIA_VERSION
        import Pkg
        Pkg.add(name="MATFrost", version=MATFROST_MATLAB_VERSION)
        error("MATFrost version mismatch.\n MATFrost-Julia has been updated. Please restart matfrostjulia \n    MATLAB-MATFrost: $(MATFROST_MATLAB_VERSION)\n    Julia-MATFrost: $(MATFROST_JULIA_VERSION)")
    elseif MATFROST_MATLAB_VERSION < MATFROST_JULIA_VERSION
        error("MATFrost-MATLAB bindings are outdated. Please reinstall using `MATFrost.install()`\n    MATLAB-MATFrost: $(MATFROST_MATLAB_VERSION)\n    Julia-MATFrost: $(MATFROST_JULIA_VERSION)\n\n\n\n")
    end


end


MATFrost.matfrostserve(ARGS[1])
