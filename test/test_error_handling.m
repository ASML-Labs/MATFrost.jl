classdef test_error_handling <  matlab.unittest.TestCase
    methods (Test)
        function test_enhance_error_message(tc)

            msg = [
                "Ambiguous function call"
                ""
                "Available methods:"
                "[1] compute_measure(m::MATFrostTest.PopulationMeasure)"
                "[2] compute_measure(m::MATFrostTest.CompositeMeasure)"
            ];

            actual = enhanceMultipleMethodDefinitionsMessage( ...
                join(msg,newline));

            tc.verifyThat(actual, ...
                matlab.unittest.constraints.ContainsSubstring("Hint:"));
        end
    end
end