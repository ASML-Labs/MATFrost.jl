"""
The bootstrap script for launching the MATFrost server.
"""

println("Starting MATFrost server")

MATFROST_MATLAB_VERSION =
    v"0.0.0" # Version is patched automatically during release

try
    using MATFrost
catch initial_load_error
    import Pkg

    include(joinpath(@__DIR__, "configure_packages.jl"))

    active_project = Base.active_project()

    active_project === nothing &&
        error("No active Julia project is available.")

    ConfigurePackages.configure_packages(
        dirname(active_project),
    )

    try
        using MATFrost
    catch configured_load_error
        # Version 0.0.0 represents the development checkout and does not
        # exist in the package registry. Never try to add that version.
        if MATFROST_MATLAB_VERSION == v"0.0.0"
            @error(
                "MATFrost could not be loaded after configuring local sources.",
                active_project,
                initial_load_error,
                configured_load_error,
            )

            rethrow(configured_load_error)
        end

        Pkg.add(
            name = "MATFrost",
            version = MATFROST_MATLAB_VERSION,
        )

        using MATFrost
    end
end

let
    # Verify that the MATLAB and Julia MATFrost versions are synchronized.
    MATFROST_JULIA_VERSION = if VERSION >= v"1.9"
        pkgversion(MATFrost)
    else
        using TOML

        project = TOML.parsefile(
            joinpath(pkgdir(MATFrost), "Project.toml"),
        )

        VersionNumber(project["version"])
    end

    if MATFROST_MATLAB_VERSION > MATFROST_JULIA_VERSION
        import Pkg

        Pkg.add(
            name = "MATFrost",
            version = MATFROST_MATLAB_VERSION,
        )

        error(
            """
            MATFrost version mismatch.
            MATFrost-Julia has been updated. Please restart matfrostjulia.

                MATLAB-MATFrost: $(MATFROST_MATLAB_VERSION)
                Julia-MATFrost:  $(MATFROST_JULIA_VERSION)
            """,
        )
    elseif MATFROST_MATLAB_VERSION < MATFROST_JULIA_VERSION
        error(
            """
            MATFrost-MATLAB bindings are outdated.
            Please reinstall using `MATFrost.install()`.

                MATLAB-MATFrost: $(MATFROST_MATLAB_VERSION)
                Julia-MATFrost:  $(MATFROST_JULIA_VERSION)
            """,
        )
    end
end

MATFrost.matfrostserve(
    ARGS[1],
    parse(Int, ARGS[2]),
)