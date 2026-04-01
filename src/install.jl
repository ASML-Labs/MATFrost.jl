
function install(destdir=pwd())

if isdir(joinpath(destdir, "@matfrostjulia"))
    rm(joinpath(destdir, "@matfrostjulia"), recursive=true)
end

mkpath(joinpath(destdir, "@matfrostjulia"))

cp(joinpath(pkgdir(MATFrost), "src", "matlab", "@matfrostjulia"), joinpath(destdir, "@matfrostjulia"), force=true)

foreach(readdir(artifact"matfrost-mex")) do fp
    cp(joinpath(artifact"matfrost-mex", fp),  joinpath(destdir, "@matfrostjulia", "private", fp), force=true)
end

end


mexbinaryartifact() = artifact"matfrost-mex"

