"""
The bootstrap script for launching the matfrostserver.
"""

println("Starting MATFrost server")

MATFROST_MATLAB_VERSION = v"0.0.0" # Version is patched automatically during release

try
    using MATFrost
catch _
    import Pkg

    if VERSION < v"1.11"
        # [sources] is ignored before Julia 1.11, so path-dependencies must be developed explicitly.
        project_file = Base.active_project()
        sources = get(Pkg.TOML.parsefile(project_file), "sources", Dict{String,Any}())
        specs = [Pkg.PackageSpec(path=normpath(joinpath(dirname(project_file), source["path"])))
                 for (_, source) in sources if haskey(source, "path")]
        if !isempty(specs)
            Pkg.develop(specs)
        end
    end

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


MATFrost.matfrostserve(ARGS[1], parse(Int, ARGS[2]))
