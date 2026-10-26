classdef matfrost_abstract_test < matlab.unittest.TestCase

    properties (Dependent, SetAccess = immutable)
        environment (1,1) string
        test_root (1,1) string
    end

    properties (ClassSetupParameter)
        julia_version = get_julia_version();
    end

    properties
        mjl
        supports_package_extensions (1,1) logical
    end

    methods
        function environment = get.environment(tc)
            test_folder = fileparts(which(class(tc)));
            [~, environment] = fileparts(test_folder);
            environment = string(environment);
        end

        function test_root = get.test_root(tc)
            test_folder = fileparts(which(class(tc)));
            test_root = string(fileparts(fileparts(test_folder)));
        end
    end

    methods (TestClassSetup)
        function setup_matfrost(tc, julia_version)
            needs_explicit_develop = ...
                julia_version_older_than(julia_version, [1 11]);

            tc.supports_package_extensions = ~needs_explicit_develop;

            environment_path = fullfile( ...
                tc.test_root, ...
                "environments", ...
                tc.environment);

            if ~isfolder(environment_path)
                error( ...
                    "MATFrost:InvalidTestEnvironment", ...
                    "Test environment '%s' does not exist at '%s'.", ...
                    tc.environment, ...
                    environment_path);
            end

            if needs_explicit_develop
                configure_packages_path = fullfile( ...
                    tc.test_root, ...
                    "..", ...
                    "src", ...
                    "matlab", ...
                    "@matfrostjulia", ...
                    "configure_packages.jl");

                cmdline = sprintf( ...
                    'julia +%s --startup-file=no "%s" "%s"', ...
                    julia_version, ...
                    configure_packages_path, ...
                    environment_path);

                if ispc
                    [status, log] = shell( ...
                        'cmd.exe', '/c', cmdline);
                elseif isunix
                    [status, log] = shell( ...
                        '/bin/sh', '-c', cmdline, ...
                        'environmentVariables', ...
                        struct('LD_LIBRARY_PATH', ''));
                else
                    error("MATFrost:UnsupportedPlatform", ...
                        "Platform is not supported.");
                end

                if status ~= 0
                    error( ...
                        "MATFrost:ConfigurePackagesFailed", ...
                        "Failed to configure packages:\n%s", ...
                        log);
                end
            end

            tc.mjl = matfrostjulia( ...
                version=julia_version, ...
                project=environment_path);
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