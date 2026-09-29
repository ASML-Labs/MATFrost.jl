classdef matfrost_exception_error_handling_test < matfrost_abstract_test

    methods (Test)
        function enhance_multiple_method_definitions_message_hint(tc)

            msg = [
                "Ambiguous function call"
                ""
                "Available methods:"
                "[1] compute_measure(m::MATFrostTest.PopulationMeasure)"
                "[2] compute_measure(m::MATFrostTest.CompositeMeasure)"
            ];

            actual = matfrostjulia.enhanceMultipleMethodDefinitionsMessage( ...
                join(msg, newline));

            tc.verifyThat(actual, ...
                matlab.unittest.constraints.ContainsSubstring("Hint:"));
        end
    end
end
