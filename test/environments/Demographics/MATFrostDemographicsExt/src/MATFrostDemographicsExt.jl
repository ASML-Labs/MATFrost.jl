module MATFrostDemographicsExt

using MATFrost
using Demographics

export activate

activate() = nothing

MATFrost.use_matfrost_handle(::Type{Demographics.Country}) = true
is_country_handle() = MATFrost.use_matfrost_handle(Demographics.Country)

include("dataframe.jl")

end