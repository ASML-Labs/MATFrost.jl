classdef matfrost_extension_test < matfrost_abstract_test
    % Unit test for matfrostjulia testing the translations of the base types from MATLAB to Julia and back.

    methods(Test, TestTags="dispatch") % Test methods
        function geometry_dispatch(tc)
            
            tc.mjl.MATFrostGeometryExt.activate();
            result = tc.mjl.Geometry.get_label( ...
                "Amsterdam", ...
                signature="Geometry.Point");

            tc.verifyEqual(result,"Amsterdam");

        end
        function geometry_constructor(tc)

            p = tc.mjl.Geometry.Point( ...
                "Amsterdam", ...
                signature="String");

            result = tc.mjl.Geometry.get_label(p);

            tc.verifyEqual(result,"Amsterdam");

        end
    end
end
