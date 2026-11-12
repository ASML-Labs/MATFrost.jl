# Demographics Handle Demonstration

This fixture demonstrates a mutable domain object that remains in Julia while
MATLAB operates on it through a MATFrost handle. The Demographics package has no
dependency on MATFrost. MATFrostDemographicsExt is a separate integration package
that opts Country into handle conversion when loaded.

Configure the environment from the repository root:

```julia
include("src/matlab/@matfrostjulia/configure_packages.jl")
ConfigurePackages.configure_packages("test/environments/Demographics")
```

```matlab
jl = matfrostjulia(project="<repository>/test/environments/Demographics");
jl.MATFrostDemographicsExt.activate();

country = jl.Demographics.Country( ...
    "Netherlands", 33481.0, signature=["String", "Float64"]);
jl.Demographics.("add_city!")( ...
    country, "Amsterdam", int64(934526), ...
    signature=[country.typename, "String", "Int64"]);
population = jl.Demographics.population(country, signature=country.typename);

info = jl.Demographics.country_info(country, signature=country.typename);
jl.MATFrost.("release_all_handles!")();
```

Country mutations act on the original Julia object. Scalar results and explicit
country-info snapshots are materialized in MATLAB through normal conversion.
Mutating functions return the Country and may create additional handles to it;
release all handles after the workflow completes.

The integration uses an ordinary Julia module, not native package extensions,
and is tested on Julia 1.7 and 1.13. No Geometry, DataFrames, or table conversion
is included in this fixture.