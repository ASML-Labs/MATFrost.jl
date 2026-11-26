
function install(destdir=pwd())

if isdir(joinpath(destdir, "@matfrostjulia"))
    rm(joinpath(destdir, "@matfrostjulia"), recursive=true)
end

mkpath(joinpath(destdir, "@matfrostjulia"))

cp(joinpath(pkgdir(MATFrost), "src", "matlab", "@matfrostjulia"), joinpath(destdir, "@matfrostjulia"), force=true)
table_helpers = joinpath(pkgdir(MATFrost), "src", "matlab", "+matfrost")
mkpath(joinpath(destdir, "+matfrost"))
for file in readdir(table_helpers)
    cp(joinpath(table_helpers, file), joinpath(destdir, "+matfrost", file), force=true)
end

foreach(readdir(artifact"matfrost-mex")) do fp
    cp(joinpath(artifact"matfrost-mex", fp),  joinpath(destdir, "@matfrostjulia", "private", fp), force=true)
end

end


mexbinaryartifact() = artifact"matfrost-mex"

