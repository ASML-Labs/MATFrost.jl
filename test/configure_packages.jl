import Pkg

test_root = @__DIR__

if VERSION < v"1.11"
	Pkg.develop([
		Pkg.PackageSpec(path=joinpath(test_root, "Geometry")),
		Pkg.PackageSpec(path=joinpath(test_root, "..")),
		Pkg.PackageSpec(path=joinpath(test_root, "MATFrostGeometryExt")),
	])
end

Pkg.resolve()
Pkg.instantiate()
