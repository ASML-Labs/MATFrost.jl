classdef matfrost_extension_test < matfrost_abstract_test
    % Unit test for matfrostjulia testing the translations of the base types from MATLAB to Julia and back.
    methods(TestClassSetup)

    function activateGeometry(tc)
        tc.mjl.MATFrostGeometryExt.activate();
    end

    end
    methods(Test, TestTags="dispatch") % Test methods
        function geometry_dispatch(tc)
            
            result = tc.mjl.Geometry.get_label( ...
                "Amsterdam", signature="Geometry.Point");

            tc.verifyEqual(result,"Amsterdam");

        end
    end
end
