function bindir = juliaup(version)
% Finds the julia bindir installed via juliaup
    arguments (Input)
        version (1,1) string
    end
    arguments (Output)
        bindir (1,1) string {mustBeFolder}
    end

    [status, ~] = shell('juliaup', '--version');

    assert(~status, "matfrostjulia:juliaup", ...
        "Juliaup not found. Please install it from https://julialang.org/downloads/")
    
    % Check if Julia channel is installed
    [status, ~]= shell('julia', ['+' char(version)], '-e' , 'print(Base.VERSION)');
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
                status = shell('juliaup', 'add', version, echo=true);
                assert(~status, "matfrostjulia:juliaup", ...
                    "Juliaup could not add channel: %s", version)
        end
    else
        % Update is required to update loaded channels such that command line output is minimal
        % see https://github.com/JuliaLang/juliaup/issues/705
        shell('juliaup', 'update', echo=true); 
    end

    % Get the bindir
    [status, output] = shell('julia', ['+' char(version)], '-e',  'println(Sys.BINDIR)');
    assert(~status, "matfrostjulia:juliaup", ...
            "Julia could not execute in version %s configured by juliaup.", version)
    bindir = strtrim(output);
end
