# Data Conversion

MATFrost supports concrete Julia values that can be represented by MATLAB.
Conversions are structural: a Julia struct or named tuple is normally
materialized as a MATLAB struct with corresponding fields.

## Scalars and arrays

| MATLAB value | Julia value |
| --- | --- |
| `1x1` numeric value | scalar |
| numeric column vector | `Vector` |
| numeric matrix | `Matrix` |
| higher-dimensional numeric array | `Array{T,N}` |
| MATLAB string | `String` |
| MATLAB cell array | `Tuple` or array of supported values |
| MATLAB struct | concrete Julia struct or named tuple |

MATLAB row vectors cannot be passed to Julia `Vector` arguments. Use a column
vector instead. Numeric values are not automatically cast to the requested
Julia type.

## Structs and named tuples

Every field in a converted Julia struct or named tuple must itself have a
supported, concrete type. For large mutable objects that should remain in Julia,
use [Julia Object Handles](@ref) instead of materializing their fields.