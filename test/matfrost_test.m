classdef matfrost_test < matlab.unittest.TestCase
% Unit test for matfrostjulia testing the translations of the base types from MATLAB to Julia and back.




    properties
        mjl matfrostjulia
    end

    properties (ClassSetupParameter)
        julia_version = {'1.7', '1.8', '1.8', '1.9', '1.10'}; 
            % Incompatible with 1.6 and lower as of now!
    end


    methods(TestClassSetup)
        function setup_matfrost(tc, julia_version)
           tc.mjl = matfrostjulia(...
                environment = fullfile(fileparts(mfilename('fullpath')), 'MATFrostTest'), ...
                version     = julia_version, ...
                instantiate = true);
           
            tc.mjl = tc.mjl.MATFrostTest;
        end
    end

    
    methods(Test)
        % Test methods
        
        function simple_numerical_tests(tc)            
            tc.verifyEqual(...
                tc.mjl.elementwise_addition_f64(100, (1:100)'), ...
                100.+(1:100)');

            tc.verifyEqual(...
                tc.mjl.kron_product_matrix_f64(diag(1:10), (1:10)'*(1:10)), ...
                kron(diag(1:10), (1:10)'*(1:10)));

        end

        function sum_vector_of_vector_f64(tc)
            vov = cell(10,1);
            acc = 0;
            for i=1:10
                vov{i} = (1:i)';
                acc = acc+ sum(1:i);
            end

            tc.verifyEqual(...
                tc.mjl.sum_vector_of_vector_f64(vov), ...
                acc);

        end
        
        function nested_structures_test1(tc)
            
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};

            tc.verifyEqual(...
                tc.mjl.sum_nest1(nest1), ...
                3+4+5+6+7);
        end
        function nested_structures_test2(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};


            nest2 = struct;
            nest2.v1={nest1;nest1;nest1};
            nest2.vs=repmat(nest1, 50,1);
            
            tc.verifyEqual(...
                tc.mjl.sum_nest2(nest2), ...
                (50+3)*(3+4+5+6+7));

        end

        function rename_structures_test1(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};

            
            rin = struct("old_v", nest1, "old_vs", repmat(nest1, 10,1));

            tc.verifyEqual(...
                tc.mjl.rename_test1(rin), ...
                struct( ...
                    "action", "Renamed", ...
                    "new_v", nest1, ...
                    "new_vs", repmat(nest1, 10,1) ...
                ));

        end
    
        function string_manipulations(tc)
            
            tc.verifyEqual(...
                tc.mjl.repeat_string("teststring_😀_", int64(4)), ...
                "teststring_😀_teststring_😀_teststring_😀_teststring_😀_");

            tc.verifyEqual(...
                tc.mjl.repeat_string('testchar_😀_', int64(2)), ...
                "testchar_😀_testchar_😀_");

        end

        function primitive_logical(tc)
            tc.verifyEqual(...
                    tc.mjl.logical_f64_multiplication(true, 8.8), ...
                    8.8);
            tc.verifyEqual(...
                    tc.mjl.logical_f64_multiplication(false, 8.8), ...
                    0.0)
        end

        function double_primitive_scalars(tc)
            
            ts = ["i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
                "f32"; "f64"];

            vs = {...
                int8(22);         uint8(42);...
                int16(3322);      uint16(4532);...
                int32(323442);    uint32(53342);... 
                int64(323434542); uint64(535345342);...
                ...
                single(34.125);   2342.0625};

            % Real numbers
            for i=1:numel(ts)
                tc.verifyEqual(...
                    tc.mjl.("double_scalar_" + ts(i))(vs{i}), vs{i}+vs{i});
            end

            % Complex numbers
            for i=1:numel(ts)
                v  = complex(vs{i},   2 * vs{i});
                v2 = complex(2*vs{i}, 4 * vs{i});
                tc.verifyEqual(...
                    tc.mjl.("double_scalar_c" + ts(i))(v), v2);
            end

        end

        function double_primitive_vectors(tc)
            
            ts = ["i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
                "f32"; "f64"];

            vs = {...
                int8(11 + (1:10)');         uint8(42 + (1:10)');...
                int16(3322 + (1:10)');      uint16(4532 + (1:10)');...
                int32(323442 + (1:10)');    uint32(53342 + (1:10)');... 
                int64(323434542 + (1:10)'); uint64(535345342 + (1:10)');...
                ...
                single(34.125 + (1:10)');   2342.0625 + (1:10)'};

            % Real numbers
            for i=1:numel(ts)
                tc.verifyEqual(...
                    tc.mjl.("double_vector_" + ts(i))(vs{i}), vs{i}+vs{i});
            end

            % Complex numbers
            for i=1:numel(ts)
                v  = complex(vs{i},   2 * vs{i});
                v2 = complex(2*vs{i}, 4 * vs{i});
                tc.verifyEqual(...
                    tc.mjl.("double_vector_c" + ts(i))(v), v2);
            end

        end


        function sum_complex_numbers(tc)
            vr = 2342.0625 + logspace(1,5,100)';
            vi = 345.0625  + logspace(3,4,100)';
            
            v = complex(vr,vi);
            tc.verifyEqual(...
                    tc.mjl.("sum_vector_cf64")(v), complex(sum(vr), sum(vi)), "RelTol", 1e-15);
        end

    end

    methods (TestClassTeardown)
        function teardown_matfrost(tc)
            tc.mjl = tc.mjl([]); % Remove BJL references.
        end
    end
    
end
