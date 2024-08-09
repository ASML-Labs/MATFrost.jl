function bindir = juliaup(version)
% Finds the julia bindir installed via juliaup
    arguments (Input)
        version (1,1) string
    end
    arguments (Output)
        bindir (1,1) string {mustBeFolder}
    end

    [status, out] = system("juliaup --version", "-echo");
    assert(~status, "matfrostjulia:juliaup", ...
        "Juliaup not found. Please install it from https://julialang.org/downloads/")
    disp(out)

    % Update is required to update loaded channels such that command line output is minimal
    % see https://github.com/JuliaLang/juliaup/issues/705
    system('juliaup update'); 

    % Check if Julia channel is installed
    [status, out]= system(sprintf('julia +%s -e "println(Base.VERSION)"', version), '-echo');
    disp(out)
    if status
        % Julia channel was not installed. Ask if the user wants to install Julia.
        
        if strcmp(getenv('GITHUB_ACTIONS'), 'true')
            answer = 'Yes';
        else
            answer = questdlg(sprintf("Julia %s was not installed. Do you want to install it?", version),...
	            "Julia was not installed", ...
	            "Yes", "No", "Yes");
        end
        switch answer
            case 'No'
                error("matfrostjulia:juliaup", "Julia channel has not been installed via juliaup. Please add via `juliaup add %s`", version);
            case 'Yes'
                status = system(sprintf("juliaup add %s", version), '-echo');
                assert(~status, "matfrostjulia:juliaup", ...
                    "Juliaup could not add channel: %s", version)
        end
    end

    % Get the bindir
    [status, output]= system(sprintf('julia +%s -e "println(Sys.BINDIR)"', version), '-echo');
    disp(output)
    assert(~status, "matfrostjulia:juliaup", ...
            "Julia could not execute in version %s configured by juliaup.", version)
    bindir = strtrim(output);
end
