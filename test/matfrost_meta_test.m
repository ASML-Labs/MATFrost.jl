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
    end
    methods(Test, TestTags="basic function call")
        function test_elementwise_addition(tc)
            res = tc.mjl.MATFrostTest.elementwise_addition_f64(2.0, [1.0, 2.0, 3.0], signature=["Float64","Vector{Float64}"]);
            tc.verifyEqual(res, [3.0, 4.0, 5.0]');
        end

        function test_compute_measure_population(tc)
            pop = tc.mjl.MATFrostTest.SimplePopulationType("A", int64(100),signature=["String","Int64"]);
            res = tc.mjl.MATFrostTest.compute_measure(pop, signature="SimplePopulationType");
            tc.verifyEqual(res, 100.0);
        end

        function test_repeat_string(tc)
            res = tc.mjl.MATFrostTest.repeat_string("ab", int64(3), signature=["String","Int64"]);
            tc.verifyEqual(res, "ababab");
        end

        function test_concat_strings(tc)
            res = tc.mjl.MATFrostTest.concat_strings({"a", "b", "c"}, signature="Vector{String}");
            tc.verifyEqual(res, "abc");
        end
    end
    methods(Test, TestTags="multi-dispatch calls")
        function test_multiple_method_float(tc)
            res = tc.mjl.MATFrostTest.multiple_method_definitions(23.0, signature="Float64");
            tc.verifyEqual(res, 46.0);
        end

        function test_multiple_method_int(tc)
            res = tc.mjl.MATFrostTest.multiple_method_definitions(int64(3), signature="Int64");
            tc.verifyEqual(res, 5);
        end

        function test_multiple_method_string(tc)
            res = tc.mjl.MATFrostTest.multiple_method_definitions("foo", 7, signature=["String","Int64"]);
            tc.verifyEqual(res, "foo_7");
        end
    end

end