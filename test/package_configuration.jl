module PackageConfigurationTests

using Test
using Pkg
using TOML
using UUIDs

include(joinpath(@__DIR__, "..", "src", "matlab", "@matfrostjulia", "configure_packages.jl"))

function write_project(directory, project)
    mkpath(directory)
    open(joinpath(directory, "Project.toml"), "w") do output
        TOML.print(output, project)
    end
end

@testset "Recursive local package sources" begin
    mktempdir() do environment
        leaf = joinpath(environment, "packages", "MATFrostConfigLeaf")
        root = joinpath(environment, "packages", "MATFrostConfigRoot")
        leaf_uuid = string(uuid4())
        root_uuid = string(uuid4())

        write_project(leaf, Dict(
            "name" => "MATFrostConfigLeaf", "uuid" => leaf_uuid, "version" => "0.1.0",
        ))
        mkpath(joinpath(leaf, "src"))
        open(joinpath(leaf, "src", "MATFrostConfigLeaf.jl"), "w") do output
            print(output, "module MATFrostConfigLeaf\nvalue() = 42\nend\n")
        end

        write_project(root, Dict(
            "name" => "MATFrostConfigRoot", "uuid" => root_uuid, "version" => "0.1.0",
            "deps" => Dict("MATFrostConfigLeaf" => leaf_uuid),
            "sources" => Dict("MATFrostConfigLeaf" => Dict("path" => "../MATFrostConfigLeaf")),
        ))
        mkpath(joinpath(root, "src"))
        open(joinpath(root, "src", "MATFrostConfigRoot.jl"), "w") do output
            print(output, "module MATFrostConfigRoot\nusing MATFrostConfigLeaf\nvalue() = MATFrostConfigLeaf.value()\nend\n")
        end

        project = Dict(
            "deps" => Dict("MATFrostConfigRoot" => root_uuid, "MATFrostConfigLeaf" => leaf_uuid),
            "sources" => Dict("MATFrostConfigRoot" => Dict("path" => "packages/MATFrostConfigRoot")),
        )
        write_project(environment, project)

        packages = Pkg.PackageSpec[]
        ConfigurePackages.collect_sources!(joinpath(environment, "Project.toml"), Set{String}(), packages)
        @test length(packages) == 2
        @test Set(normpath(package.path) for package in packages) == Set([root, leaf])

        project["sources"]["MATFrostConfigLeaf"] = Dict("path" => "packages/MATFrostConfigLeaf")
        write_project(environment, project)
        packages = Pkg.PackageSpec[]
        ConfigurePackages.collect_sources!(joinpath(environment, "Project.toml"), Set{String}(), packages)
        @test length(packages) == 2
        @test !isfile(joinpath(environment, "Manifest.toml"))

        configure_packages = joinpath(
            @__DIR__, "..", "src", "matlab", "@matfrostjulia", "configure_packages.jl",
        )
        @test success(pipeline(
            `$(Base.julia_cmd()) --startup-file=no $configure_packages $environment`,
            stdout = stdout, stderr = stderr,
        ))
        @test isfile(joinpath(environment, "Manifest.toml"))
        @test success(pipeline(
            `$(Base.julia_cmd()) --startup-file=no --project=$environment -e "using MATFrostConfigRoot; @assert MATFrostConfigRoot.value() == 42"`,
            stdout = stdout, stderr = stderr,
        ))
    end
end

end