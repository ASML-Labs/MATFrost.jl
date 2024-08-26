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

# Prerequisites: MATLAB MEX C++ compiler configured
1. Windows: MinGW-w64 installed: https://mathworks.com/support/requirements/supported-compilers.html 
   ```matlab
   % Install official MATLAB MinGW-w64 add-on.
   websave("mingw.mlpkginstall", "https://mathworks.com/matlabcentral/mlc-downloads/downloads/submissions/52848/versions/22/download/mlpkginstall")
   uiopen("mingw.mlpkginstall",1)
   ```
   Alternatively, install MinGW-w64 manually and link with MATLAB using `MW_MINGW64_LOC` environment variable.
<!-- 2. Linux: GCC installed: https://mathworks.com/support/requirements/supported-compilers-linux.html -->

# Linux not supported yet!
Linux not supported at this point. Default library `libunwind.so` bundled with MATLAB is incompatible with Julia.  


# Quick start 🚀
```matlab
% MATLAB
system('julia --project="@MATFrostEnvironment" -e "import Pkg ; Pkg.add(name=""MATFrost"")"');
   % Install MATFrost

[~, matfrostmatlabpath] = system('julia --project="@MATFrostEnvironment" -e "import MATFrost ; print(MATFrost.matlabpathexamples())"');
addpath(matfrostmatlabpath);
   % Bootstrap MATFrost (including examples)

mjl = matfrostjulia(...
    environment=matfrost_helloworld_environment(), ... % Example Hello World environment. 
    instantiate=true); 
   % Spawn a matfrostjulia process running JULIA

mjl.MATFrostHelloWorld.matfrost_hello_world() % 'Hello Julia! :)'
   % (See: examples/01-MATFrostHelloWorld/MATFrostHelloWorld.jl)
```


For more examples see the examples folder. 

# Workflow
To call a Julia function using MATFrost, the Julia function needs to satisfy some conditions. These conditions include fully typed input signatures and single method implementation (see later section for more info on these conditions). These conditions have been set to remove interface ambiguities but goes against the overall Julia vision of aiming for high extensibility. What this means in practice is that to be able to call Julia functions from MATLAB, very likely, a MATFrost Julia interface function needs to be created that wraps around Julia functionality. 

In this section we would like to give you a simple example of integrating Julia functionality.

1. Generate new Julia package/environment
   ```
   (@v1.10) pkg> generate MATFrostWorkflowExample
      Generating  project MATFrostWorkflowExample:
        MATFrostWorkflowExample/Project.toml
        MATFrostWorkflowExample/src/MATFrostWorkflowExample.jl
   ```
2. Edit `MATFrostWorkflowExample/src/MATFrostWorkflowExample.jl`
   ```julia
   module MATFrostWorkflowExample

   broadcast_multiply(c::Float64, v::Vector{Float64}) = c.*v

   end # module MATFrostWorkflowExample
   ```
3. Construct `matfrostjulia` object with `environment` set to the path to the newly created Julia environment `MATFrostWorkflowExample`.
   ```matlab
   mjl = matfrostjulia(...
      environment = <MATFrostWorkflowExample>);
   ```
4. Call `broadcast_multiply`
   ```matlab
   mjl.MATFrostWorkflowExample.broadcast_multiply(3.0, [1.0; 2.0; 3.0]) % [3.0; 6.0; 9.0]
   ``` 


# API

## Construct `matfrostjulia`
Constructing a `matfrostjulia` object will spawn a new process with Julia loaded. The constructor will need information such that it can find the Julia binaries and it will need the path to the Julia environment.

* Option 1 (recommended): Julia version to link to Julia binaries - requires Juliaup:
   ```matlab
   mjl = matfrostjulia(...
      environment = <environment_dir>, ... % Directory containing Julia environment.
      version = "1.10");                   % Julia version. (Accepted values are Juliaup channels)
   ```
* Option 2: Julia binary directory:
   ```matlab
   mjl = matfrostjulia(...
      environment = <environment_dir>, ... % Directory containing Julia environment.
      bindir = <bindir>);                  % Directory containing Julia binaries
   ```
* Option 3: Based on Julia configured in PATH
   ```matlab
   mjl = matfrostjulia(...              
      environment = <environment_dir>);    % Directory containing Julia environment.
   ```

### Option: Instantiate
An additional option instantiate will resolve project environment at construction of `matfrostjulia`. This will call `Pkg.instantiate()`. 

```matlab
mjl = matfrostjulia(...
   environment = <environment_dir>, ... 
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
mjl = matfrostjulia(...
    environment = matfrost_helloworld_environment());
    
hwjl = mjl.MATFrostHelloWorld; 

hwjl.matfrost_hello_world(); % 'Hello Julia! :)'
```

## Conditions Julia functions
To be able to call Julia functions through `matfrostjulia` it needs to satisfy some conditions.

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
cities      = struct("name", "Amsterdam", "population", int64(920));
cities(2,1) = struct("name", "Den Haag",  "population", int64(565));
cities(3,1) = struct("name", "Eindhoven", "population", int64(246));

country = struct("cities", cities, "area", 321.0)

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


