![MATLAB versions](https://img.shields.io/badge/MATLAB-R2021b+-blue.svg)
![Julia support](https://img.shields.io/badge/Julia%20-v1.7+-purple)

[![Windows](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests.yml/badge.svg?branch=main)](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests.yml)
<!-- [![windows](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests-windows.yml/badge.svg)](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests-windows.yml) -->
<!-- [![ubuntu](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests-ubuntu.yml/badge.svg)](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests-ubuntu.yml) -->

> [!IMPORTANT]
> Linux support in development. New revision will run Julia completely isolated into its own process, thereby preventing any library collisions.


# MATFrost.jl - Embedding Julia in MATLAB

MATFrost enables quick and easy embedding of Julia inside MATLAB. It is like Bifrost but between Julia and MATLAB


Characteristics:
1. Interface defined on Julia side.
2. Nested datatypes supported.
3. Leveraging Julia environments for reproducible builds.
4. Julia runs in its own mexhost process.


# Linux not supported yet!
Linux not supported at this point. Default library `libunwind.so` bundled with MATLAB is incompatible with Julia. 


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
   jl = matfrostjulia(version="1.10");                   
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


