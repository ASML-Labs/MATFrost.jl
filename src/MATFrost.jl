module MATFrost
using Scratch

mexdir() = @get_scratch!("mexbin") 

matlabpath() = joinpath(pkgdir(MATFrost), "src", "matlab") * ";" * mexdir()

matlabpathexamples() = matlabpath() * ";" * joinpath(pkgdir(MATFrost), "examples", "01-MATFrostHelloWorld")

end
