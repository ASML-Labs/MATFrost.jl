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

@testset "MATFrost._Server kwargs conversion" begin
    kwargs_marr = MATFrost._Types.MATFrostArrayStruct(
        Int64[1],
        Symbol[:digits, :base],
        MATFrost._Types.MATFrostArrayAbstract[
            MATFrost._Types.MATFrostArrayPrimitive{Int64}(Int64[1], Int64[3]),
            MATFrost._Types.MATFrostArrayPrimitive{Int64}(Int64[1], Int64[10]),
        ]
    )

    kwargs = MATFrost._Server.convert_callkwargs(kwargs_marr)
    @test kwargs == (digits = 3, base = 10)

    @test MATFrost._Server.convert_callkwargs(MATFrost._Types.MATFrostArrayEmpty()) == NamedTuple()

    scalar = MATFrost._Types.MATFrostArrayPrimitive{Float64}(Int64[1], Float64[2.5])
    @test MATFrost._Server.convert_untyped_matfrostarray(scalar) == 2.5

    vectorv = MATFrost._Types.MATFrostArrayPrimitive{Float64}(Int64[3], Float64[1.0, 2.0, 3.0])
    @test MATFrost._Server.convert_untyped_matfrostarray(vectorv) == [1.0, 2.0, 3.0]

    nested_kwargs_marr = MATFrost._Types.MATFrostArrayStruct(
        Int64[1],
        Symbol[:config],
        MATFrost._Types.MATFrostArrayAbstract[
            MATFrost._Types.MATFrostArrayStruct(
                Int64[1],
                Symbol[:enabled, :weights],
                MATFrost._Types.MATFrostArrayAbstract[
                    MATFrost._Types.MATFrostArrayPrimitive{Bool}(Int64[1], Bool[true]),
                    MATFrost._Types.MATFrostArrayPrimitive{Float64}(Int64[2], Float64[0.25, 0.75])
                ]
            )
        ]
    )
    nested_kwargs = MATFrost._Server.convert_callkwargs(nested_kwargs_marr)
    @test nested_kwargs == (config = (enabled = true, weights = [0.25, 0.75]),)

    invalid_payload = MATFrost._Types.MATFrostArrayPrimitive{Int64}(Int64[1], Int64[1])
    ex = nothing
    try
        MATFrost._Server.convert_callkwargs(invalid_payload)
    catch e
        ex = e
    end
    @test ex isa MATFrost._Types.MATFrostConversionException
    @test ex.id == "matfrostjulia:conversion:invalidKwargs"

    non_scalar_kwargs = MATFrost._Types.MATFrostArrayStruct(
        Int64[2],
        Symbol[:digits],
        MATFrost._Types.MATFrostArrayAbstract[
            MATFrost._Types.MATFrostArrayPrimitive{Int64}(Int64[1], Int64[2]),
            MATFrost._Types.MATFrostArrayPrimitive{Int64}(Int64[1], Int64[3])
        ]
    )
    ex = nothing
    try
        MATFrost._Server.convert_callkwargs(non_scalar_kwargs)
    catch e
        ex = e
    end
    @test ex isa MATFrost._Types.MATFrostConversionException
    @test ex.id == "matfrostjulia:conversion:invalidKwargs"
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
@testset "MATFrost._Server._load_and_eval_type" begin
    # Test 1: Load type from already-loaded package (no-op)
    result = MATFrost._Server._load_and_eval_type("Base.String")
    @test result == String

    # Test 2: Load type from MATFrost (fully qualified)
    result = MATFrost._Server._load_and_eval_type("MATFrost._Types.MATFrostArrayAbstract")
    @test result == MATFrost._Types.MATFrostArrayAbstract

    # Test 3: Simple type without package prefix
    result = MATFrost._Server._load_and_eval_type("Int")
    @test result == Int

    # Test 4: Generic types with nested braces
    result = MATFrost._Server._load_and_eval_type("Tuple{Int, String}")
    @test result == Tuple{Int, String}

    # Test 5: Nested type with non-leading package qualification
    result = MATFrost._Server._load_and_eval_type("Vector{MATFrost._Types.MATFrostArrayAbstract}")
    @test result == Vector{MATFrost._Types.MATFrostArrayAbstract}

    # Test 6: Non-existent package should throw
    callMeta = MATFrost._Server.CallMeta("MATFrost._ConvertToJulia.convert_matfrostarray", "NonExistentPkg.SomeType")
    @test_throws MATFrost._Types.MATFrostException MATFrost._Server.getMethod(callMeta)
end