import Pkg

test_root = @__DIR__

if VERSION < v"1.11"
	for path in (
		joinpath(test_root, ".."),
		joinpath(test_root, "MATFrostTest"),
		joinpath(test_root, "Geometry"),
		joinpath(test_root, "MATFrostGeometryExt"),
	)
		Pkg.develop(path=path)
	end
end

Pkg.resolve()
Pkg.instantiate()
