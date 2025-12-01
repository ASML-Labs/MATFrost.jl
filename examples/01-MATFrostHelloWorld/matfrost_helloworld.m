
%% Install MATFrost environment
system('julia --project="./MATFrostHelloWorld.jl" -e "import Pkg ; Pkg.instantiate()"');
system('julia --project="./MATFrostHelloWorld.jl" -e "import MATFrost ; MATFrost.install()"');
% add the generated MATFrost package to MATLAB path
addpath(fullfile(pwd,"@matfrostjulia"));   
%% Build the MATFrost MEX interface
mjl = matfrostjulia(project=fullfile(pwd,"MATFrostHelloWorld.jl"));
%% Ex1: Hello World
mjl.matfrost_hello_world()
    % = "Hello Julia :)"
%% Ex2: matfrost_sum(v) = sum(v)
mjl.matfrost_sum((1:100)')
    % = 5050
%% Ex3: Polynomial multiplication
mjl.matfrost_polynomial_quadratic_multiplication( ...
    struct('c0', 1, 'c1', 2, 'c2', 3), ...
    struct('c0', 6, 'c1', 5, 'c2', 4)) 
    % = struct('c0', 6, 'c1', 17, 'c2', 32, 'c3', 23, 'c4', 12)
%% Ex4: Count population of a country.  
cities = [struct(name="Amsterdam", population=int64(920)); ...
          struct(name="Den Haag",  population=int64(565)); ...
          struct(name="Eindhoven", population=int64(246))];

country = struct(cities=cities, area=321.0);
mjl.Population.total_population(country) % 920+565+246 = 1731
%% Ex5: Multi-dispatch example
% Call with integers
result_int = mjl.matfrost_multi_dispatch("x::Int, y::Int",10, 20)
    % = 30
% Call with strings
result_str = mjl.matfrost_multi_dispatch("x::String, y::String","Hello ", "World")
    % = "Hello World"