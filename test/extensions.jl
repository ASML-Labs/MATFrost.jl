function test_extension(environment)
    env = joinpath(@__DIR__, "environments", environment)
    package_dir = joinpath(env, environment)

    configure_packages = joinpath(
        @__DIR__,
        "..",
        "src",
        "matlab",
        "@matfrostjulia",
        "configure_packages.jl",
    )

    @testset "$environment Extension" begin
        @testset "Package" begin
            run(
                pipeline(
                    `$(Base.julia_cmd()) --project=$package_dir -e "using Pkg; Pkg.test()"`,
                    stdout = devnull,
                    stderr = devnull,
                ),
            )
        end

        @testset "MATFrost Integration" begin
            cmd = `$(Base.julia_cmd()) $configure_packages $env`

            try
                run(pipeline(cmd, stdout=devnull, stderr=devnull))
            catch
                @info "configure_packages failed, rerunning with output"
                run(cmd)
                rethrow()
            end

            run(
                `$(Base.julia_cmd()) --project=$env $(joinpath(env, "runtests.jl"))`,
            )
        end
    end
end

test_extension("Demographics")