classdef matfrost_handle_test < matfrost_abstract_test
    methods(TestMethodSetup)
        function clear_handle_registry(tc)
            tc.mjl.MATFrostTest.release_handle_test_objects();
        end
    end

    methods(TestMethodTeardown)
        function release_handle_registry(tc)
            tc.mjl.MATFrostTest.release_handle_test_objects();
        end
    end

    methods(Test)
        function scalar_handle_roundtrip(tc)
            object = tc.mjl.MATFrostTest.make_handle_test_type( ...
                int64(42), signature="Int64");

            tc.verifyEqual(string(fieldnames(object)), ["dataType"; "id"; "typename"]);
            tc.verifyEqual(object.dataType, "matfrost_handle");
            tc.verifyEqual(object.typename, "MATFrostTest.HandleTestType");
            tc.verifyFalse(isfield(object, 'value'));
            tc.verifyGreaterThan(strlength(string(object.id)), 0);

            actual = tc.mjl.MATFrostTest.get_handle_test_value( ...
                object, signature=object.typename);
            tc.verifyEqual(actual, int64(42));
        end

        function mutations_preserve_identity(tc)
            object = tc.mjl.MATFrostTest.make_handle_test_type( ...
                int64(3), signature="Int64");
            copied_reference = object;

            actual = tc.mjl.MATFrostTest.("increment_handle_test_value!")( ...
                object, int64(7), signature=[object.typename, "Int64"]);
            tc.verifyEqual(actual, int64(10));

            actual = tc.mjl.MATFrostTest.get_handle_test_value( ...
                copied_reference, signature=copied_reference.typename);
            tc.verifyEqual(actual, int64(10));
        end

        function explicit_release(tc)
            object = tc.mjl.MATFrostTest.make_handle_test_type( ...
                int64(42), signature="Int64");

            released = tc.mjl.MATFrost.release_handle( ...
                object, signature="MATFrost.MATFrostHandle");
            tc.verifyTrue(released);
            released = tc.mjl.MATFrost.release_handle( ...
                object, signature="MATFrost.MATFrostHandle");
            tc.verifyFalse(released);
            tc.verifyEqual(tc.mjl.MATFrost.handle_count(), int64(0));
        end
    end
end