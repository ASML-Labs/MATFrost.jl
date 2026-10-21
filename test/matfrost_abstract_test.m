classdef matfrost_abstract_test < matlab.unittest.TestCase
    
    properties 
        environment (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'MATFrostTest');
    end

    properties (ClassSetupParameter)
        julia_version = get_julia_version();
    end    
    
    properties
        mjl
        supports_package_extensions (1,1) logical
    end

    methods(TestClassSetup)
        function setup_matfrost(tc, julia_version)
            needs_explicit_develop = julia_version_older_than(julia_version, [1 11]);
            tc.supports_package_extensions = ~needs_explicit_develop;
            test_root = fileparts(mfilename('fullpath'));
            project_path = fullfile(test_root, "MATFrostTest");
            if needs_explicit_develop
                configuration_packages_path = fullfile(test_root, "configure_packages.jl");
                cmdline = sprintf('julia %s%s --project="%s" "%s"', '+', julia_version, project_path, configuration_packages_path);

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

function tf = julia_version_older_than(julia_version, reference)
    % Compares version components; str2double would rank "1.7" above "1.11".
    parts = str2double(strsplit(string(julia_version), "."));
    parts(isnan(parts)) = 0;
    parts(end+1:numel(reference)) = 0;
    tf = false;
    for k = 1:numel(reference)
        if parts(k) ~= reference(k)
            tf = parts(k) < reference(k);
            return
        end
    end
end
