classdef matfrost_abstract_test < matlab.unittest.TestCase
    
    properties 
        environment (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'MATFrostTest');
    end

    properties (ClassSetupParameter)
        julia_version = get_julia_version();
    end    
    
    properties
        mjl
    end

    methods(TestClassSetup)
        function setup_matfrost(tc, julia_version)
            matfpath = strrep(fileparts(fileparts(mfilename('fullpath'))), "\", "\");
            pr = fullfile(fileparts(mfilename('fullpath')),"MATFrostTest");
            conf_pack =  fullfile(fileparts(mfilename('fullpath')),"configure_packages.jl");
            [arg1, arg2] = shell('julia', ['+' char(julia_version)], ['--project="', char(pr), '"'], conf_pack, matfpath);
            tc.mjl = matfrostjulia(version=julia_version, project=pr);
        end
    end
end

function version = get_julia_version()
    if strcmp(getenv('GITHUB_ACTIONS'), 'true')
        version = strsplit(getenv('JULIA_VERSIONS'), ',');
    else
        version={'1.12'};
    end
end
