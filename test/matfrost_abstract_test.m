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
                instantiate = true);
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
