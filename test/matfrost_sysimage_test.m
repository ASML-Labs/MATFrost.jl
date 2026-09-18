classdef matfrost_sysimage_test < matfrost_abstract_test

    properties
        tested_julia_version (1,1) string
    end

    methods(TestClassSetup)
        function store_julia_version(tc, julia_version)
            tc.tested_julia_version = julia_version;
        end
    end

    methods(Test, TestTags="Sysimage")
        function start_with_custom_sysimage(tc)
            [sysimage_dir, sysimage_name] = tc.copy_default_sysimage();
            project_path = fullfile(fileparts(mfilename('fullpath')), "MATFrostTest");

            jl = matfrostjulia(version=tc.tested_julia_version, project=project_path, ...
                sysimage=fullfile(sysimage_dir, sysimage_name));


            tc.verifyTrue(endsWith(string(jl.MATFrostTest.sysimage_path()), sysimage_name), ...
                "Julia was not started with the requested sysimage.");
            tc.verifyEqual(jl.MATFrostTest.elementwise_addition_f64(2.0, [1.0; 2.0; 3.0]), [3.0; 4.0; 5.0]);
        end

        function start_with_relative_sysimage_path(tc)
            [sysimage_dir, sysimage_name] = tc.copy_default_sysimage();
            project_path = fullfile(fileparts(mfilename('fullpath')), "MATFrostTest");

            old_dir = cd(sysimage_dir);
            tc.addTeardown(@cd, old_dir);

            jl = matfrostjulia(version=tc.tested_julia_version, project=project_path, ...
                sysimage=sysimage_name);


            tc.verifyTrue(endsWith(string(jl.MATFrostTest.sysimage_path()), sysimage_name), ...
                "Relative sysimage path was not resolved correctly.");
        end

        function missing_sysimage_errors(tc)
            tc.verifyError(@() matfrostjulia(version=tc.tested_julia_version, ...
                sysimage=fullfile(tempdir, "matfrost_sysimage_does_not_exist.so")), ...
                'MATLAB:validators:mustBeFile');
        end
    end

    methods(Access=private)
        function [sysimage_dir, sysimage_name] = copy_default_sysimage(tc)
            default_sysimage = string(tc.mjl.MATFrostTest.sysimage_path());
            [~, ~, ext] = fileparts(default_sysimage);

            sysimage_dir = fullfile(tempdir, "matfrost sysimage " + string(randi(1e9)));
            sysimage_name = "matfrost_test_sys" + ext;
            mkdir(sysimage_dir);
            tc.addTeardown(@remove_folder_quietly, sysimage_dir);

            copyfile(default_sysimage, fullfile(sysimage_dir, sysimage_name));
        end
    end
end

function remove_folder_quietly(folder)
    for attempt = 1:10
        if ~isfolder(folder) || rmdir(folder, 's')
            return
        end
        pause(0.5);
    end
end
