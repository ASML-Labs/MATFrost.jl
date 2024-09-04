![MATLAB versions](https://img.shields.io/badge/MATLAB-R2022b-blue.svg)
![Julia support](https://img.shields.io/badge/Julia%20-v1.7+-purple)

[![Windows](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests.yml/badge.svg?branch=main)](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests.yml)
<!-- [![windows](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests-windows.yml/badge.svg)](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests-windows.yml) -->
<!-- [![ubuntu](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests-ubuntu.yml/badge.svg)](https://github.com/ASML-Labs/MATFrost.jl/actions/workflows/run-tests-ubuntu.yml) -->


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
system('julia -e "import Pkg ; Pkg.generate(""MATFrostHelloWorld"") ; Pkg.activate(""./MATFrostHelloWorld"") ; Pkg.add(name=""MATFrost"")" ; Pkg.instantiate()');
   % Generate a MATFrost Julia project and add MATFrost.

system('julia --project="./MATFrostHelloWorld" -e "import MATFrost ; MATFrost.install()"');
   % Generate MATLAB bindings for MATFrostHelloWorld

writelines(...
   "module MATFrostHelloWorld" + newline + ...
      "matfrost_hello_world()=""Hello Julia! :)""" + newline + ...
   "end", ...
   fullfile("MATFrostHelloWorld", "src", "MATFrostHelloWorld.jl"))
   % Add simple hello_world function

mjl = MATFrostHelloWorld(...
    instantiate=true); 
   % Spawn a matfrostjulia process running JULIA

mjl.MATFrostHelloWorld.matfrost_hello_world() 
   % 'Hello Julia! :)'
```


For more examples see the examples folder. 

# Workflow
In this section we would like to explain the workflow of integrating Julia functionality into MATLAB using MATFrost. 

1. Generate a new Julia environment. 
   ```
   (@v1.10) pkg> generate MATFrostWorkflowExample
      Generating  project MATFrostWorkflowExample:
        MATFrostWorkflowExample/Project.toml
        MATFrostWorkflowExample/src/MATFrostWorkflowExample.jl
   ```
2. Activate environment
   ```
   (@v1.10) pkg> activate ./MATFrostWorkflowExample
   ```
3. Add MATFrost dependency
   ```
   (MATFrostWorkflowExample) pkg> add MATFrost
   ```
4. Generate MATLAB bindings. This will create a new class folder `@MATFrostWorkflowExample` acting as the MATLAB entrypoint.
   ```julia
   using MATFrost
   MATFrost.install()
   ```
5. Edit `MATFrostWorkflowExample/src/MATFrostWorkflowExample.jl`
   ```julia
   module MATFrostWorkflowExample

   broadcast_multiply(c::Float64, v::Vector{Float64}) = c.*v

   end # module MATFrostWorkflowExample
   ```
6. Construct a `MATFrostWorkflowExample` object. This will spawn a Julia process (using Juliaup channel +1.10) set to `MATFrostWorkflowExample` environment.
   ```matlab
   mjl = MATFrostWorkflowExample(...
      version = "1.10");
   ```
7. Call `broadcast_multiply`. This will call function `broadcast_multiply` in package `MATFrostWorkflowExample` of environment `MATFrostWorkflowExample`.
   ```matlab
   mjl.MATFrostWorkflowExample.broadcast_multiply(3.0, [1.0; 2.0; 3.0]) % [3.0; 6.0; 9.0]
   ``` 


# API

## Construct MATFrost object
Constructing a MATFrost object, which from now on we call `MATFrostHelloWorld`, will spawn a new process with Julia loaded. The Julia binaries are specified in the constructor. Three options are given to locate the Julia binaries.

* Option 1 (recommended): Julia version to link to Julia binaries - requires Juliaup:
   ```matlab
   mjl = MATFrostHelloWorld(...
      version = "1.10");                   % Julia version. (Accepted values are Juliaup channels)
   ```
* Option 2: Julia binary directory:
   ```matlab
   mjl = MATFrostHelloWorld(...
      bindir = <bindir>);                  % Directory containing Julia binaries
   ```
* Option 3: Based on Julia configured in PATH
   ```matlab
   mjl = MATFrostHelloWorld();    % Directory containing Julia environment.
   ```

### Option: Instantiate
An additional option instantiate will resolve project environment at construction of `MATFrostHelloWorld`. This will call `Pkg.instantiate()`. 

```matlab
mjl = MATFrostHelloWorld(...
   version = "1.10", ...
   instantiate = true);  % By default is turned off.              
```

## Calling Julia functions

Julia functions are called according to:
```matlab
% MATLAB
mjl.Package1.function1(arg1, arg2)
```
which operates as:
```julia
# Julia
import Package1

Package1.function1(arg1, arg2)
```

And to increase readability:
```matlab
% MATLAB
mjl = MATFrostHelloWorld();
    
hwjl = mjl.MATFrostHelloWorld; 

hwjl.matfrost_hello_world(); % 'Hello Julia! :)'
```

## Conditions Julia functions
To be able to call Julia functions through MATFrost it needs to satisfy some conditions.

1. The Julia function should have a single method implementation.
2. The function input signature should be fully typed and concrete entirely (meaning any nested type is concrete as well). 


```julia
# Bad
struct Point # `Point` is not concrete entirely as `Number` is abstract.
   x :: Number 
   y :: Number
end

Base.:(+)(p1::Point, p2::Point) = Point(p1.x + p2.x, p1.y + p2.y)
# `Base.+` function contains many method implementations.
```

```julia
# Good
struct Point # `Point` is concrete entirely as `Float64` is concrete.
   x :: Float64 
   y :: Float64
end

matfrost_addition(p1::Point, p2::Point) = Point(p1.x + p2.x, p1.y + p2.y)
# `matfrost_addition` function has a single method implementation
```

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


