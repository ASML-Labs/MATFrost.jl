module MATFrostHelloWorld

matfrost_hello_world() = "Hello Julia :)"

matfrost_sum(v::Vector{Float64}) = sum(v)

struct PolynomialQuadratic
  c0 :: Float64
  c1 :: Float64
  c2 :: Float64
end

struct PolynomialQuartic
  c0 :: Float64
  c1 :: Float64
  c2 :: Float64
  c3 :: Float64
  c4 :: Float64
end

matfrost_polynomial_quadratic_multiplication(p1::PolynomialQuadratic, p2::PolynomialQuadratic) =  PolynomialQuartic(
    p1.c0 * p2.c0, 
    p1.c0 * p2.c1 + p1.c1 * p2.c0, 
    p1.c0 * p2.c2 + p1.c1 * p2.c1 + p1.c2 * p2.c0, 
    p1.c1 * p2.c2 + p1.c2 * p2.c1, 
    p1.c2 * p2.c2
)


struct City
   name::String
   population::Int64
end

struct Country
   cities::Vector{City}
   area::Float64
end

total_population(country::Country) = sum((city.population for city in country.cities))

function matfrost_multi_dispatch(x::Int, y::Int)
    return x + y
end

function matfrost_multi_dispatch(x::String, y::String)
    return string(x, y)
end


end # module MATFrostHelloWorld
