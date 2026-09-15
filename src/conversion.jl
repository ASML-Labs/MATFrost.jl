"""
    convert_from_matlab(value)

Extension point for converting a value received from MATLAB into the Julia
representation expected by the called method.

The fallback returns `value` unchanged. Integration packages can extend this
function for their own types without adding those dependencies to MATFrost.
Conversion is intentionally implemented through Julia multiple dispatch.
"""
convert_from_matlab(value) = value

"""
    convert_to_matlab(value)

Extension point for converting a Julia return value into a representation that
MATFrost can transport to MATLAB.

The fallback returns `value` unchanged. Integration packages can extend this
function for their own types without adding those dependencies to MATFrost.
"""
convert_to_matlab(value) = value
