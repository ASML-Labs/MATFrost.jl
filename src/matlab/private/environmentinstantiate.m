function environmentinstantiate(juliaexe, environment)
    arguments
        juliaexe    (1,1) string
        environment (1,1) string
    end

    [status, output] = system(juliaexe + " --project=""" + environment + """  -e ""import Pkg; Pkg.instantiate()""");
    disp(output);
    assert(~status, "matfrostjulia:exe", "Could not instantiate environment: " + environment);

end