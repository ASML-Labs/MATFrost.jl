function environmentinstantiate(juliaexe, environment)
    arguments
        juliaexe    (1,1) string
        environment (1,1) string
    end

    [status, output] = shell(juliaexe, ['--project="', char(environment), '"'], '-e', '"import Pkg; Pkg.instantiate()"');

    assert(~status, "matfrostjulia:exe", "Could not instantiate environment: " + environment);

end