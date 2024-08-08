classdef matfrost_abstract_test < matlab.unittest.TestCase
    
    properties 
        environment (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'MATFrostTest');
    end

    properties (ClassSetupParameter)
        julia = {"1.7"};
    end    
    
    
    properties
        mjl matfrostjulia
    end


    methods(TestClassSetup)
        function setup_matfrost(tc, julia)

           tc.mjl = matfrostjulia(...
                environment = tc.environment, ...
                version     = julia, ...
                instantiate = true);

            if isunix()
                addpath("~/.julia/scratchspaces/406cae98-a0f7-4766-b83f-8510a556e0e7/mexbin")
            end
           
        end
    end
   
end
