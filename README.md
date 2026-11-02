![MATLAB versions](https://img.shields.io/badge/MATLAB-R2021b+-blue.svg)
![Julia support](https://img.shields.io/badge/Julia%20-v1.7+-purple)
![Windows](https://img.shields.io/badge/Windows-0078D6)
![Linux](https://img.shields.io/badge/Linux-FCC624)
[![Tests](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests.yml/badge.svg?event=schedule)](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests.yml)

# MATFrost.jl - Embedding Julia in MATLAB

MATFrost enables quick and easy embedding of Julia inside MATLAB. It is like Bifrost but between Julia and MATLAB

Characteristics:
1. Interface defined on Julia side.
2. Nested datatypes supported.
3. Leveraging Julia environments for reproducible builds.

# Quick start 🚀
```matlab
% MATLAB
system('julia -e "import Pkg ; Pkg.add(ARGS[1]) ; using MATFrost ; MATFrost.install()" "MATFrost"');
   % Install MATLAB bindings. This will install @matfrostjulia inside current working directory.

jl = matfrostjulia(); 
   % Spawn a matfrostjulia server running JULIA

jl.MATFrost.Example.hello_world() 
   % > 'Hello Julia! :)'

jl.MATFrost.Example.multiply_scalar_vector_f64(5.0, [1.0; 4.0; 9.0; 16.0]) 
   % > [5.0; 20.0; 45.0; 80.0]
```

# API: Start MATFrost server 

## Select Julia binary
* Option 1 (recommended): Use Juliaup and select by version:
   ```matlab
   jl = matfrostjulia(version="1.12");                   
      % Julia version. (Accepted values are Juliaup channels)
   ```
* Option 2: Julia binary directory:
   ```matlab
   jl = matfrostjulia(bindir="<bindir>");                           
   ```
* Option 3: Based on Julia configured in PATH
   ```matlab
   jl = matfrostjulia();                              
   ```

## Select Julia environment/project
Specify Julia environment. If not defined will use default startup environment.
https://pkgdocs.julialang.org/v1/environments/

```matlab
   jl = matfrostjulia(project="<projectdir>");    
      % Directory containing Julia environment.
      % acts like: `julia --project=<projectdir> ...`
```

## Use a custom system image (faster startup)

Heavy packages can be compiled ahead of time into a Julia system image with
[PackageCompiler.jl](https://github.com/JuliaLang/PackageCompiler.jl), so no
compilation happens when the MATFrost server starts:

```julia
# Julia (run inside the environment you pass as `project`)
using PackageCompiler
create_sysimage(["MATFrost", "MyPackage"];
                sysimage_path = "matfrost_sys.dll",          # .so on Linux
                precompile_execution_file = "warmup.jl")     # optional: typical calls
```

```matlab
% MATLAB
jl = matfrostjulia(version="1.12", project="<projectdir>", sysimage="matfrost_sys.dll");
   % acts like: `julia --sysimage=<sysimage> --project=<projectdir> ...`
```

Notes:

- The system image only works with the exact Julia version that built it; select that version with `version` or `bindir`.
- Include `MATFrost` in the system image and keep it in the `project` environment, otherwise it is loaded (and compiled) the normal way.
- The MATFrost version in the system image must match the installed MATLAB bindings.

## Calling Julia functions
Julia functions are called according to:
```matlab
% MATLAB
jl.Package1.function1(arg1, arg2)
```

which operates as:
```julia
# Julia
import Package1

Package1.function1(arg1, arg2)
```

Additionally nested modules are supported:
```matlab
%MATLAB
jl.Package1.NestedModule1.function1(arg1, arg2)    
```

## Handling ambiguous Julia functions with `signature`

MATFrost now supports calling overloaded Julia functions by specifying the targeted method using the `signature` argument from MATLAB.

Suppose you define a custom `Point` type and overload the `Base.+` operator in Julia:

```julia
module MyGeometry

struct Point
    x::Int
    y::Int
end

Base.:(+)(p1::Point, p2::Point) = Point(p1.x + p2.x, p1.y + p2.y)

end
```

You can then use MATFrost from MATLAB to create and add `Point` objects, specifying the method signature to ensure the correct overload is called:

```matlab
% MATLAB
% Create two Julia Point objects
p1 = tc.mjl.MATFrostTest.Point(int64(1), int64(2),signature=["Int64","Int64"]);
p2 = tc.mjl.MATFrostTest.Point(int64(3), int64(4),signature=["Int64","Int64"]);

% Call the overloaded Base.+ method for Point
res = tc.mjl.Base.('+')(p1, p2, signature=["MATFrostTest.Point", "MATFrostTest.Point"]);  % returns Point(4, 6)
```

Here, `signature=["MyGeometry.Point", "MyGeometry.Point"]` ensures the correct method for adding two `Point` objects is called.

**Notes:**
- Use a string for a single type, or a cell/string array for multiple types.
- The types in `signature` must match the Julia method’s argument types exactly.

This feature allows you to disambiguate overloaded Julia functions directly from MATLAB.

## Keep Julia objects in Julia with handles

By default, MATFrost marshals Julia objects into MATLAB values. For large or
stateful objects, repeatedly transferring their contents can be expensive. Opt a
Julia type into handle conversion to keep the object in Julia: MATLAB receives
only a small struct containing `dataType`, `id`, and `typename`. Passing this
handle back to Julia resolves the original object rather than reconstructing it
from its fields.

For example, define the following in a Julia package available in your MATFrost
project:

```julia
module MySimulation

import MATFrost

mutable struct State
   values::Vector{Float64}
end

MATFrost.use_matfrost_handle(::Type{State}) = true

create_state(count::Int64) = State(zeros(count))

function add!(state::State, amount::Float64)
   state.values .+= amount
   return sum(state.values)
end

snapshot(state::State) = copy(state.values)

end
```

Use the object from MATLAB without transferring its vector on each call:

```matlab
jl = matfrostjulia(project="<projectdir>");
state = jl.MySimulation.create_state(int64(1000000), signature="Int64");
total = jl.MySimulation.("add!")(state, 2.0, ...
   signature=[state.typename, "Float64"]); % 2000000
values = jl.MySimulation.snapshot(state, signature=state.typename);
   % Explicitly transfer the vector to MATLAB when needed.
jl.MATFrost.("release_all_handles!")();
   % Release all stored objects when no handles are needed anymore.
```

The vector is allocated and updated in Julia; only the handle and scalar result
are marshalled during the update. Mutations affect the original Julia object,
and copies of the MATLAB handle refer to that same object. The handle is an
opaque reference, not a MATLAB handle-class object; access its data through Julia
functions rather than MATLAB field indexing.

Handles belong to the Julia server process that created them and cannot be
reused after it exits. Stored objects remain referenced until explicitly
released or the process exits: clearing a MATLAB variable does not release them.
Julia code can release an individual reference with
`MATFrost.release_handle(handle::MATFrost.MATFrostHandle)` or
`MATFrost.release_handle(id::UUID)`. `MATFrost.release_all_handles!()` invalidates
all outstanding handles in that server process.

## Type mapping

### Scalars and Arrays conversions
MATLAB doesn't have the same flexibility of expressing scalars and arrays as Julia. The following conversions scheme has been implemented. This scheme applies to all including primitives, structs, named tuples, tuples.

| MATLAB                               |      Julia           |
|--------------------------------------|----------------------|
| `(1, 1)`                             | scalar               |
| `(:, 1)` - Column vector (see note)  | `Vector`             |
| `(:, :)`                             | `Matrix`             |
| `(:, :, ...)` - Array order `N`      | `Array{N}`           |


NOTE: Row vector MATLAB objects `(1,:)` **cannot** be passed to `Vector` inputs.

### Primitives

| MATLAB              |      Julia           |
|---------------------|----------------------|
| `string`            | `String`             |
| -                   | -                    |
| `single`            | `Float32`            |
| `double`            | `Float64`            |
| -                   | -                    |
| `int8`              | `Int8`               |
| `uint8`             | `UInt8`              |
| `int16`             | `Int16`              |
| `uint16`            | `UInt16`             |
| `int32`             | `Int32`              |
| `uint32`            | `UInt32`             |
| `int64`             | `Int64`              |
| `uint64`            | `UInt64`             |
| -                   | -                    |
| `single (complex)`  | `Complex{Float32}`   |
| `double (complex)`  | `Complex{Float64}`   |

NOTE: Values will **not** be automatically converted. If the interface requests `Int64` it will not accept a MATLAB `double`.


### Struct and NamedTuple
Julia `struct` and `NamedTuple` are mapped to MATLAB structs. Any struct or named tuple is supported as long as it is concrete entirely (concrete for all its nested types). See earlier section for examples.

```julia
# Julia
module Population

struct City
   name::String
   population::Int64
end

struct Country
   cities::Vector{City}
   area::Float64
end

total_population(country::Country) = sum((city.population for city in country.cities))

end
```

```matlab
% MATLAB
cities = [struct(name="Amsterdam", population=int64(920)); ...
          struct(name="Den Haag",  population=int64(565)); ...
          struct(name="Eindhoven", population=int64(246))];

country = struct(cities=cities, area=321.0)

mjl.Population.total_population(cities) % 920+565+246 = 1731
```

### Tuples
Julia `Tuple` map to MATLAB `cell` column vectors.

```julia
# Julia
module TupleExample

tuple_sum(t::NTuple{4, Float64}) = sum(t)

end
```

```matlab
% MATLAB
mjl.TupleExample.tuple_sum({3.0; 4.0; 5.0; 6.0}) % 18.0
```


