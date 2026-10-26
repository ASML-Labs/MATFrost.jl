# test/extensions.jl

function test_extension(environment)
    env = joinpath(@__DIR__, "environments", environment)

    @testset "$environment Extension" begin
        run(`$(Base.julia_cmd()) $(joinpath(@__DIR__, "configure_packages.jl")) $env`)
        @test isfile(joinpath(env, "Manifest.toml"))
        run(`$(Base.julia_cmd()) --project=$env $(joinpath(env, "runtest.jl"))`)
    end
end

test_extension("Demographics")