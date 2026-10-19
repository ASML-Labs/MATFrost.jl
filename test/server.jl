using Test
using MATFrost

@testset "MATFrost._Server.CallMeta" begin
        name = "MATFrost._Convert.convert_matfrostarray"
        callMeta = MATFrost._Server.CallMeta(name)
        @test callMeta.fully_qualified_name == name
        @test callMeta.signature == String[]

        signature = "(:Type{String}, marr::MATFrost._Types.MATFrostArrayAbstract)"
        callMeta = MATFrost._Server.CallMeta(name,signature)
        @test callMeta.fully_qualified_name == name
        @test callMeta.signature == [signature]

end
@testset "MATFrost._Server.getMethod" begin
    # Test: function with one method
    callMeta = MATFrost._Server.CallMeta("MATFrost._Server.getMethod")
    (f,m) = MATFrost._Server.getMethod(callMeta)
    @test isa(f, Function)
    @test m == Tuple{MATFrost._Server.CallMeta}

    # Test: function with multiple methods should throw ambiguity error
    callMeta = MATFrost._Server.CallMeta("MATFrost._ConvertToJulia.convert_matfrostarray")
    @test_throws MATFrost._Types.MATFrostException MATFrost._Server.getMethod(callMeta)
    err = nothing
    try
        MATFrost._Server.getMethod(callMeta)
    catch e
        err = e
    end
    @test occursin("Ambiguous function call", err.message)
    @test err.id == "matfrostjulia:call:multipleMethodDefinitions"

    # Test: lower level function with many methods, specific signature
    callMeta = MATFrost._Server.CallMeta("MATFrost._ConvertToJulia.convert_matfrostarray",["Type{String}", "MATFrost._Types.MATFrostArrayAbstract"])
    (f,m) = MATFrost._Server.getMethod(callMeta)
    @test isa(f, Function)
    @test m==Tuple{Type{String}, MATFrost._Types.MATFrostArrayAbstract}

    # Test: signature with comma in type name
    callMeta = MATFrost._Server.CallMeta("MATFrost._ConvertToJulia.convert_matfrostarray","Type{String}, Tuple{Int, String}")
    (f,m) = MATFrost._Server.getMethod(callMeta)
    @test isa(f, Function)
    @test m==Tuple{Type{String}, Tuple{Int, String}}

    # Test: non-existing function should throw error
    callMeta = MATFrost._Server.CallMeta("MATFrost.nonExistentFunction")
    @test_throws MATFrost._Types.MATFrostException MATFrost._Server.getMethod(callMeta)
    try
        MATFrost._Server.getMethod(callMeta)
    catch e
        @test e.message == "Function not found exception:\nFunction MATFrost.nonExistentFunction \n"
        @test e.id == "matfrostjulia:call:functionNotFound"
    end
end
@testset "MATFrost._Server.qualified_roots" begin
    # Test 1: Already-available modules are never reported as packages to load
    @test MATFrost._Server.qualified_roots("Base.String") == Set{Symbol}()
    @test MATFrost._Server.qualified_roots("Core.Int64") == Set{Symbol}()
    @test MATFrost._Server.qualified_roots("Main.MyPkg.foo") == Set{Symbol}()

    # Test 2: Only the root of a qualified chain is reported
    @test MATFrost._Server.qualified_roots("MATFrost._Types.MATFrostArrayAbstract") == Set([:MATFrost])

    # Test 3: Unqualified names carry no package information
    @test MATFrost._Server.qualified_roots("Int") == Set{Symbol}()

    # Test 4: Generic types with nested braces
    @test MATFrost._Server.qualified_roots("Tuple{Int, String}") == Set{Symbol}()

    # Test 5: Nested type with non-leading package qualification
    @test MATFrost._Server.qualified_roots("Vector{MATFrost._Types.MATFrostArrayAbstract}") == Set([:MATFrost])

    # Test 6: Every root in a nested parametric type is collected
    @test MATFrost._Server.qualified_roots("Pkg1.T{Pkg2.U, Vector{Pkg3.V}}") == Set([:Pkg1, :Pkg2, :Pkg3])

    # Test 7: Roots in where clauses and spaced qualifications
    @test MATFrost._Server.qualified_roots("Vector{T} where T<:Pkg.Abs") == Set([:Pkg])
    @test MATFrost._Server.qualified_roots("Pkg . Type") == Set([:Pkg])

    # Test 8: Numeric literals never yield a root
    @test MATFrost._Server.qualified_roots("Tuple{Int, 1.0e3}") == Set{Symbol}()

    # Test 9: The roots argument accumulates across calls and is returned
    roots = Set{Symbol}()
    MATFrost._Server.qualified_roots("Pkg1.A", roots)
    MATFrost._Server.qualified_roots("Pkg2.B{Pkg3.C}", roots)
    @test roots == Set([:Pkg1, :Pkg2, :Pkg3])
    @test MATFrost._Server.qualified_roots("Pkg4.D", roots) === roots
    @test roots == Set([:Pkg1, :Pkg2, :Pkg3, :Pkg4])
end
@testset "MATFrost._Server.load_dependencies" begin
    # Test 1: Already-loaded packages in name and signature are a no-op
    callMeta = MATFrost._Server.CallMeta(
        "MATFrost._ConvertToJulia.convert_matfrostarray",
        ["Type{String}", "MATFrost._Types.MATFrostArrayAbstract"])
    @test MATFrost._Server.load_dependencies(callMeta) === nothing

    # Test 2: Non-existent package in the function name should throw
    callMeta = MATFrost._Server.CallMeta("NonExistentPkg.someFunction")
    @test_throws MATFrost._Types.MATFrostException MATFrost._Server.load_dependencies(callMeta)

    # Test 3: Non-existent package in the signature should throw
    callMeta = MATFrost._Server.CallMeta("MATFrost._ConvertToJulia.convert_matfrostarray", "NonExistentPkg.SomeType")
    @test_throws MATFrost._Types.MATFrostException MATFrost._Server.load_dependencies(callMeta)
    err = nothing
    try
        MATFrost._Server.load_dependencies(callMeta)
    catch e
        err = e
    end
    @test err.id == "matfrostjulia:call:packageNotFound"
    @test occursin("NonExistentPkg", err.message)
end