module Demographics

export City, Country, add_city!, remove_city!, has_city, update_city!,
    population, area, density, city_names, city_info, country_info

mutable struct City
    name::String
    population::Int64
end

mutable struct Country
    name::String
    cities::Vector{City}
    area::Float64
end

Country(name::String, area::Float64) = Country(name, City[], area)

function add_city!(country::Country, name::String, population::Int64)
    push!(country.cities, City(name, population))
    return country
end

function remove_city!(country::Country, name::String)
    filter!(city -> city.name != name, country.cities)
    return country
end

city_info(country::Country, name::String) =
    first(filter(city -> city.name == name, country.cities))

has_city(country::Country, name::String) = any(city -> city.name == name, country.cities)

function update_city!(country::Country, name::String, population::Int64)
    city_info(country, name).population = population
    return country
end

population(city::City) = city.population
population(country::Country) = sum((city.population for city in country.cities); init = Int64(0))
area(country::Country) = country.area
density(country::Country) = population(country) / area(country)
city_names(city::City) = [city.name]
city_names(country::Country) = [city.name for city in country.cities]
city_info(city::City) = (name = city.name, population = city.population)
city_info(country::Country) = city_info.(country.cities)

country_info(country::Country) = (
    name = country.name,
    area = country.area,
    population = population(country),
    density = density(country),
)

end