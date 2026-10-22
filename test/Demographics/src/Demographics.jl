module Demographics

using DataFrames

export City,
       Country,
       add_city!,
       remove_city!,
       has_city,
       update_city!,
       population,
       area,
       density,
       city_names,
       city_info,
       country_info,
       dataframe

mutable struct City
    name::String
    population::Int64
end

mutable struct Country
    name::String
    cities::Vector{City}
    area::Float64
end

#
# Constructors
#

Country(name::String, area::Float64) =
    Country(name, City[], area)

#
# Mutating operations
#

function add_city!(country::Country, name::String, population::Integer)
    push!(country.cities, City(name, Int64(population)))
    return country
end

function remove_city!(country::Country, name::String)
    filter!(city -> city.name != name, country.cities)
    return country
end

city_info(country::Country, name::String) =
    first(filter(city -> city.name == name, country.cities))

function has_city(country::Country, name::String)
    any(city -> city.name == name, country.cities)
end

function update_city!(country::Country, name::String, population::Integer)
    city = city_info(country, name)
    city.population = Int64(population)
    return country
end

#
# Population
#

population(city::City) =
    city.population

population(country::Country) =
    sum(population, country.cities)

total_population(country::Country) =
    population(country)

#
# Area
#

area(country::Country) =
    country.area

#
# Density
#

density(country::Country) =
    population(country) / area(country)

#
# Names
#

city_names(city::City) =
    [city.name]

city_names(country::Country) =
    [city.name for city in country.cities]

#
# Information
#

city_info(city::City) =
    (
        name = city.name,
        population = city.population,
    )

city_info(country::Country) =
    city_info.(country.cities)

country_info(country::Country) =
    (
        name = country.name,
        area = country.area,
        population = total_population(country),
        density = density(country),
    )

#
# DataFrame conversion
#

function dataframe(city::City)
    DataFrame(
        name = [city.name],
        population = [city.population],
    )
end

function dataframe(country::Country)
    df = DataFrame(
        name = String[],
        population = Int64[],
    )

    for city in country.cities
        append!(df, dataframe(city))
    end

    return df
end

end