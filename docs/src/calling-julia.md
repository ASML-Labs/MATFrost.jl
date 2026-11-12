# Calling Julia

MATLAB calls a Julia function by writing its package and module path as dot
references, followed by parentheses:

```matlab
result = jl.PackageName.function_name(argument1, argument2);
```

This corresponds to calling `PackageName.function_name(argument1, argument2)`
from Julia. Nested modules can also be addressed through additional dot
references.

## Selecting a method

When a Julia function has multiple applicable methods, pass the desired Julia
argument types with the `signature` name-value argument:

```matlab
result = jl.PackageName.combine(value, signature="MyPackage.MyType");
```

For multiple arguments, use a string array in argument order:

```matlab
result = jl.PackageName.combine(left, right, ...
    signature=["MyPackage.Left", "MyPackage.Right"]);
```

Signature entries must match the Julia method's argument types. MATLAB values
are not automatically cast to the requested Julia type; for example, use
`int64(3)` when the Julia method expects `Int64`.