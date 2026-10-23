classdef matfrost_handle_test < matfrost_abstract_test
    methods(TestMethodSetup)
        function load_geometry_integration(tc)
            tc.mjl.MATFrostTest.release_handle_test_objects();
        end
    end

    methods(TestMethodTeardown)
        function cleanup_handle_registry(tc)
            tc.mjl.MATFrostTest.release_handle_test_objects();
        end
    end

    methods(Test)
        function scalar_handle_roundtrip(tc)
            obj = tc.mjl.MATFrostTest.make_handle_test_type( ...
                "Amsterdam", ...
                signature="String");

            tc.verifyTrue(isstruct(obj));
            tc.verifyTrue(isfield(obj, "dataType"));
            tc.verifyEqual(obj.dataType, "matfrost_handle");
            tc.verifyTrue(isfield(obj, "id"));
            tc.verifyTrue(isfield(obj, "typename"));
            tc.verifyFalse(isfield(obj, "value"));
            tc.verifyEqual(obj.typename, "MATFrostTest.HandleTestType");

            actual = tc.mjl.MATFrostTest.get_handle_test_value( ...
                obj, ...
                signature="MATFrostTest.HandleTestType");

            tc.verifyEqual(actual, "Amsterdam");
        end

        function point_handle_roundtrip(tc)
            % Geometry.Point handle support comes from a package extension (Julia >= 1.11).
            tc.assumeTrue(tc.supports_package_extensions);

            point = tc.mjl.Geometry.Point( ...
                "Amsterdam", ...
                signature="String");

            tc.verifyTrue(isstruct(point));
            tc.verifyEqual(point.dataType, "matfrost_handle");
            tc.verifyTrue(isfield(point, "id"));
            tc.verifyTrue(isfield(point, "typename"));
            tc.verifyFalse(isfield(point, "label"));
            tc.verifyEqual(point.typename, "Geometry.Point");

            label = tc.mjl.Geometry.get_label( ...
                point, ...
                signature="Geometry.Point");

            tc.verifyEqual(label, "Amsterdam");
        end
    end
end
