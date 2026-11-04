module MATFrostDemographicsExt

using MATFrost
using Demographics

MATFrost.use_matfrost_handle(::Type{Demographics.Country}) = true

activate() = nothing

end