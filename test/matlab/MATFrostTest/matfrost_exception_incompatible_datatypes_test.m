classdef matfrost_exception_incompatible_datatypes_test < matfrost_abstract_test
% Test the behaviour of calling functions with arguments of different
% datatypes. In this case exceptions should be thrown of incompatible
% datatypes. A matrix is created on one side a set of values (vs) and on the
% other side the corresponding jltypes. The pairs in this matrix which
% should be incompatible are tested.



    properties (Constant)
        jltypes = {
            "bool"; 
            "string";
            "tup_f64_i64_bool_string";  % 
            "i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
            "f32"; "f64"; ...
            "ci8"; "cui8"; "ci16"; "cui16"; "ci32"; "cui32"; "ci64"; "cui64"; ...
            "cf32"; "cf64";
            
            "simple_population_type";
            "named_tuple_simple_population_type"};

        vs = {...
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
    
    methods (Static)
        function pairs = incompatible_datatypes()
            vals    = matfrost_exception_incompatible_datatypes_test.vs;
            jltypes = matfrost_exception_incompatible_datatypes_test.jltypes;


            val     = repmat(vals, 1, length(jltypes));
            val = val(:);

            jltype  = repmat(jltypes', length(vals), 1);
            jltype = jltype(:);

            bincompatible = true(length(val),1);

            % Remove the compatible pairs, which are on the diagonal. 
            bincompatible(1: (length(vals)+1):end) = false;

            % Remove (Struct value) -> (Named Tuple)
            bincompatible(end) = false;

            pairs.val = val(bincompatible);
            pairs.jltype= jltype(bincompatible);
        end

    end


    properties (TestParameter)

       val    = matfrost_exception_incompatible_datatypes_test.incompatible_datatypes().val;
       jltype = matfrost_exception_incompatible_datatypes_test.incompatible_datatypes().jltype;
        
    end

    


    
    methods(Test, ParameterCombination="sequential")

        function scalar_val_scalar_jltype_incompatible_datatypes(tc, val, jltype)
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_" + jltype)(val), 'matfrostjulia:conversion:incompatibleDatatypes');
        end

        function vector_val_vector_jltype_incompatible_datatypes(tc, val, jltype)
            if iscell(val)
                vals = repmat({val}, 5, 1);
            else
                vals = repmat(val, 5, 1);
            end
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_vector_" + jltype)(vals), 'matfrostjulia:conversion:incompatibleDatatypes');
        end

        function matrix_val_matrix_jltype_incompatible_datatypes(tc, val, jltype)
            if iscell(val)
                vals = repmat({val}, 5, 5);
            else
                vals = repmat(val, 5, 5);
            end
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_matrix_" + jltype)(vals), 'matfrostjulia:conversion:incompatibleDatatypes');
        end

    end
    
end