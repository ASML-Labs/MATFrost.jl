module MATFrostTest



elementwise_addition_f64(c::Float64, x::Vector{Float64}) = c .+ x

kron_product_matrix_f64(A::Matrix{Float64}, B::Matrix{Float64}) = kron(A, B)

sum_vector_of_vector_f64(vs::Vector{Vector{Float64}}) = sum(sum(v) for v in vs)


struct SimplePopulationType
    name::String
    population::Int64
end

largest_population(p1::SimplePopulationType, p2::SimplePopulationType) = ifelse(p1.population > p2.population, p1, p2)

largest_population_vector(ps::Vector{SimplePopulationType}) = last(sort(ps, lt=(p1, p2)-> p1.population < p2.population))


struct Nest1
    v1::Float64
    v2::Int64
    v3::Tuple{Float64, Int64, Int32}
    v4::Bool
end

sum_nest1(v::Nest1) = v.v1 + v.v2 + v.v3[1]+v.v3[2]+v.v3[3]

nest1_identity(v::Nest1) = v

struct Nest2
    v1::Tuple{Nest1, Nest1, Nest1}
    vs::Vector{Nest1}
end

sum_nest2(v::Nest2) = sum(sum_nest1(e) for e in v.v1) + sum(sum_nest1(e) for e in v.vs)

nest2_identity(v::Nest2) = v

struct Rename1Old
    old_v  :: Nest1
    old_vs :: Vector{Nest1}
end

struct Rename1New
    action :: String
    new_v  :: Nest1
    new_vs :: Vector{Nest1}
end



rename_test1(v::Rename1Old) = Rename1New("Renamed", v.old_v, v.old_vs)


struct AbstractType1
    v1::Float64
    v2::Any
end


matfrost_abstract_test1(v1::Float64, v2::Int64) = AbstractType1(v1, v2)



matfrost_xor(b1::Bool, b2::Bool) = xor(b1, b2)

matfrost_elementwise_xor(v1::Vector{Bool}, v2::Vector{Bool}) = Vector{Bool}(xor.(v1, v2))


repeat_string(s::String, num::Int64) = reduce(*, (s for _ in 1:num))

concat_strings(s::Vector{String}) = reduce(*, s)


double_scalar_f32(v::Float32) = v+v
double_scalar_f64(v::Float64) = v+v

double_scalar_i8(v::Int8) = v+v
double_scalar_i16(v::Int16) = v+v
double_scalar_i32(v::Int32) = v+v
double_scalar_i64(v::Int64) = v+v


double_scalar_ui8(v::UInt8) = v+v
double_scalar_ui16(v::UInt16) = v+v
double_scalar_ui32(v::UInt32) = v+v
double_scalar_ui64(v::UInt64) = v+v


double_scalar_cf32(v::Complex{Float32}) = v+v
double_scalar_cf64(v::Complex{Float64}) = v+v

double_scalar_ci8(v::Complex{Int8})   = v+v
double_scalar_ci16(v::Complex{Int16}) = v+v
double_scalar_ci32(v::Complex{Int32}) = v+v
double_scalar_ci64(v::Complex{Int64}) = v+v

double_scalar_cui8(v::Complex{UInt8})   = v+v
double_scalar_cui16(v::Complex{UInt16}) = v+v
double_scalar_cui32(v::Complex{UInt32}) = v+v
double_scalar_cui64(v::Complex{UInt64}) = v+v

logical_f64_multiplication(b::Bool, v::Float64) = b * v



double_vector_f32(v::Vector{Float32}) = v .+ v
double_vector_f64(v::Vector{Float64}) = v .+ v

double_vector_i8(v::Vector{Int8})   = v .+ v
double_vector_i16(v::Vector{Int16}) = v .+ v
double_vector_i32(v::Vector{Int32}) = v .+ v
double_vector_i64(v::Vector{Int64}) = v .+ v

double_vector_ui8(v::Vector{UInt8})   = v .+ v
double_vector_ui16(v::Vector{UInt16}) = v .+ v
double_vector_ui32(v::Vector{UInt32}) = v .+ v
double_vector_ui64(v::Vector{UInt64}) = v .+ v



