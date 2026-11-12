# Julia Object Handles

By default, MATFrost converts a Julia struct's fields to a MATLAB struct. For a
large or mutable object, an integration package can opt its type into handle
conversion. MATLAB then receives a small struct containing `dataType`, `id`,
and `typename`; the original object stays in the Julia server process.

```julia
module Simulation

import MATFrost

mutable struct Counter
    value::Int64
end

MATFrost.use_matfrost_handle(::Type{Counter}) = true
new_counter(value::Int64) = Counter(value)

function increment!(counter::Counter, amount::Int64)
    counter.value += amount
    return counter.value
end

end
```

From MATLAB, calls can pass the returned handle back to Julia:

```matlab
counter = jl.Simulation.new_counter(int64(10), signature="Int64");
value = jl.Simulation.("increment!")(counter, int64(5), ...
    signature=[counter.typename, "Int64"]); % 15

released = jl.MATFrost.release_handle( ...
    counter, signature="MATFrost.MATFrostHandle");
```

Copies of the MATLAB handle struct refer to the same Julia object, so mutations
remain visible through every copy. The handle is scoped to the Julia server
process that created it. Clearing a MATLAB variable does not release the stored
object; call `release_handle` or `release_all_handles!` when it is no longer
needed. Using a released handle raises an error.

Opt-in methods are commonly defined by a package integration module that imports
both the domain package and MATFrost. This keeps domain packages independent of
MATFrost.