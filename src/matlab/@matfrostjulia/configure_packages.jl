module ConfigurePackages

using Pkg
using TOML

export configure_packages

function collect_sources!(
    project_file::AbstractString,
    visited::Set{String},
    packages::Vector{Pkg.PackageSpec},
)
    project_file = abspath(project_file)
    project_file in visited && return
    push!(visited, project_file)

    project = TOML.parsefile(project_file)
    project_dir = dirname(project_file)

    for source in values(get(project, "sources", Dict{String,Any}()))
        source isa AbstractDict || continue
        haskey(source, "path") || continue

        package_dir = normpath(joinpath(project_dir, source["path"]))
        package_project = joinpath(package_dir, "Project.toml")
        isfile(package_project) || error("No Project.toml found for source package at $package_dir")

        if !(abspath(package_project) in visited)
            push!(packages, Pkg.PackageSpec(path = package_dir))
            collect_sources!(package_project, visited, packages)
        end
    end

    return nothing
end

function configure_packages(environment::AbstractString)
    environment = abspath(environment)
    project_file = isdir(environment) ? joinpath(environment, "Project.toml") : environment
    isfile(project_file) || error("Project.toml not found at $project_file")

    Pkg.activate(dirname(project_file))
    if VERSION < v"1.11"
        packages = Pkg.PackageSpec[]
        collect_sources!(project_file, Set{String}(), packages)
        isempty(packages) || Pkg.develop(packages)
        Pkg.resolve()
    end

    Pkg.instantiate()
    return nothing
end

end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    length(ARGS) == 1 || error("Usage: configure_packages.jl <environment>")
    ConfigurePackages.configure_packages(only(ARGS))
end