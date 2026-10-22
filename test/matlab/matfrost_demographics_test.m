classdef matfrost_demographics_test < matfrost_abstract_test

    methods (Test, TestTags="dispatch")

        function country_handle_preserves_state(tc)

            country = tc.mjl.Demographics.Country( ...
                "Netherlands", ...
                33481.0);

            add_city = tc.mjl.Demographics.("add_city!");
            update_city = tc.mjl.Demographics.("update_city!");

            add_city(country, "Amsterdam", int64(934526));
            add_city(country, "Rotterdam", int64(672960));

            update_city(country, "Amsterdam", int64(950000));

            tc.verifyEqual( ...
                tc.mjl.Demographics.population(country), ...
                int64(1622960));

            tc.verifyEqual( ...
                string(tc.mjl.Demographics.city_names(country)), ...
                ["Amsterdam"; "Rotterdam"]);

        end

        function country_dataframe_returns_table(tc)

            country = tc.mjl.Demographics.Country( ...
                "Netherlands", ...
                33481.0);

            add_city = tc.mjl.Demographics.("add_city!");

            add_city(country, "Amsterdam", int64(934526));
            add_city(country, "Rotterdam", int64(672960));

            actual = tc.mjl.Demographics.dataframe(country);

            expected = table( ...
                ["Amsterdam"; "Rotterdam"], ...
                int64([934526; 672960]), ...
                "VariableNames", ["name", "population"]);

            tc.verifyEqual(actual, expected);

        end

    end

end