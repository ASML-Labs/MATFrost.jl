classdef matfrost_nested_structures_test < matfrost_abstract_test
% Deep nested structures are created and reconfigured arbitrarily on Julia
% side.
    
    properties (TestParameter)
        jltype = {"bool";
                "string";
                
                "simple_population_type";
                "named_tuple_simple_population_type";

                "tup_f64_i64_bool_string";

                "i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
                "f32"; "f64"; ...
                "ci8"; "cui8"; "ci16"; "cui16"; "ci32"; "cui32"; "ci64"; "cui64"; ...
                "cf32"; "cf64"};

        val = {...
                false;
                "test";
                ...
                struct("name", "Test", "population", int64(200));
                struct("name", "Test", "population", int64(200));

                {3.0; int64(3); true; "Test"};
                ...
                int8(8);          uint8(14);
                int16(478);       uint16(4532);
                int32(323442);    uint32(53342);
                int64(323434542); uint64(535345342);
                ...
                single(34.125);   2342.0625;
                ...
                complex(int8(8), int8(12));          
                complex(uint8(14), uint8(7));
                complex(int16(478), int16(124));
                complex(uint16(4532), uint16(544));
                complex(int32(323442), int32(74571));
                complex(uint32(53342), uint32(56123));... 
                complex(int64(323434542), int64(84968213));
                complex(uint64(535345342), uint64(8492313));...
                ...
                complex(single(34.125), single(4234.5));  
                complex(2342.0625, 12444.0625)}; 
        
    end



    methods(Test, ParameterCombination="sequential")
        % Test methods
        
        function nested_structures_test1_scalars(tc, jltype, val)

            nest3_l3.v1 = val;
            nest3_l3.v2 = 3.0;
            nest3_l3.v3 = int64(23);


            nest3_l2.v1 = val;
            if iscell(val)
                nest3_l2.v2 = repmat({val}, 10,1);
            else
                nest3_l2.v2 = repmat(val, 10,1);
            end
            nest3_l2.v3 = repmat(nest3_l3, 10,1);

            nest3_l1.v1 = int64(23);
            nest3_l1.v2 = 323.0;
            nest3_l1.v3 = val;
            nest3_l1.v4 = repmat({val}, 3,1);
            if iscell(val)
                nest3_l1.v5 = repmat({val}, 5,1);
                nest3_l1.v6 = repmat({val}, 5,5);
            else
                nest3_l1.v5 = repmat(val, 5,1);
                nest3_l1.v6 = repmat(val, 5,5);
            end
             
            nest3_l1.v7 = nest3_l2;
            nest3_l1.v8 = repmat(nest3_l2, 10,1);


            nest4_o.v1 = nest3_l1.v2;
            nest4_o.v2 = nest3_l1.v1;
            nest4_o.v3 = repmat(nest3_l1, 2,2,2);
            nest4_o.v4 = nest3_l1.v3;
            nest4_o.v5 = nest3_l1.v7;

            tc.verifyEqual(...
                tc.mjl.MATFrostTest.("nested_structures_test1_scalar_" + jltype)(nest3_l1), ...
                nest4_o);

        end


        function nested_structures_test1_vectors(tc, jltype, val)

            if iscell(val)
                val = repmat({val}, 5,1);
            else
                val = repmat(val, 5,1);
            end

            nest3_l3.v1 = val;
            nest3_l3.v2 = 3.0;
            nest3_l3.v3 = int64(23);


            nest3_l2.v1 = val;
%             if iscell(val)
                nest3_l2.v2 = repmat({val}, 10,1);
%             else
%                 nest3_l2.v2 = repmat(val, 10,1);
%             end
            nest3_l2.v3 = repmat(nest3_l3, 10,1);

            nest3_l1.v1 = int64(23);
            nest3_l1.v2 = 323.0;
            nest3_l1.v3 = val;
            nest3_l1.v4 = repmat({val}, 3,1);
%             if iscell(val)
                nest3_l1.v5 = repmat({val}, 5,1);
                nest3_l1.v6 = repmat({val}, 5,5);
%             else
%                 nest3_l1.v5 = repmat(val, 5,1);
%                 nest3_l1.v6 = repmat(val, 5,5);
%             end
%              
            nest3_l1.v7 = nest3_l2;
            nest3_l1.v8 = repmat(nest3_l2, 10,1);


            nest4_o.v1 = nest3_l1.v2;
            nest4_o.v2 = nest3_l1.v1;
            nest4_o.v3 = repmat(nest3_l1, 2,2,2);
            nest4_o.v4 = nest3_l1.v3;
            nest4_o.v5 = nest3_l1.v7;

            tc.verifyEqual(...
                tc.mjl.MATFrostTest.("nested_structures_test1_vector_" + jltype)(nest3_l1), ...
                nest4_o);

        end




    end
    
end