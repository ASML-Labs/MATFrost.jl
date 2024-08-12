function environmentinstantiate(juliaexe, environment)
    arguments
        juliaexe    (1,1) string
        environment (1,1) string
    end

    [status, ~] = shell(juliaexe, ['--project="', char(environment), '"'], '-e', 'import Pkg; Pkg.instantiate()', echo=true);
    assert(~status, "matfrostjulia:exe", "Could not instantiate environment: " + environment);

end