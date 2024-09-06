classdef matfrost_abstract_test < matlab.unittest.TestCase
    
    properties 
        environment (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'MATFrostTest');
    end

    properties (ClassSetupParameter)
        julia_version = get_julia_version()

        mexbinaries = {"COMPILE", "PRECOMPILED_ARTIFACTS"}
    end    
    
    properties
        mjl
    end

    methods(TestClassSetup)
        function setup_matfrost(tc, julia_version, mexbinaries)

            delete(fullfile(fileparts(mfilename("fullpath")), "@MATFrostTest/*"));
            delete(fullfile(fileparts(mfilename("fullpath")), "@MATFrostTest/private/*"));


            [~, bindir] = shell('julia', ['+' char(version)], '-e',  'println(Sys.BINDIR)');

            matfpath = strrep(fileparts(fileparts(mfilename('fullpath'))), "\", "\\");
            
            env.JULIA_PROJECT = tc.environment;
            env.PATH = fileparts(bindir);
            env.LD_LIBRARY_PATH = fullfile(fileparts(bindir), "lib");

            shell('julia', ['+' char(julia_version)], '-e',  "import Pkg ; Pkg.develop(path=\"""+ matfpath + "\"") ; Pkg.resolve() ; using MATFrost ; MATFrost.install()", environmentVariables=env, echo=true);

            if mexbinaries == "COMPILE"
                addpath(fullfile(fileparts(fileparts(mfilename("fullpath"))), "src/matfrostjuliacall"));

                matv = regexp(version, "R20\d\d[ab]", "match");
                matv = matv{1};
                mjlname = "matfrostjuliacall_r" + string(matv(2:end));


                mjlfile = mjlname + "." + mexext();
                if ~exist(fullfile(fileparts(fileparts(mfilename("fullpath"))), "src/matfrostjuliacall/bin", mjlfile), "file")
                    matfrostmake(mjlname);
                end

                delete(fullfile(fileparts(mfilename("fullpath")), "@MATFrostTest/private/matfrostjuliacall_*"))

                copyfile( ...
                    fullfile(fileparts(fileparts(mfilename("fullpath"))), "src/matfrostjuliacall/bin", mjlfile), ...
                    fullfile(fileparts(mfilename("fullpath")), "@MATFrostTest/private", mjlfile));
            end

            tc.mjl = MATFrostTest(...
                version     = julia_version, ...
                instantiate = true);

        end
    end
end

function version = get_julia_version()
    if strcmp(getenv('GITHUB_ACTIONS'), 'true')
        version = { getenv('JULIA_VERSION') };
    else
        version = {'1.7', '1.8', '1.9', '1.10', '1.11'};
    end
end
