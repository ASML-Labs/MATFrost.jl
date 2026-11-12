classdef matfrost_demographics_test < matfrost_abstract_test
    properties
        country
    end

    methods(Access=protected)
        function project_path = julia_project_path(~)
            project_path = fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), ...
                "environments", "Demographics");
        end
    end

    methods(TestClassSetup)
        function activate_handle_integration(tc)
            tc.mjl.MATFrostDemographicsExt.activate();
        end
    end

    methods(TestMethodSetup)
        function create_country(tc)
            tc.mjl.MATFrost.("release_all_handles!")();
            tc.country = tc.mjl.Demographics.Country( ...
                "Netherlands", 33481.0, signature=["String", "Float64"]);
            tc.mjl.Demographics.("add_city!")( ...
                tc.country, "Amsterdam", int64(934526), ...
                signature=[tc.country.typename, "String", "Int64"]);
            tc.mjl.Demographics.("add_city!")( ...
                tc.country, "Rotterdam", int64(672960), ...
                signature=[tc.country.typename, "String", "Int64"]);
        end
    end

    methods(TestMethodTeardown)
        function release_country_handles(tc)
            tc.mjl.MATFrost.("release_all_handles!")();
        end
    end

    methods(Test)
        function country_is_an_opaque_handle(tc)
            tc.verifyEqual(string(fieldnames(tc.country)), ...
                ["dataType"; "id"; "typename"]);
            tc.verifyEqual(tc.country.dataType, "matfrost_handle");
            tc.verifyEqual(tc.country.typename, "Demographics.Country");
            tc.verifyFalse(isfield(tc.country, 'cities'));
        end

        function population_and_density(tc)
            population = tc.mjl.Demographics.population( ...
                tc.country, signature=tc.country.typename);
            density = tc.mjl.Demographics.density( ...
                tc.country, signature=tc.country.typename);

            tc.verifyEqual(population, int64(1607486));
            tc.verifyEqual(density, 1607486 / 33481.0, AbsTol=1e-12);
        end

        function country_info_is_materialized(tc)
            info = tc.mjl.Demographics.country_info( ...
                tc.country, signature=tc.country.typename);

            tc.verifyEqual(string(info.name), "Netherlands");
            tc.verifyEqual(info.area, 33481.0);
            tc.verifyEqual(info.population, int64(1607486));
            tc.verifyFalse(isfield(info, 'dataType'));
        end

        function mutation_preserves_identity(tc)
            copied_handle = tc.country;
            tc.mjl.Demographics.("update_city!")( ...
                tc.country, "Amsterdam", int64(950000), ...
                signature=[tc.country.typename, "String", "Int64"]);

            population = tc.mjl.Demographics.population( ...
                copied_handle, signature=copied_handle.typename);
            tc.verifyEqual(population, int64(1622960));
        end

        function remove_city_mutates_original(tc)
            tc.mjl.Demographics.("remove_city!")( ...
                tc.country, "Rotterdam", ...
                signature=[tc.country.typename, "String"]);

            population = tc.mjl.Demographics.population( ...
                tc.country, signature=tc.country.typename);
            tc.verifyEqual(population, int64(934526));
        end
    end
end