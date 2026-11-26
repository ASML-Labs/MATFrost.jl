classdef matfrost_table_test < matfrost_abstract_test
    methods(Test)
        function roundTrip(tc)
            input = table(int64([1; 2]), single([1.5; NaN]), ...
                [true; false], ["alpha"; "beta"], complex([1; 3], [2; -4]), ...
                'VariableNames', {'id', 'value', 'valid', 'label', 'z'});
            for value = {input, input(1, :), input([], :), table(), ...
                    table(int32(7)), table(strings(0, 1))}
                handle = matfrost.tableToDataFrame(tc.mjl, value{1});
                cleanup = onCleanup(@() tc.mjl.MATFrost.release_handle( ...
                    handle, signature="MATFrost.MATFrostHandle"));
                tc.verifyEqual(tc.mjl.DataFrames.nrow(handle, signature=handle.typename), ...
                    int64(height(value{1})));
                tc.verifyEqual(matfrost.dataFrameToTable(tc.mjl, handle), value{1});
                clear cleanup
            end
        end

        function primitiveTypes(tc)
            classes = ["int8", "uint8", "int16", "uint16", "int32", ...
                "uint32", "int64", "uint64", "single", "double"];
            input = table();
            for k = 1:numel(classes)
                input.(classes(k)) = feval(char(classes(k)), [1; 2]);
            end
            input.singleComplex = complex(single([1; 2]), single([3; 4]));
            handle = matfrost.tableToDataFrame(tc.mjl, input);
            cleanup = onCleanup(@() tc.mjl.MATFrost.release_handle( ...
                handle, signature="MATFrost.MATFrostHandle"));
            tc.verifyEqual(matfrost.dataFrameToTable(tc.mjl, handle), input);
        end

        function rejectedColumns(tc)
            tc.verifyError(@() matfrost.tableToDataFrame(tc.mjl, ...
                table([1; 2], [missing; "x"])), 'MATFrost:UnsupportedTableColumn');
            tc.verifyError(@() matfrost.tableToDataFrame(tc.mjl, ...
                table({1; 2})), 'MATFrost:UnsupportedTableColumn');
            tc.verifyError(@() matfrost.tableToDataFrame(tc.mjl, ...
                table([1 2; 3 4])), 'MATFrost:UnsupportedTableColumn');
            withNames = table([1; 2], 'RowNames', {'a', 'b'});
            tc.verifyError(@() matfrost.tableToDataFrame(tc.mjl, withNames), ...
                'MATFrost:UnsupportedTableMetadata');
        end
    end
end
