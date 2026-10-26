function test_extension(environment)
    env = joinpath(@__DIR__, "environments", environment)
    package_dir = joinpath(env, environment)

    @testset "$environment Extension" begin

        @testset "Package" begin
            run(
                pipeline(
                    `$(Base.julia_cmd()) --project=$package_dir -e "using Pkg; Pkg.test()"`,
                    stdout=devnull,
                    stderr=devnull,
                ),
            )
        end

        @testset "MATFrost Integration" begin
            run(
                pipeline(
                    `$(Base.julia_cmd()) $(joinpath(@__DIR__, "configure_packages.jl")) $env`,
                    stdout=devnull,
                    stderr=devnull,
                ),
            )

            run(
                `$(Base.julia_cmd()) --project=$env $(joinpath(env, "runtest.jl"))`,
            )
        end
    end
end

test_extension("Demographics")  