
function install()

projectname = TOML.parsefile(Base.active_project())["name"]

joinpath(pkgdir(MATFrost), "src", "matlab")

matdir = joinpath(Base.active_project(), "..", "..", "@" * projectname)

cp(joinpath(pkgdir(MATFrost), "src", "matlab"), 
    matdir, force=true)

matfrostjulia = read(joinpath(matdir, "matfrostjulia.m"), String)

matfrostjulia = replace(matfrostjulia, " matfrostjulia " => " " * projectname * " ")
matfrostjulia = replace(matfrostjulia, "matfrostjulia(argstruct)" => (projectname * "(argstruct)"))
matfrostjulia = replace(matfrostjulia, "\"matfrostjulia\"" =>  "\"" * projectname * "\"")

write(joinpath(matdir, "matfrostjulia.m"), matfrostjulia)

mv(joinpath(matdir, "matfrostjulia.m"), 
    joinpath(matdir, projectname * ".m"))


# cp(joinpath(artifact"matfrost-mex"), joinpath(matdir, "private"))

foreach(readdir(artifact"matfrost-mex")) do fp
    cp(joinpath(artifact"matfrost-mex", fp),  joinpath(matdir, "private", fp))
end


end
