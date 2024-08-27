classdef matfrost_union_type_unpacking_test < matfrost_abstract_test
    
    
    properties (TestParameter)
        prim_type = {"bool";
                "string";
                "simple_population_type";
                "named_tuple_simple_population_type";
                "i8"; "ui8"; "i16"; "ui16"; "i32"; "ui32"; "i64"; "ui64"; ...
                "f32"; "f64"; ...
                "ci8"; "cui8"; "ci16"; "cui16"; "ci32"; "cui32"; "ci64"; "cui64"; ...
                "cf32"; "cf64"};

        v = {...
                false;
                "test";
                ...
                struct("name", "Test", "population", int64(200));
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

        function ifelse_scalar_union_value(tc, prim_type, v)
           
            tc.verifyEqual( ...
                tc.mjl.MATFrostTest.("ifelse_" + prim_type)(true, v, ["If"; "Else"]), ...
                v);

            tc.verifyEqual( ...
                tc.mjl.MATFrostTest.("ifelse_" + prim_type)(false, v, ["If"; "Else"]), ...
                ["If"; "Else"]);
        end

% jorisbelier: Disabled until satisfactory Julia implementation found.
%
%         function interleave_with_number_and_string(tc, prim_type, v)
%             vs = repmat(v, 5, 1);
% 
%             vnum = 321.0;
% 
%             vstring = "interleaved";
% 
%             vo = repmat({v; vnum; vstring}, 5, 1);
% 
%             tc.verifyEqual(tc.mjl.MATFrostTest.("interleave_with_number_and_string_" + prim_type)(vs, vnum, vstring), vo);
%         end


    end
    
end