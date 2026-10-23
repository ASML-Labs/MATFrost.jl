classdef matfrost_demographics_test < matfrost_abstract_test

    methods(Test, TestTags="dispatch")

        function country_handle_roundtrip(tc)

            country = tc.mjl.Demographics.Country( ...
                "Netherlands", ...
                33481.0);

            tc.verifyTrue( ...
                isa(country, "MATFrostHandle"));

        end

        function country_population(tc)

            country = tc.mjl.Demographics.Country( ...
                "Netherlands", ...
                33481.0);

            add_city = tc.mjl.Demographics.("add_city!");

            add_city(country, "Amsterdam", int64(934526));
            add_city(country, "Rotterdam", int64(672960));

            actual = tc.mjl.Demographics.population(country);

            tc.verifyEqual(actual, int64(1607486));

        end

        function country_density(tc)

            country = tc.mjl.Demographics.Country( ...
                "Netherlands", ...
                33481.0);

            add_city = tc.mjl.Demographics.("add_city!");

            add_city(country, "Amsterdam", int64(934526));
            add_city(country, "Rotterdam", int64(672960));

            actual = tc.mjl.Demographics.density(country);

            expected = 1607486 / 33481.0;

            tc.verifyEqual(actual, expected, AbsTol=1e-12);

        end

        function country_info(tc)

            country = tc.mjl.Demographics.Country( ...
                "Netherlands", 33481.0, ...
                signature = ["String", "Float64"]);

            add_city = tc.mjl.Demographics.("add_city!");

            add_city(country, "Amsterdam", int64(934526));
            add_city(country, "Rotterdam", int64(672960));

            info = tc.mjl.Demographics.country_info(country);

            tc.verifyEqual(string(info.name), "Netherlands");
            tc.verifyEqual(info.area, 33481.0);
            tc.verifyEqual(info.population, int64(1607486));

        end

        function update_city(tc)

             country = tc.mjl.Demographics.Country( ...
                "Netherlands", 33481.0, ...
                signature = ["String", "Float64"]);

            add_city = tc.mjl.Demographics.("add_city!");
            update_city = tc.mjl.Demographics.("update_city!");

            add_city(country, "Amsterdam", int64(934526));

            update_city(country, "Amsterdam", int64(950000));

            actual = tc.mjl.Demographics.population(country);

            tc.verifyEqual(actual, int64(950000));

        end

        function remove_city(tc)

            country = tc.mjl.Demographics.Country( ...
                "Netherlands", 33481.0, ...
                signature = ["String", "Float64"]);

            add_city = tc.mjl.Demographics.("add_city!");
            remove_city = tc.mjl.Demographics.("remove_city!");

            add_city(country, "Amsterdam", int64(934526));
            add_city(country, "Rotterdam", int64(672960));

            remove_city(country, "Rotterdam");

            actual = tc.mjl.Demographics.population(country);

            tc.verifyEqual(actual, int64(934526));

        end

        function dataframe(tc)

            country = tc.mjl.Demographics.Country( ...
                "Netherlands", 33481.0, ...
                signature = ["String", "Float64"]);

            add_city = tc.mjl.Demographics.("add_city!");

            add_city(country, "Amsterdam", int64(934526));
            add_city(country, "Rotterdam", int64(672960));

            actual = tc.mjl.Demographics.dataframe(country);

            expected = table( ...
                ["Amsterdam"; "Rotterdam"], ...
                int64([934526; 672960]), ...
                VariableNames=["name","population"]);

            tc.verifyEqual(actual, expected);

        end

    end

end