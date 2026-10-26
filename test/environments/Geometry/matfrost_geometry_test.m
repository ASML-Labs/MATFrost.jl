classdef matfrost_geometry_test < matfrost_abstract_test

    properties (Constant)
        environment = "Geometry"
    end
   
    methods(Test, TestTags="dispatch")
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