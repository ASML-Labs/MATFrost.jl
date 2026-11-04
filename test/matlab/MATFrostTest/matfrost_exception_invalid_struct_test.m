classdef matfrost_exception_invalid_struct_test < matfrost_abstract_test

   
    methods (Test)

        function nest2_sanity(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};
            nest1.v4 = true;


            nest2 = struct;
            nest2.v1={nest1;nest1;nest1};
            nest2.vs=repmat(nest1, 50,1);
            
            tc.verifyEqual(...
                tc.mjl.MATFrostTest.identity_nest2(nest2), ...
                nest2);

        end

        function top_struct_missing_field(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};
            nest1.v4 = true;


            nest2 = struct;
            nest2.v1={nest1;nest1;nest1};
%             nest2.vs=repmat(nest1, 50,1);

            tc.verifyError(@() tc.mjl.MATFrostTest.identity_nest2(nest2), 'matfrostjulia:conversion:missingFields');


        end
        % 
        % function top_struct_additional_field(tc)
        %     nest1 = struct;
        %     nest1.v1 = 3.0;
        %     nest1.v2 = int64(4);
        %     nest1.v3 = {5; int64(6); int32(7)};
        %     nest1.v4 = true;
        % 
        % 
        %     nest2 = struct;
        %     nest2.v1={nest1;nest1;nest1};
        %     nest2.vs=repmat(nest1, 50,1);
        %     nest2.a = 23;
        % 
        %     tc.verifyError(@() tc.mjl.MATFrostTest.identity_nest2(nest2), 'matfrostjulia:conversion:additionalFields');
        % 
        % 
        % end

        function nested_struct_missing_field(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};
            nest1.v4 = true;

            nest1missing = rmfield(nest1, "v2");          

            nest2 = struct;
            nest2.v1={nest1;nest1missing;nest1};
            nest2.vs=repmat(nest1, 50,1);

            tc.verifyError(@() tc.mjl.MATFrostTest.identity_nest2(nest2), 'matfrostjulia:conversion:missingFields');


        end

        % function nested_struct_additional_field(tc)
        %     nest1 = struct;
        %     nest1.v1 = 3.0;
        %     nest1.v2 = int64(4);
        %     nest1.v3 = {5; int64(6); int32(7)};
        %     nest1.v4 = true;
        % 
        %     nest1additional = nest1;
        %     nest1additional.v5 = 2323;
        % 
        %     nest2 = struct;
        %     nest2.v1={nest1;nest1additional;nest1};
        %     nest2.vs=repmat(nest1, 50,1);
        % 
        %     tc.verifyError(@() tc.mjl.MATFrostTest.identity_nest2(nest2), 'matfrostjulia:conversion:additionalFields');
        % 
        % 
        % end



        function array_struct_missing_field(tc)
            nest1 = struct;
            nest1.v1 = 3.0;
            nest1.v2 = int64(4);
            nest1.v3 = {5; int64(6); int32(7)};
            nest1.v4 = true;

            nest1missing = rmfield(nest1, "v2");          

            nest2 = struct;
            nest2.v1={nest1;nest1;nest1};
            nest2.vs=repmat(nest1missing, 50,1);

            tc.verifyError(@() tc.mjl.MATFrostTest.identity_nest2(nest2), 'matfrostjulia:conversion:missingFields');


        end

        % function array_struct_additional_field(tc)
        %     nest1 = struct;
        %     nest1.v1 = 3.0;
        %     nest1.v2 = int64(4);
        %     nest1.v3 = {5; int64(6); int32(7)};
        %     nest1.v4 = true;
        % 
        %     nest1additional = nest1;
        %     nest1additional.v5 = 2323;
        % 
        %     nest2 = struct;
        %     nest2.v1={nest1;nest1;nest1};
        %     nest2.vs=repmat(nest1additional, 50,1);
        % 
        %     tc.verifyError(@() tc.mjl.MATFrostTest.identity_nest2(nest2), 'matfrostjulia:conversion:additionalFields');
        % 
        % 
        % end



    end
    
end