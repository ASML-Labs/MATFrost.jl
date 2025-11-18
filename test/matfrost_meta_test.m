classdef matfrost_meta_test < matfrost_abstract_test
% Unit test for matfrostjulia testing the translations of the base types from MATLAB to Julia and back.

    
    methods(Test)
        % Test methods
        
        function missing_package_test(tc)
            tc.verifyError(@() tc.mjl.PackageDoesNotExist.test(), 'matfrostjulia:call:packageNotFound');
        end

        function missing_function_test(tc)          
            tc.verifyError(@() tc.mjl.MATFrostTest.function_does_not_exist(), 'matfrostjulia:call:functionNotFound');
            tc.verifyError(@() tc.mjl.MATFrostTest.ModuleDoesNotExist.function_does_not_exist(), 'matfrostjulia:call:functionNotFound');
        end


        function multiple_methods_test(tc)
            tc.verifyError(@() tc.mjl.MATFrostTest.multiple_method_definitions(23.0), 'matfrostjulia:call:multipleMethodDefinitions');
        end
        
        function missingParenthesis_test(tc)
            tc.verifyError(@() tc.mjl.MATFrostTest.multiple_method_definitions, "matfrostjulia:invalidCallSignature");
        end

        function specify_method_test(tc)
            res = tc.mjl.MATFrostTest.multiple_method_definitions(23,signature="Int64");
            tc.verifyEqual(res, 46);
        end

    end

end
