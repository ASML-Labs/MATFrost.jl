![MATLAB versions](https://img.shields.io/badge/MATLAB-R2021b+-blue.svg)
![Julia support](https://img.shields.io/badge/Julia%20-v1.7+-purple)
![Windows](https://img.shields.io/badge/Windows-0078D6)
![Linux](https://img.shields.io/badge/Linux-FCC624)
[![Tests](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests.yml/badge.svg?event=schedule)](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests.yml)
[![Documentation](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/docs.yml/badge.svg)](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/docs.yml)

# MATFrost.jl

MATFrost embeds Julia in MATLAB. Call Julia package functions from MATLAB while
keeping your Julia code and package environments as the source of the API.

## Install

In Julia, add MATFrost to the environment you plan to use and install its MATLAB
bindings into MATLAB's current working directory:

```julia
import Pkg
Pkg.add("MATFrost")
using MATFrost
MATFrost.install()
```

Then start a Julia server and call a package function from MATLAB:

```matlab
jl = matfrostjulia(version="1.13", project="<project-directory>");
result = jl.MyPackage.my_function(argument);
```

See the **[MATFrost documentation](https://asml-labs.github.io/MATFrost.jl/stable/)**
for installation details, Julia/MATLAB type conversion, method selection,
object handles, and system images.