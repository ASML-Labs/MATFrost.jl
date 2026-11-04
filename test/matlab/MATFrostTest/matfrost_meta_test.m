classdef matfrost_meta_test < matfrost_abstract_test
% Unit test for matfrostjulia testing the translations of the base types from MATLAB to Julia and back.

    methods(Test, TestTags="ErrorHandling") % Test methods        
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

        function invalid_signature_type(tc)
            % Pass a numeric value in the signature to trigger the exception
            tc.verifyError(@() tc.mjl.MATFrostTest.multiple_method_definitions(23.0, signature={42}), ...
                "matfrostjulia:invalidSignature");
        end
        function invalid_signature_size(tc)
            % Pass a numeric value in the signature to trigger the exception
            tc.verifyError(@() tc.mjl.MATFrostTest.multiple_method_definitions(23.0, signature=["Float64","Float64"]), ...
                "matfrostjulia:invalidSignatureSize");
        end
    end
    methods(Test, TestTags="basic function call")
        function no_signature_provided(tc)
            res = tc.mjl.MATFrostTest.elementwise_addition_f64(2.0, [1.0, 2.0, 3.0]);
            tc.verifyEqual(res, [3.0, 4.0, 5.0]');
        end
        function elementwise_addition(tc)
            res = tc.mjl.MATFrostTest.elementwise_addition_f64(2.0, [1.0, 2.0, 3.0], signature=["Float64","Vector{Float64}"]);
            tc.verifyEqual(res, [3.0, 4.0, 5.0]');
        end

        function compute_measure_population(tc)
            pop = tc.mjl.MATFrostTest.SimplePopulationType("A", int64(100),signature=["String","Int64"]);
            res = tc.mjl.MATFrostTest.compute_measure(pop, signature="MATFrostTest.SimplePopulationType");
            tc.verifyEqual(res, 100.0);
        end

        function repeat_string(tc)
            res = tc.mjl.MATFrostTest.repeat_string("ab", int64(3), signature=["String","Int64"]);
            tc.verifyEqual(res, "ababab");
        end

        function concat_strings(tc)
            res = tc.mjl.MATFrostTest.concat_strings(["a", "b", "c"], signature="Vector{String}");
            tc.verifyEqual(res, "abc");
        end
    end
    methods(Test, TestTags="multi-dispatch calls")
        function multiple_method_float(tc)
            res = tc.mjl.MATFrostTest.multiple_method_definitions(23.0, signature="Float64");
            tc.verifyEqual(res, 46.0);
        end

        function multiple_method_int(tc)
            res = tc.mjl.MATFrostTest.multiple_method_definitions(int64(3), signature="Int64");
            tc.verifyEqual(res, int64(5));
        end

        function multiple_method_string(tc)
            res = tc.mjl.MATFrostTest.multiple_method_definitions("foo", int64(7), signature=["String","Int64"]);
            tc.verifyEqual(res, "foo_7");
        end

        function point_addition_test(tc)
            % Create two Julia Point objects
            p1 = tc.mjl.MATFrostTest.Point(int64(1), int64(2),signature=["Int64","Int64"]);
            p2 = tc.mjl.MATFrostTest.Point(int64(3), int64(4),signature=["Int64","Int64"]);

            % Call the overloaded Base.+ method for Point
            res = tc.mjl.Base.('+')(p1, p2, signature=["MATFrostTest.Point", "MATFrostTest.Point"]);
            
            % Verify the result is a Point with expected values
            tc.verifyEqual(res.x, int64(4));
            tc.verifyEqual(res.y, int64(6));
        end
    end

end