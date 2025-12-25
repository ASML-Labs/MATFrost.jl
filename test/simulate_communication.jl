using Test
using MATFrost
using MATFrost._Types
using MATFrost._Read:  read_matfrostarray!
using MATFrost._Write: write_matfrostarray!
using MATFrost._ConvertToJulia
using MATFrost._ConvertToMATLAB
using Sockets

@testset "Simulated MATLAB-Julia Communication" begin  
    # Start the server in a separate task
    host = "127.0.0.1"
    port = 10001
    
    server_task = Threads.@spawn begin
        try
            MATFrost.matfrostserve(host, port)
        catch e
            if !(e isa InterruptException)
                @error "Server error" exception=(e, catch_backtrace())
                rethrow(e)
            end
        end
    end    
    # Give server time to start
    sleep(1)

    @test istaskstarted(server_task)

    
    # Try to connect multiple times (server might not be ready immediately)
    client = nothing
    for attempt in 1:50
        try
            client = connect(host, port)
            break
        catch e
            sleep(0.1)
        end
    end
    @test client !== nothing
    
    try
        @testset "Simple Function Call" begin
            # Prepare the call: CallMeta and arguments
            # The call structure is a cell array with 2 elements:
            # 1. CallMeta struct with fully_qualified_name and signature
            # 2. Cell array with function arguments
            
            # Create CallMeta struct
            callmeta_struct = MATFrostArrayStruct(
                Int64[1],  # dims
                Symbol[:fully_qualified_name, :signature],  # field names
                MATFrostArrayAbstract[
                    MATFrostArrayString(Int64[1], String["Base.sum"]),
                    MATFrostArrayString(Int64[1], String["Vector{Float64}"]),
                ]
            )
            
            # Create arguments cell array
            args_cell = MATFrostArrayCell(
                Int64[1],  # 1 argument
                MATFrostArrayAbstract[
                    MATFrostArrayPrimitive{Float64}(Int64[2], Float64[5.0, 3.0])
                ]
            )
            
            # Combine into call structure
            call_struct = MATFrostArrayCell(
                Int64[2],  # 2 elements
                MATFrostArrayAbstract[callmeta_struct, args_cell]
            )

            # Send the request
            write_matfrostarray!(client, call_struct)
            flush(client)
            
            # Read the response
            response = read_matfrostarray!(client)
            
            # The response should be a struct with status, log, and value fields
            @test response isa MATFrostArrayStruct
            @test response.fieldnames == Symbol[:status, :log, :value]
            
            # Extract status
            status = _ConvertToJulia.convert_matfrostarray(String, response.values[1])
            @test status == "SUCCESFUL"
            
            # Extract result value
            result = _ConvertToJulia.convert_matfrostarray(Float64, response.values[3])
            @test result ≈ 8.0
        end
        
    finally
        close(client)
        # Stop the server
        schedule(server_task, InterruptException(), error=true)
    end
    
    # @testset "Error Handling - Nonexistent Function" begin
    #     socket_path = tempname() * ".sock"
        
    #     server_task = @async begin
    #         try
    #             MATFrost.matfrostserve(pipe_path)
    #         catch e
    #             if !(e isa InterruptException)
    #                 @error "Server error" exception=(e, catch_backtrace())
    #             end
    #         end
    #     end
        
    #     sleep(1)
        
    #     # Connect client
    #     @static if Sys.iswindows()
    #         pipe_name = basename(socket_path)
    #         pipe_name = replace(pipe_name, r"\.(sock|socket)$" => "")
    #         pipe_path = "\\\\.\\pipe\\matfrost_$(pipe_name)"
            
    #         client = nothing
    #         for attempt in 1:50
    #             try
    #                 client = connect(pipe_path)
    #                 break
    #             catch e
    #                 sleep(0.1)
    #             end
    #         end
    #         @test client !== nothing
    #     else
    #         client = connect(socket_path)
    #     end
        
    #     try
    #         # Call a non-existent function
    #         callmeta_struct = MATFrostArrayStruct(
    #             Int64[1],
    #             Symbol[:fully_qualified_name, :signature],
    #             MATFrostArrayAbstract[
    #                 MATFrostArrayString(Int64[1], String["NonExistent.function"]),
    #                 MATFrostArrayString(Int64[0], String[])
    #             ]
    #         )
            
    #         args_cell = MATFrostArrayCell(Int64[0], MATFrostArrayAbstract[])
    #         call_struct = MATFrostArrayCell(
    #             Int64[2],
    #             MATFrostArrayAbstract[callmeta_struct, args_cell]
    #         )
            
    #         write_matfrostarray!(client, call_struct)
    #         flush(client)
            
    #         response = read_matfrostarray!(client)
            
    #         @test response isa MATFrostArrayStruct
    #         status = _ConvertToJulia.convert_matfrostarray(String, response.values[1])
    #         @test status == "ERROR"
            
    #         # The error value should be a MATFrostException struct
    #         error_struct = response.values[3]
    #         @test error_struct isa MATFrostArrayStruct
    #         @test :id in error_struct.fieldnames
    #         @test :message in error_struct.fieldnames
            
    #         println("✓ Error handling works correctly for nonexistent function")
            
    #     finally
    #         close(client)
    #         try
    #             schedule(server_task, InterruptException(), error=true)
    #         catch
    #         end
    #     end
    # end
    
    # @testset "Multiple Sequential Calls" begin
    #     module TestModule2
    #         square(x::Float64) = x * x
    #         cube(x::Float64) = x * x * x
    #     end
        
    #     socket_path = tempname() * ".sock"
        
    #     server_task = @async begin
    #         try
    #             MATFrost.matfrostserve(socket_path)
    #         catch e
    #             if !(e isa InterruptException)
    #                 @error "Server error" exception=(e, catch_backtrace())
    #             end
    #         end
    #     end
        
    #     sleep(1)
        
    #     # Connect client
    #     @static if Sys.iswindows()
    #         pipe_name = basename(socket_path)
    #         pipe_name = replace(pipe_name, r"\.(sock|socket)$" => "")
    #         pipe_path = "\\\\.\\pipe\\matfrost_$(pipe_name)"
            
    #         client = nothing
    #         for attempt in 1:50
    #             try
    #                 client = connect(pipe_path)
    #                 break
    #             catch e
    #                 sleep(0.1)
    #             end
    #         end
    #         @test client !== nothing
    #     else
    #         client = connect(socket_path)
    #     end
        
    #     try
    #         # First call: square(4.0)
    #         callmeta1 = MATFrostArrayStruct(
    #             Int64[1],
    #             Symbol[:fully_qualified_name, :signature],
    #             MATFrostArrayAbstract[
    #                 MATFrostArrayString(Int64[1], String["TestModule2.square"]),
    #                 MATFrostArrayString(Int64[0], String[])
    #             ]
    #         )
    #         args1 = MATFrostArrayCell(
    #             Int64[1],
    #             MATFrostArrayAbstract[MATFrostArrayPrimitive{Float64}(Int64[1], Float64[4.0])]
    #         )
    #         call1 = MATFrostArrayCell(Int64[2], MATFrostArrayAbstract[callmeta1, args1])
            
    #         write_matfrostarray!(client, call1)
    #         flush(client)
    #         response1 = read_matfrostarray!(client)
            
    #         status1 = _ConvertToJulia.convert_matfrostarray(String, response1.values[1])
    #         @test status1 == "SUCCESFUL"
    #         result1 = _ConvertToJulia.convert_matfrostarray(Float64, response1.values[3])
    #         @test result1 ≈ 16.0
            
    #         println("✓ First call: square(4.0) = $result1")
            
    #         # Second call: cube(3.0)
    #         callmeta2 = MATFrostArrayStruct(
    #             Int64[1],
    #             Symbol[:fully_qualified_name, :signature],
    #             MATFrostArrayAbstract[
    #                 MATFrostArrayString(Int64[1], String["TestModule2.cube"]),
    #                 MATFrostArrayString(Int64[0], String[])
    #             ]
    #         )
    #         args2 = MATFrostArrayCell(
    #             Int64[1],
    #             MATFrostArrayAbstract[MATFrostArrayPrimitive{Float64}(Int64[1], Float64[3.0])]
    #         )
    #         call2 = MATFrostArrayCell(Int64[2], MATFrostArrayAbstract[callmeta2, args2])
            
    #         write_matfrostarray!(client, call2)
    #         flush(client)
    #         response2 = read_matfrostarray!(client)
            
    #         status2 = _ConvertToJulia.convert_matfrostarray(String, response2.values[1])
    #         @test status2 == "SUCCESFUL"
    #         result2 = _ConvertToJulia.convert_matfrostarray(Float64, response2.values[3])
    #         @test result2 ≈ 27.0
            
    #         println("✓ Second call: cube(3.0) = $result2")
            
    #     finally
    #         close(client)
    #         try
    #             schedule(server_task, InterruptException(), error=true)
    #         catch
    #         end
    #     end
    # end
end
