classdef matfrost_abstract_test < matlab.unittest.TestCase
    
    properties 
        environment (1,1) string = fullfile(fileparts(mfilename('fullpath')), 'MATFrostTest');
    end

    properties (ClassSetupParameter)
        julia = {"1.7", "1.8", "1.9", "1.10"};
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
           
        end
    end

   
  
    
end