using Test
using MATFrostTest

@testset "basic function calls" begin
    # Test elementwise_addition_f64
    @test MATFrostTest.elementwise_addition_f64(2.0, [1.0, 2.0, 3.0]) == [3.0, 4.0, 5.0]

    # Test kron_product_matrix_f64
    A = [1.0 2.0; 3.0 4.0]
    B = [0.0 5.0; 6.0 7.0]
    kronAB = MATFrostTest.kron_product_matrix_f64(A, B)
    @test size(kronAB) == (4, 4)

    # Test sum_vector_of_vector_f64
    vs = [[1.0, 2.0], [3.0], [4.0, 5.0]]
    @test MATFrostTest.sum_vector_of_vector_f64(vs) == 15.0

    # Test sum_composite_number_type
    cnt = MATFrostTest.CompositeNumberType(1, Int32(2), UInt8(3))
    @test MATFrostTest.sum_composite_number_type(cnt) == 6

    # Test largest_population
    p1 = MATFrostTest.SimplePopulationType("A", 100)
    p2 = MATFrostTest.SimplePopulationType("B", 200)
    @test MATFrostTest.largest_population(p1, p2) == p2

    # Test double_scalar_f64
    @test MATFrostTest.double_scalar_f64(3.0) == 6.0

    # Test double_vector_i32
    v = Int32[1, 2, 3]
    @test MATFrostTest.double_vector_i32(v) == Int32[2, 4, 6]

    # Test repeat_string
    @test MATFrostTest.repeat_string("ab", 3) == "ababab"

    # Test concat_strings
    @test MATFrostTest.concat_strings(["a", "b", "c"]) == "abc"

    # Test logical_f64_multiplication
    @test MATFrostTest.logical_f64_multiplication(true, 2.5) == 2.5
    @test MATFrostTest.logical_f64_multiplication(false, 2.5) == 0.0

   end

@testset "Multi-Dispatch Tests" begin
    # Test multiple_method_definitions
    @test MATFrostTest.multiple_method_definitions(2.0) == 4.0
    @test MATFrostTest.multiple_method_definitions(Int64(3)) == 5
    @test MATFrostTest.multiple_method_definitions("foo", 7) == "foo_7"
    # Test compute_measure multi-dispatch
    p = MATFrostTest.SimplePopulationType("C", 150)
    cnt = MATFrostTest.CompositeNumberType(4, Int32(5), UInt8(6))
    @test MATFrostTest.compute_measure(p) == 150.0  
    @test MATFrostTest.compute_measure(cnt) == 15.0
end

@testset "Base.+ for Point" begin
    p1 = MATFrostTest.Point(1, 2)
    p2 = MATFrostTest.Point(3, 4)
    res = Base.:+(p1, p2)
    @test res == MATFrostTest.Point(4, 6)
    @test typeof(res) == MATFrostTest.Point
end
