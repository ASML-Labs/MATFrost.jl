using Test
using DataFrames
using Demographics

@testset "Demographics" begin

    country = Country("Netherlands", 33481.0)

    @test country.name == "Netherlands"
    @test area(country) == 33481.0
    @test isempty(country.cities)

    #
    # Add cities
    #

    add_city!(country, "Amsterdam", 934526)
    add_city!(country, "Rotterdam", 672960)

    @test has_city(country, "Amsterdam")
    @test has_city(country, "Rotterdam")
    @test !has_city(country, "Eindhoven")

    @test city_names(country) == ["Amsterdam", "Rotterdam"]

    #
    # Update city
    #

    update_city!(country, "Amsterdam", 950000)

    amsterdam = city_info(country, "Amsterdam")

    @test amsterdam.name == "Amsterdam"
    @test amsterdam.population == 950000

    #
    # Population
    #

    @test population(country) == 1622960

    #
    # Density
    #

    @test density(country) ≈ 1622960 / 33481.0

    #
    # Country info
    #

    info = country_info(country)

    @test info.name == "Netherlands"
    @test info.area == 33481.0
    @test info.population == 1622960
    @test info.density ≈ density(country)

    #
    # City info
    #

    cities = city_info(country)

    @test length(cities) == 2
    @test cities[1].name == "Amsterdam"
    @test cities[1].population == 950000
    @test cities[2].name == "Rotterdam"
    @test cities[2].population == 672960

    #
    # Remove city
    #

    remove_city!(country, "Rotterdam")

    @test !has_city(country, "Rotterdam")
    @test city_names(country) == ["Amsterdam"]

    #
    # Country dataframe
    #

    df = dataframe(country)

    @test df isa DataFrame
    @test names(df) == ["name", "population"]
    @test nrow(df) == 1
    @test df.name == ["Amsterdam"]
    @test df.population == [950000]

    #
    # City dataframe
    #

    city = City("Eindhoven", 246443)

    @test population(city) == 246443
    @test city_names(city) == ["Eindhoven"]

    city_df = dataframe(city)

    @test city_df isa DataFrame
    @test nrow(city_df) == 1
    @test city_df.name == ["Eindhoven"]
    @test city_df.population == [246443]

end