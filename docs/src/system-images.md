# System Images

MATFrost can start Julia with a custom system image created by
[PackageCompiler.jl](https://julialang.github.io/PackageCompiler.jl/). A system
image can reduce compilation and startup work for packages used by an
application.

Build the image in the same Julia environment you will pass to MATFrost:

```julia
using PackageCompiler

create_sysimage(
    ["MATFrost", "MyPackage"];
    sysimage_path = "matfrost_sysimage.dll", # Use .so on Linux.
    precompile_execution_file = "warmup.jl",
)
```

Pass the image when constructing the MATLAB server:

```matlab
jl = matfrostjulia( ...
    version="1.13", ...
    project="<project-directory>", ...
    sysimage="matfrost_sysimage.dll");
```

The image must be built with the exact Julia version used to start the server.
It should include MATFrost and the application packages, and its MATFrost
version must match the installed MATLAB bindings.