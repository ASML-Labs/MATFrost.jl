
%% Install MATFrost environment

system('julia --project="./MATFrostHelloWorld.jl" -e "import Pkg ; Pkg.instantiate()"');

system('julia --project="./MATFrostHelloWorld.jl" -e "import MATFrost ; MATFrost.install()"');



%% Spawn a MATFrost process running JULIA
mjl = MATFrostHelloWorld(instantiate=true);

mjl = mjl.MATFrostHelloWorld;

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