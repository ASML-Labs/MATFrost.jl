classdef matfrost_abstract_test < matlab.unittest.TestCase
    
    properties 
        environment (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'MATFrostTest');
    end

    properties (ClassSetupParameter)
        julia_version = get_julia_version()
    end    
    
    properties
        mjl matfrostjulia
    end

    methods(TestClassSetup)
        function setup_matfrost(tc, julia_version)

           tc.mjl = matfrostjulia(...
                environment = tc.environment, ...
                version     = julia_version, ...
                instantiate = false);
            
            matfpath = strrep(fileparts(fileparts(mfilename('fullpath'))), "\", "\\");
            system(sprintf('julia -E "import Pkg ; Pkg.develop(path=\\"%s\\") ; Pkg.instantiate()"', matfpath), ...
                "JULIA_PROJECT",   tc.mjl.environment, ...
                "PATH",            fileparts(tc.mjl.julia), ... 
                "LD_LIBRARY_PATH", fullfile(fileparts(fileparts(tc.mjl.julia)), "lib"));

        end
    end
end

function version = get_julia_version()
    if strcmp(getenv('GITHUB_ACTIONS'), 'true')
        version = { getenv('JULIA_VERSION') };
    else
        version = {'1.7', '1.8', '1.9', '1.10'};
    end
end
