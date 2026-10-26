using Pkg

length(ARGS) == 1 || error(
    "Usage: julia configure_packages.jl <environment>"
)

environment = abspath(only(ARGS))
if VERSION < v"1.11"
project_file = joinpath(environment, "Project.toml")

isfile(project_file) || error(
    "Project.toml not found at: $project_file"
)

using TOML
project = TOML.parsefile(project_file)
sources = get(project, "sources", Dict{String,Any}())

packages = Pkg.PackageSpec[]

for (name, source) in sources
    source isa AbstractDict || continue

    path = get(source, "path", nothing)
    path isa AbstractString || continue

    package_path = normpath(environment, path)
    @info "Developing package" name package_path
    push!(
        packages,
        Pkg.PackageSpec(
            name=name,
            path=normpath(environment, path),
        ),
    )
end
Pkg.activate(environment)

isempty(packages) || Pkg.develop(packages)
Pkg.resolve()
else 
    Pkg.activate(environment)
end

Pkg.instantiate()