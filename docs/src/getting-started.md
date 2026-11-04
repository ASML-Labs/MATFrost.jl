# Getting Started

## Requirements

- MATLAB R2021b or later.
- Julia 1.7 or later.
- A Julia environment containing `MATFrost` and the Julia packages you want to call.

## Install MATFrost

Add MATFrost to the Julia environment that MATLAB will use, then install the
MATLAB bindings into the current MATLAB working directory:

```julia
import Pkg
Pkg.add("MATFrost")
using MATFrost
MATFrost.install()
```

The install step places the `@matfrostjulia` MATLAB class and the platform MEX
binary in the current working directory. Run it again after updating MATFrost.

## Start a Julia server

In MATLAB, select a Juliaup channel and environment explicitly:

```matlab
jl = matfrostjulia(version="1.13", project="<project-directory>");
```

The `project` argument is a directory containing Julia's `Project.toml`. If it
is omitted, Julia uses its default active environment. The `version` argument
can be omitted to use the Julia executable on `PATH`; `bindir` can be used to
select a Julia installation by its binary directory instead.

MATFrost starts the Julia server when the object is constructed. Deleting the
MATLAB object stops its associated server:

```matlab
delete(jl)
```

See [System Images](@ref) for reducing startup and compilation time.