"""
This module exposes C-functions to be used in the MEX-layer.
"""
module MEX

using ..MATFrost: _MATFrostArray as MATFrostArray
using .._JuliaCall: juliacall
using .._JuliaCall: freematfrostmemory

juliacall_c()          = @cfunction(juliacall, MATFrostArray, (MATFrostArray,))
freematfrostmemory_c() = @cfunction(freematfrostmemory, Cvoid, (MATFrostArray,))

end
