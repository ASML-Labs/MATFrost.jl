
function install()

projectname = TOML.parsefile(Base.active_project())["name"]

projectdirrel = splitpath(Base.active_project())[end-1]

joinpath(pkgdir(MATFrost), "src", "matlab")

matdir = joinpath(Base.active_project(), "..", "..", "TEMP_" * projectname)

cp(joinpath(pkgdir(MATFrost), "src", "matlab"), 
    matdir, force=true)

matfrostjulia = read(joinpath(pkgdir(MATFrost), "src", "matlab", "matfrostjulia.m"), String)

# The following manipulations will convert base file `matfrostjulia.m` to target environment MATLAB bindings.
matfrostjulia = replace(matfrostjulia, "classdef matfrostjulia"                  => "classdef " * projectname)                          # Replace class name.           (Line: 1)
matfrostjulia = replace(matfrostjulia, "{{ relative_environment }}"              => projectdirrel)                                      # Replace relative environment. (Line: ~14)
matfrostjulia = replace(matfrostjulia, "function obj = matfrostjulia(argstruct)" => ("function obj = " * projectname * "(argstruct)"))  # Replace constructor name.     (Line: ~25)

write(joinpath(matdir, projectname * ".m"), matfrostjulia)

rm(joinpath(matdir, "matfrostjulia.m"))

foreach(readdir(artifact"matfrost-mex")) do fp
    cp(joinpath(artifact"matfrost-mex", fp),  joinpath(matdir, "private", fp))
end

mv(matdir, joinpath(Base.active_project(), "..", "..", "@" * projectname), force=true)


end
