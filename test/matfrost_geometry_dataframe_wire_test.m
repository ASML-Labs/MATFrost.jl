classdef matfrost_geometry_dataframe_wire_test < matfrost_abstract_test
    methods(TestClassSetup)
        function activate_geometry(tc)
            tc.mjl.MATFrostGeometryExt.activate();
        end
    end

    methods(Test, TestTags="dispatch")
        function points_dataframe_returns_wire_payload(tc)
            wire = tc.mjl.Geometry.points_dataframe();

            tc.verifyTrue(istable(wire));
            tc.verifyEqual(height(wire), 3);
            tc.verifyEqual(width(wire), 3);

            tc.verifyEqual(...
                string(wire.Properties.VariableNames(:)), ...
                ["label"; "kind"; "population"]);

            tc.verifyClass(wire.label, "string");
            tc.verifyClass(wire.kind, "string");
            tc.verifyClass(wire.population, "int64");

            tc.verifyEqual(...
                string(wire.label(:)), ...
                ["Amsterdam"; "Eindhoven"; "Veldhoven"]);

            tc.verifyEqual(...
                string(wire.kind(:)), ...
                ["city"; "city"; "village"]);

            tc.verifyEqual(...
                wire.population(:), ...
                int64([931298; 246443; 45829]));
        end
    end
end