classdef matfrost_exception_not_scalar_value_test < matfrost_abstract_test
    
    
    properties (TestParameter)
        prim_type = {"string";
                "simple_population_type";
                "i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
                "f32"; "f64"; ...
                "ci8"; "cui8"; "ci16"; "cui16"; "ci32"; "cui32"; "ci64"; "cui64"; ...
                "cf32"; "cf64"};

        v = {...
                "test";
                struct("name", "Test", "population", int64(200));
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

        function identity_sanity(tc, prim_type, v)
            tc.verifyEqual(tc.mjl.MATFrostTest.("identity_" + prim_type)(v), v);
        end

        function error_empty_input(tc, prim_type, v)
            if isnumeric(v)
                if isreal(v)
                    vempty = zeros(0,0, class(v));
                else
                    vempty = complex(zeros(0,0, class(v)));
                end
            else
                vempty = v([]);
            end
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_" + prim_type)(vempty), 'matfrostjulia:conversion:notScalarValue');
        end

        function error_vector_numel_larger_than_1(tc, prim_type, v)
            vs = [v;v];
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_" + prim_type)(vs), 'matfrostjulia:conversion:notScalarValue');
        end

        function error_matrix_numel_larger_than_1(tc, prim_type, v)
            vs = [v, v; v, v];
            tc.verifyError(@() tc.mjl.MATFrostTest.("identity_" + prim_type)(vs), 'matfrostjulia:conversion:notScalarValue');
        end



    end
    
end