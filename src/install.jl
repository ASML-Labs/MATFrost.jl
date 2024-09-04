
function install()

projectname = TOML.parsefile(Base.active_project())["name"]

joinpath(pkgdir(MATFrost), "src", "matlab")

matdir = joinpath(Base.active_project(), "..", "..", "TEMP_" * projectname)

cp(joinpath(pkgdir(MATFrost), "src", "matlab"), 
    matdir, force=true)

matfrostjulia = read(joinpath(pkgdir(MATFrost), "src", "matlab", "matfrostjulia.m"), String)

matfrostjulia = replace(matfrostjulia, " matfrostjulia " => " " * projectname * " ")
matfrostjulia = replace(matfrostjulia, "matfrostjulia(argstruct)" => (projectname * "(argstruct)"))
matfrostjulia = replace(matfrostjulia, "\"matfrostjulia\"" =>  "\"" * projectname * "\"")

write(joinpath(matdir, projectname * ".m"), matfrostjulia)

rm(joinpath(matdir, "matfrostjulia.m"))

foreach(readdir(artifact"matfrost-mex")) do fp
    cp(joinpath(artifact"matfrost-mex", fp),  joinpath(matdir, "private", fp))
end

mv(matdir, joinpath(Base.active_project(), "..", "..", "@" * projectname), force=true)


end
