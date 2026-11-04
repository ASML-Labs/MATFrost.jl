classdef matfrost_test < matfrost_abstract_test
% Unit test for matfrostjulia testing the translations of the base types from MATLAB to Julia and back.

    
    methods(Test)
        % Test methods
        
        function simple_numerical_tests(tc)            
            tc.verifyEqual(...
                tc.mjl.MATFrostTest.elementwise_addition_f64(100, (1:100)'), ...
                100.+(1:100)');

            tc.verifyEqual(...
                tc.mjl.MATFrostTest.kron_product_matrix_f64(diag(1:10), (1:10)'*(1:10)), ...
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
                tc.mjl.MATFrostTest.sum_vector_of_vector_f64(vov), ...
                acc);

        end

        function simple_composite_type(tc)
            ct = struct;
            ct.v1 = int64(322);
            ct.v2 = int32(3913);
            ct.v3 = uint8(33);

            tc.verifyEqual(...
                tc.mjl.MATFrostTest.sum_composite_number_type(ct), ...
                int64(322+3913+33));

        end

        function simple_struct(tc)
            
            p1 = struct;
            p1.name = "Midgard";
            p1.population = int64(5443);

            p2 = struct;
            p2.name = "Asgard";
            p2.population = int64(981);

            
            tc.verifyEqual(...
                tc.mjl.MATFrostTest.largest_population(p1, p2), ...
                p1);
        end

        function simple_struct_vector(tc)
            
            p1 = struct;
            p1.name = "Midgard";
            p1.population = int64(5443);

            p2 = struct;
            p2.name = "Asgard";
            p2.population = int64(981);


            p3 = struct;
            p3.name = "Westeros";
            p3.population = int64(68544);


            p4 = struct;
            p4.name = "Braavos";
            p4.population = int64(23544);

            tc.verifyEqual(...
                tc.mjl.MATFrostTest.largest_population_vector([p1;p2;p3;p4]), ...
                p3);
        end


        function nested_structures_test1(tc)
            
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};
            nest1.v4 = true;

            tc.verifyEqual(...
                tc.mjl.MATFrostTest.sum_nest1(nest1), ...
                3+4+5+6+7);
        end


        function nested_structures1_identity(tc)

            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};
            nest1.v4 = true;

            tc.verifyEqual(...
                tc.mjl.MATFrostTest.nest1_identity(nest1), ...
                nest1);
        end

        
        function nested_structures_test2(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};
            nest1.v4 = true;


            nest2 = struct;
            nest2.v1={nest1;nest1;nest1};
            nest2.vs=repmat(nest1, 50,1);
            
            tc.verifyEqual(...
                tc.mjl.MATFrostTest.sum_nest2(nest2), ...
                (50+3)*(3+4+5+6+7));

        end

        function nested_structures2_identity(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};
            nest1.v4 = true;


            nest2 = struct;
            nest2.v1={nest1;nest1;nest1};
            nest2.vs=repmat(nest1, 50,1);
            
            tc.verifyEqual(...
                tc.mjl.MATFrostTest.nest2_identity(nest2), ...
                nest2);

        end
        function rename_structures_test1(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};       
            nest1.v4 = true;

            
            rin = struct("old_v", nest1, "old_vs", repmat(nest1, 10,1));

            tc.verifyEqual(...
                tc.mjl.MATFrostTest.rename_test1(rin), ...
                struct( ...
                    "action", "Renamed", ...
                    "new_v", nest1, ...
                    "new_vs", repmat(nest1, 10,1) ...
                ));

        end

        function rename_structures_test2(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};       
            nest1.v4 = true;

            
            rin = struct("old_v", nest1, "old_vs", repmat(nest1, 10,1));

            tc.verifyEqual(...
                tc.mjl.MATFrostTest.rename_test1(rin), ...
                struct( ...
                    "action", "Renamed", ...
                    "new_v", nest1, ...
                    "new_vs", repmat(nest1, 10,1) ...
                ));

        end

        function abstract_type_test1(tc)
            
            
            
            tc.verifyEqual(...
                tc.mjl.MATFrostTest.matfrost_abstract_test1(1.3, int64(4)), ...
                struct( ...
                    "v1", 1.3, ...
                    "v2", int64(4)...
                ));

        end
        

        function string_manipulations(tc)
            
            tc.verifyEqual(...
                tc.mjl.MATFrostTest.repeat_string("teststring_😀_", int64(4)), ...
                "teststring_😀_teststring_😀_teststring_😀_teststring_😀_");


        end
        
        function vector_of_strings_concatanation(tc)
            
            tc.verifyEqual(...
                tc.mjl.MATFrostTest.concat_strings(["teststring_😀_"; "_lorem_ipusm_"; "_teststring2_🙁"]), ...
                    "teststring_😀__lorem_ipusm__teststring2_🙁");

        end


        function primitive_logical(tc)
            tc.verifyEqual(...
                    tc.mjl.MATFrostTest.logical_f64_multiplication(true, 8.8), ...
                    8.8);
            tc.verifyEqual(...
                    tc.mjl.MATFrostTest.logical_f64_multiplication(false, 8.8), ...
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
                    tc.mjl.MATFrostTest.("double_scalar_" + ts(i))(vs{i}), vs{i}+vs{i});
            end
        end

        function double_complex_primitive_scalars(tc)
            ts = ["i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
                "f32"; "f64"];

            vs = {...
                int8(22);         uint8(42);...
                int16(3322);      uint16(4532);...
                int32(323442);    uint32(53342);... 
                int64(323434542); uint64(535345342);...
                ...
                single(34.125);   2342.0625};


            % Complex numbers
            for i=1:numel(ts)
                v  = complex(vs{i},   2 * vs{i});
                v2 = complex(2*vs{i}, 4 * vs{i});
                tc.verifyEqual(...
                    tc.mjl.MATFrostTest.("double_scalar_c" + ts(i))(v), v2);
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
                    tc.mjl.MATFrostTest.("double_vector_" + ts(i))(vs{i}), vs{i}+vs{i});
            end
            
        end

        % 
        % function empty_vectors(tc)
        % 
        %     ts = ["i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
        %         "f32"; "f64"];
        % 
        %     % Real numbers
        %     for i=1:numel(ts)
        %         tc.verifyEqual(...
        %             tc.mjl.MATFrostTest.("double_vector_" + ts(i))([]), []);
        % 
        %     end
        % 
        % end

        function double_complex_primitive_vectors(tc)
            
            ts = ["i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
                "f32"; "f64"];

            vs = {...
                int8(11 + (1:10)');         uint8(42 + (1:10)');...
                int16(3322 + (1:10)');      uint16(4532 + (1:10)');...
                int32(323442 + (1:10)');    uint32(53342 + (1:10)');... 
                int64(323434542 + (1:10)'); uint64(535345342 + (1:10)');...
                ...
                single(34.125 + (1:10)');   2342.0625 + (1:10)'};

            % Complex numbers
            for i=1:numel(ts)
                v  = complex(vs{i},   2 * vs{i});
                v2 = complex(2*vs{i}, 4 * vs{i});
                tc.verifyEqual(...
                    tc.mjl.MATFrostTest.("double_vector_c" + ts(i))(v), v2);
            end

        end


        function sum_complex_numbers(tc)
            vr = 2342.0625 + logspace(1,5,100)';
            vi = 345.0625  + logspace(3,4,100)';
            
            v = complex(vr,vi);
            tc.verifyEqual(...
                    tc.mjl.MATFrostTest.("sum_vector_cf64")(v), complex(sum(vr), sum(vi)), "RelTol", 1e-15);
        end

    end

    
end
