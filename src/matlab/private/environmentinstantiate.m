function environmentinstantiate(bindir, environment)
    arguments
        bindir      (1,1) string
        environment (1,1) string
    end
    if ispc
        julia_exe = "julia.exe";
    else
        julia_exe = "julia";
    end

    [status, output] = system(fullfile(bindir, julia_exe) + " --project=""" + environment + """  -e ""import Pkg; Pkg.instantiate()""");

    assert(~status, "matfrostjulia:exe", "Could not instantiate environment: " + environment);

end