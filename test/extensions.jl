using Test

function test_extension(environment::AbstractString)
    env = joinpath(@__DIR__, "environments", environment)
    package_dir = joinpath(env, environment)
    configure_packages = joinpath(
        @__DIR__, "..", "src", "matlab", "@matfrostjulia", "configure_packages.jl",
    )

    @testset "$environment package" begin
        @test success(pipeline(
            `$(Base.julia_cmd()) --startup-file=no --project=$package_dir -e "using Pkg; Pkg.test()"`,
            stdout = stdout, stderr = stderr,
        ))
    end

    @testset "$environment integration" begin
        @test success(pipeline(
            `$(Base.julia_cmd()) --startup-file=no $configure_packages $env`,
            stdout = stdout, stderr = stderr,
        ))
        @test success(pipeline(
            `$(Base.julia_cmd()) --startup-file=no --project=$env $(joinpath(env, "runtests.jl"))`,
            stdout = stdout, stderr = stderr,
        ))
    end
end

test_extension("Demographics")