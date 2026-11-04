using Test
using Demographics

@testset "Demographics" begin
    country = Country("Netherlands", 33481.0)
    @test country.name == "Netherlands"
    @test isempty(country.cities)
    @test area(country) == 33481.0
    @test population(country) == 0
    @test density(country) == 0.0

    @test add_city!(country, "Amsterdam", Int64(934526)) === country
    @test add_city!(country, "Rotterdam", Int64(672960)) === country
    @test has_city(country, "Amsterdam")
    @test !has_city(country, "Eindhoven")
    @test city_names(country) == ["Amsterdam", "Rotterdam"]
    @test population(country) == 1607486
    @test density(country) == 1607486 / 33481.0

    info = country_info(country)
    @test info.name == "Netherlands"
    @test info.area == 33481.0
    @test info.population == 1607486
    @test info.density == density(country)
    @test city_info(country) == [
        (name = "Amsterdam", population = Int64(934526)),
        (name = "Rotterdam", population = Int64(672960)),
    ]

    @test update_city!(country, "Amsterdam", Int64(950000)) === country
    @test city_info(country, "Amsterdam").population == 950000
    @test population(country) == 1622960
    @test remove_city!(country, "Rotterdam") === country
    @test !has_city(country, "Rotterdam")
    @test city_names(country) == ["Amsterdam"]
    @test population(country) == 950000

    city = City("Eindhoven", 246443)
    @test population(city) == 246443
    @test city_names(city) == ["Eindhoven"]
    @test city_info(city) == (name = "Eindhoven", population = Int64(246443))
end