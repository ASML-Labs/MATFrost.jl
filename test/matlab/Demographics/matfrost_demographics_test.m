classdef matfrost_demographics_test < matfrost_abstract_test

    properties
        country
    end

    methods(TestClassSetup)
        function activateExtension(tc)
            tc.mjl.MATFrostDemographicsExt.activate();
        end

        function createCountry(tc)
            tc.country = tc.mjl.Demographics.Country( ...
                "Netherlands", 33481.0, ...
                signature=["String", "Float64"]);
            tc.mjl.Demographics.("add_city!")(tc.country, "Amsterdam", int64(934526));
            tc.mjl.Demographics.("add_city!")(tc.country, "Rotterdam", int64(672960));
        end
    end

    methods(Test, TestTags="dispatch")
        function country_handle_roundtrip(tc)
            expected = ["dataType"; "id"; "typename"];

            tc.verifyTrue(all(strcmp( ...
                string(fieldnames(tc.country)), ...
                expected)));
        end

        function country_population(tc)
            actual = tc.mjl.Demographics.population( ...
                tc.country, ...
                signature=tc.country.typename);

            tc.verifyEqual(actual, int64(1607486));
        end

        function country_density(tc)
            actual = tc.mjl.Demographics.density( ...
                tc.country, ...
                signature=tc.country.typename);

            expected = 1607486 / 33481.0;

            tc.verifyEqual(actual, expected, AbsTol=1e-12);
        end

        function country_info(tc)
            actual = tc.mjl.Demographics.country_info(tc.country);

            tc.verifyEqual(string(actual.name), "Netherlands");
            tc.verifyEqual(actual.area, 33481.0);
            tc.verifyEqual(actual.population, int64(1607486));
        end

        function update_city(tc)
            tc.mjl.Demographics.("update_city!")(tc.country, "Amsterdam", int64(950000));

            actual = tc.mjl.Demographics.population(tc.country,signature=tc.country.typename);

            tc.verifyEqual(actual, int64(1622960));
        end

        function remove_city(tc)
            tc.mjl.Demographics.("remove_city!")(tc.country, "Rotterdam");
            actual = tc.mjl.Demographics.population(tc.country, signature=tc.country.typename);

            tc.verifyEqual(actual, int64(934526));
        end

        function dataframe(tc)
            actual = tc.mjl.Demographics.dataframe(tc.country,signature=tc.country.typename);

            expected = table( ...
                ["Amsterdam"; "Rotterdam"], ...
                int64([934526; 672960]), ...
                VariableNames=["name", "population"]);

            tc.verifyEqual(actual, expected);
        end
    end
end