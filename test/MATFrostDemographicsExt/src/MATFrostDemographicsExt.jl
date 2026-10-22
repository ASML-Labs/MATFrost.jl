module MATFrostDemographicsExt

using Demographics
using MATFrost

export activate

activate() = nothing

MATFrost.use_matfrost_handle(::Type{Demographics.Country}) = true

end
