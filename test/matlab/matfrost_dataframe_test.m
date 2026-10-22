classdef matfrost_dataframe_test < matfrost_abstract_test
    methods(TestMethodSetup)
        function load_converters(tc)
            tc.mjl.MATFrostGeometryExt.activate();
        end
    end

    methods(Test, TestTags="dispatch")
        function points_dataframe_returns_wire_payload(tc)
            wire = tc.mjl.Geometry.points_dataframe();

            tc.verifyTrue(istable(wire));
            tc.verifyEqual(height(wire), 3);
            tc.verifyEqual(width(wire), 2);

            tc.verifyEqual(...
                string(wire.Properties.VariableNames(:)), ...
                ["label"; "kind"]);

            tc.verifyClass(wire.label, "string");
            tc.verifyClass(wire.kind, "string");

            tc.verifyEqual(...
                string(wire.label(:)), ...
                ["Amsterdam"; "Eindhoven"; "Veldhoven"]);

            tc.verifyEqual(...
                string(wire.kind(:)), ...
                ["city"; "city"; "city"]);
        end
    end
end
