classdef matfrost_exception_incompatible_array_dimensions_test < matfrost_abstract_test


    properties (TestParameter)
        jltype = {
            "bool"; 
            "string";
            "tup_f64_i64_bool_string";  
            "i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
            "f32"; "f64"; ...
            "ci8"; "cui8"; "ci16"; "cui16"; "ci32"; "cui32"; "ci64"; "cui64"; ...
            "cf32"; "cf64";
            
            "simple_population_type";
            "named_tuple_simple_population_type"};

        val = {...
                true;
                "test";
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
                complex(uint32(53342), uint32(56123));
                complex(int64(323434542), int64(84968213));
                complex(uint64(535345342), uint64(8492313));
                ...
                complex(single(34.125), single(4234.5));  
                complex(2342.0625, 12444.0625);
                ...
                struct("name", "Test", "population", int64(200))}; 
        
    end
   
   
    methods(Test, ParameterCombination="exhaustive")
       
        function row_vector_error(tc, val, jltype)
            if iscell(val)
                vs = repmat({val}, 1, 5);
            else
                vs = repmat(val, 1, 5);
            end
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_vector_" + jltype)(vs), 'matfrostjulia:conversion:incompatibleArrayDimensions');
        end

        function matrix_value_to_vector_type_error(tc, val, jltype)
            if iscell(val)
                vs = repmat({val}, 5, 5);
            else
                vs = repmat(val, 5, 5);
            end
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_vector_" + jltype)(vs), 'matfrostjulia:conversion:incompatibleArrayDimensions');
        end

        function arr3_value_to_matrix_type_error(tc, val, jltype)
            if iscell(val)
                vs = repmat({val}, 5, 5, 5);
            else
                vs = repmat(val, 5, 5, 5);
            end
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_matrix_" + jltype)(vs), 'matfrostjulia:conversion:incompatibleArrayDimensions');
        end

        function arr4_value_to_arr3_type_error(tc, val, jltype)
            if iscell(val)
                vs = repmat({val}, 5, 5, 5, 5);
            else
                vs = repmat(val, 5, 5, 5, 5);
            end
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_arr3_" + jltype)(vs), 'matfrostjulia:conversion:incompatibleArrayDimensions');
        end

    end
end
