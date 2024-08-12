function environmentinstantiate(juliaexe, environment)
    arguments
        juliaexe    (1,1) string
        environment (1,1) string
    end

    env.JULIA_PROJECT = char(environment);
    env.PATH = fileparts(juliaexe);
    env.LD_LIBRARY_PATH = fullfile(fileparts(fileparts(juliaexe)), "lib");

    [status, ~] = shell(juliaexe, '-E', 'import Pkg; Pkg.instantiate()', echo=true, environmentVariables=env);
    assert(~status, "matfrostjulia:exe", "Could not instantiate environment: " + environment);

end
