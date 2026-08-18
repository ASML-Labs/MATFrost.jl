
function install(destdir=pwd())

if isdir(joinpath(destdir, "@matfrostjulia"))
    rm(joinpath(destdir, "@matfrostjulia"), recursive=true)
end

if isdir(joinpath(destdir, "+MATFrost"))
    rm(joinpath(destdir, "+MATFrost"), recursive=true)
end

for entry in readdir(joinpath(pkgdir(MATFrost), "src", "matlab"))
    cp(
        joinpath(pkgdir(MATFrost), "src", "matlab", entry),
        joinpath(destdir, entry),
        force=true
    )
end

foreach(readdir(artifact"matfrost-mex")) do fp
    cp(joinpath(artifact"matfrost-mex", fp),  joinpath(destdir, "@matfrostjulia", "private", fp), force=true)
end

end


mexbinaryartifact() = artifact"matfrost-mex"

