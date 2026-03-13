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
            matfrost_path = fileparts(fileparts(mfilename('fullpath')));
            project_path = fullfile(fileparts(mfilename('fullpath')),"MATFrostTest");
            configuration_packages_path =  fullfile(fileparts(mfilename('fullpath')),"configure_packages.jl");

            cmdline = sprintf('julia %s%s --project="%s" "%s" "%s"', '+', julia_version, project_path, configuration_packages_path, matfrost_path);

            if ispc
                [resolve_julia_project_status, resolve_julia_project_log] = ...
                    shell('cmd.exe', '/c', cmdline)
            elseif isunix
                % LD_LIBRARY_PATH should be cleared to prevent loading of
                % MATLAB libraries in Julia process.
                [resolve_julia_project_status, resolve_julia_project_log] = ...
                    shell('/bin/sh', '-c', cmdline, 'environmentVariables', struct('LD_LIBRARY_PATH', ''))
            else
                error("Not supported")
            end
            
            tc.mjl = matfrostjulia(version=julia_version, project=project_path);
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
