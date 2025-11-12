module ServerTest

using Test
using JET

using MATFrost._Server: CallMeta, MATFrostResultMATLAB, package_is_loaded, getfunction, matfrostinputconversionexception, matfrostexceptionresult
using MATFrost._Types
using MATFrost._Constants

# Define a test function with only one method for testing getfunction
test_single_method(x::Float64) = x * 2.0

@testset "Server-CallMeta" begin

    @testset "CallMeta-Constructor" begin
        meta = CallMeta("Example.hello_world")
        @test meta.fully_qualified_name == "Example.hello_world"
    end

    @testset "CallMeta-With-Nested-Path" begin
        meta = CallMeta("Package.Module.Function")
        @test meta.fully_qualified_name == "Package.Module.Function"
    end
end


@testset "Server-MATFrostResultMATLAB" begin

    @testset "ResultMATLAB-Successful" begin
        result = MATFrostResultMATLAB{Float64}("SUCCESFUL", "", 42.0)
        @test result.status == "SUCCESFUL"
        @test result.log == ""
        @test result.value == 42.0
    end

    @testset "ResultMATLAB-Error" begin
        exc = MATFrostException("test:error", "Test error message")
        result = MATFrostResultMATLAB{MATFrostException}("ERROR", "", exc)
        @test result.status == "ERROR"
        @test result.value isa MATFrostException
    end
end


@testset "Server-PackageIsLoaded" begin

    @testset "PackageIsLoaded-Base" begin
        # Base is always loaded
        @test package_is_loaded(:Base) == true
    end

    @testset "PackageIsLoaded-Core" begin
        # Core is always loaded
        @test package_is_loaded(:Core) == true
    end

    @testset "PackageIsLoaded-Test" begin
        # Test package behavior depends on the test runner:
        # - Pkg.test() keeps Test isolated from Main
        # - TestReports.test() loads Test into Main
        # Both are valid, so we just test that the function works
        @test isa(package_is_loaded(:Test), Bool)
    end

    @testset "PackageIsLoaded-Nonexistent" begin
        # This package should not exist
        @test package_is_loaded(:NonexistentPackage12345) == false
    end
end


@testset "Server-GetFunction" begin

    @testset "GetFunction-Simple" begin
        # Test with a single-method function
        meta = CallMeta("ServerTest.test_single_method")
        f = getfunction(meta)
        @test f === test_single_method
    end

    @testset "GetFunction-Nested" begin
        # Base.sqrt has multiple methods, so it should throw an exception
        meta = CallMeta("Base.sqrt")
        @test_throws MATFrostException getfunction(meta)
    end

    @testset "GetFunction-Invalid-Short-Path" begin
        # Path must have at least package.function
        meta = CallMeta("sqrt")
        @test_throws MATFrostException getfunction(meta)
    end

    @testset "GetFunction-Nonexistent-Function" begin
        # Function doesn't exist
        meta = CallMeta("Base.nonexistent_function_xyz")
        @test_throws MATFrostException getfunction(meta)
    end

    @testset "GetFunction-Exception-Message" begin
        meta = CallMeta("Base.nonexistent_function_xyz")
        try
            getfunction(meta)
            @test false  # Should not reach here
        catch e
            @test e isa MATFrostException
            @test e.id == "matfrostjulia:call:functionNotFound"
            @test occursin("Base.nonexistent_function_xyz", e.message)
        end
    end
end


@testset "Server-InputConversionException" begin

    @testset "InputConversionException-Simple" begin
        original = MATFrostConversionException(
            "matfrostjulia:conversion:incompatibleDatatypes",
            "Test error message",
            Any[]
        )

        result = matfrostinputconversionexception(original)

        @test result isa MATFrostException
        @test result.id == "matfrostjulia:conversion:incompatibleDatatypes"
        @test occursin("Test error message", result.message)
    end

    @testset "InputConversionException-WithStacktrace" begin
        original = MATFrostConversionException(
            "matfrostjulia:conversion:incompatibleDatatypes",
            "Test error message",
            Any[1, :field1, 2]
        )

        result = matfrostinputconversionexception(original)

        @test result isa MATFrostException
        # The stacktrace should be reversed and formatted
        @test occursin("Input invalid at:", result.message)
        @test occursin("[2]", result.message)
        @test occursin(".field1", result.message)
        @test occursin("[1]", result.message)
    end

    @testset "InputConversionException-SymbolTrace" begin
        original = MATFrostConversionException(
            "matfrostjulia:conversion:missingFields",
            "Missing field error",
            Any[:x, :nested]
        )

        result = matfrostinputconversionexception(original)

        @test occursin(".nested", result.message)
        @test occursin(".x", result.message)
    end
end


@testset "Server-ExceptionResult" begin

    @testset "ExceptionResult-MATFrostException" begin
        exc = MATFrostException("test:error", "Test error message")
        result = matfrostexceptionresult(exc)

        @test result isa MATFrostResultMATLAB
        @test result.status == "ERROR"
        @test result.log == ""
        @test result.value === exc
    end

    @testset "ExceptionResult-GenericException" begin
        exc = ErrorException("Generic error")
        result = matfrostexceptionresult(exc)

        @test result isa MATFrostResultMATLAB
        @test result.status == "ERROR"
        @test result.value === exc
    end
end


@testset "Server-EdgeCases" begin

    @testset "CallMeta-Empty-String" begin
        meta = CallMeta("")
        @test meta.fully_qualified_name == ""
    end

    @testset "CallMeta-Single-Dot" begin
        meta = CallMeta(".")
        @test meta.fully_qualified_name == "."
    end

    @testset "CallMeta-Many-Dots" begin
        meta = CallMeta("A.B.C.D.E.F")
        @test meta.fully_qualified_name == "A.B.C.D.E.F"
    end
end

end
