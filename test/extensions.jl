using TOML

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
                `$(Base.julia_cmd()) --project=$package_dir -e "using Pkg; Pkg.test()"`,
            )
        end

        @testset "MATFrost Integration" begin
            if VERSION < v"1.11"
                @test_skip VERSION >= v"1.11"
                return
            end

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

if VERSION < v"1.11"
    @testset "Configure local sources" begin
        project_file = joinpath(@__DIR__, "environments", "MATFrostTest", "Project.toml")
        project = TOML.parsefile(project_file)
        for source in values(project["sources"])
            source["path"] = abspath(joinpath(dirname(project_file), source["path"]))
        end

        mktempdir() do environment
            open(joinpath(environment, "Project.toml"), "w") do output
                TOML.print(output, project)
            end

            configure_packages = joinpath(
                @__DIR__, "..", "src", "matlab", "@matfrostjulia", "configure_packages.jl",
            )
            @test success(pipeline(
                `$(Base.julia_cmd()) $configure_packages $environment`,
                stdout = stdout, stderr = stderr,
            ))
            @test success(pipeline(
                `$(Base.julia_cmd()) --project=$environment -e "using MATFrost, MATFrostTest"`,
                stdout = stdout, stderr = stderr,
            ))
        end
    end
end

test_extension("Demographics")