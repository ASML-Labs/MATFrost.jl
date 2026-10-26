classdef matfrost_demographics_test < matfrost_abstract_test
    
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
