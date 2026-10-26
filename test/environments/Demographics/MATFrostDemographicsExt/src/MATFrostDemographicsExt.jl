module MATFrostDemographicsExt

using MATFrost
using Demographics

export activate

activate() = nothing

MATFrost.use_matfrost_handle(::Type{Demographics.Country}) = true

include("dataframe.jl")

end