double_vector_cf32(v::Vector{Complex{Float32}}) = v .+ v
double_vector_cf64(v::Vector{Complex{Float64}}) = v .+ v

double_vector_ci8(v::Vector{Complex{Int8}})     = v .+ v
double_vector_ci16(v::Vector{Complex{Int16}})   = v .+ v
double_vector_ci32(v::Vector{Complex{Int32}})   = v .+ v
double_vector_ci64(v::Vector{Complex{Int64}})   = v .+ v

double_vector_cui8(v::Vector{Complex{UInt8}})   = v .+ v
double_vector_cui16(v::Vector{Complex{UInt16}}) = v .+ v
double_vector_cui32(v::Vector{Complex{UInt32}}) = v .+ v
double_vector_cui64(v::Vector{Complex{UInt64}}) = v .+ v




sum_vector_cf64(v::Vector{Complex{Float64}}) = sum(v)




multiplication_scalar_f32(v1::Float32, v2::Float32) = v1*v2
multiplication_scalar_f64(v1::Float64, v2::Float64) = v1*v2

multiplication_scalar_i8(v1::Int8, v2::Int8) = v1*v2
multiplication_scalar_i16(v1::Int16, v2::Int16) = v1*v2
multiplication_scalar_i32(v1::Int32, v2::Int32) = v1*v2
multiplication_scalar_i64(v1::Int64, v2::Int64) = v1*v2


multiplication_scalar_ui8(v1::UInt8, v2::UInt8) = v1*v2
multiplication_scalar_ui16(v1::UInt16, v2::UInt16) = v1*v2
multiplication_scalar_ui32(v1::UInt32, v2::UInt32) = v1*v2
multiplication_scalar_ui64(v1::UInt64, v2::UInt64) = v1*v2


multiplication_scalar_cf32(v1::Complex{Float32}, v2::Complex{Float32}) = v1*v2
multiplication_scalar_cf64(v1::Complex{Float64}, v2::Complex{Float64}) = v1*v2

multiplication_scalar_ci8(v1::Complex{Int8}, v2::Complex{Int8})   = v1*v2
multiplication_scalar_ci16(v1::Complex{Int16}, v2::Complex{Int16}) = v1*v2
multiplication_scalar_ci32(v1::Complex{Int32}, v2::Complex{Int32}) = v1*v2
multiplication_scalar_ci64(v1::Complex{Int64}, v2::Complex{Int64}) = v1*v2

multiplication_scalar_cui8(v1::Complex{UInt8}, v2::Complex{UInt8})   = v1*v2
multiplication_scalar_cui16(v1::Complex{UInt16}, v2::Complex{UInt16}) = v1*v2
multiplication_scalar_cui32(v1::Complex{UInt32}, v2::Complex{UInt32}) = v1*v2
multiplication_scalar_cui64(v1::Complex{UInt64}, v2::Complex{UInt64}) = v1*v2






identity_simple_population_type(v::SimplePopulationType) = v

identity_string(v::String) = v

identity_f32(v::Float32) = v
identity_f64(v::Float64) = v

identity_i8(v::Int8) = v
identity_i16(v::Int16) = v
identity_i32(v::Int32) = v
identity_i64(v::Int64) = v

identity_ui8(v::UInt8) = v
identity_ui16(v::UInt16) = v
identity_ui32(v::UInt32) = v
identity_ui64(v::UInt64) = v


identity_cf32(v::Complex{Float32}) = v
identity_cf64(v::Complex{Float64}) = v

identity_ci8(v::Complex{Int8}) = v
identity_ci16(v::Complex{Int16}) = v
identity_ci32(v::Complex{Int32}) = v
identity_ci64(v::Complex{Int64}) = v

identity_cui8(v::Complex{UInt8}) = v
identity_cui16(v::Complex{UInt16}) = v
identity_cui32(v::Complex{UInt32}) = v
identity_cui64(v::Complex{UInt64}) = v



# identity_ui8(v::Float64) = v
# identity_f64(v::Float64) = v
# identity_f64(v::Float64) = v
# identity_f64(v::Float64) = v
# identity_f64(v::Float64) = v






end # module MATFrostTest
