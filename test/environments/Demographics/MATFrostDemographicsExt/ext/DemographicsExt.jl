module DemographicsExt

using Demographics
using MATFrost

MATFrost.use_matfrost_handle(::Type{Demographics.Country}) = true

end