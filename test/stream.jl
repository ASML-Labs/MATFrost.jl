module StreamTest

using Test
using JET

using MATFrost._Stream: Buffer, BufferedUDS, write!, read!, flush!, discard!, memcpy_mat


@testset "Stream-Buffer-Write-Read-Numbers" begin

    @testset "Write-Read-Float64" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, 42.5)
        @test buffer.available == 8

        val = read!(stream, Float64)
        @test val == 42.5
        @test buffer.position == 8
    end

    @testset "Write-Read-Float32" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, Float32(42.5))
        @test buffer.available == 4

        val = read!(stream, Float32)
        @test val == Float32(42.5)
    end

    @testset "Write-Read-Int8" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, Int8(-42))
        @test buffer.available == 1

        val = read!(stream, Int8)
        @test val == Int8(-42)
    end

    @testset "Write-Read-UInt8" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, UInt8(255))
        @test buffer.available == 1

        val = read!(stream, UInt8)
        @test val == UInt8(255)
    end

    @testset "Write-Read-Int16" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, Int16(-1234))
        @test buffer.available == 2

        val = read!(stream, Int16)
        @test val == Int16(-1234)
    end

    @testset "Write-Read-UInt16" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, UInt16(1234))
        @test buffer.available == 2

        val = read!(stream, UInt16)
        @test val == UInt16(1234)
    end

    @testset "Write-Read-Int32" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, Int32(-123456))
        @test buffer.available == 4

        val = read!(stream, Int32)
        @test val == Int32(-123456)
    end

    @testset "Write-Read-UInt32" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, UInt32(123456))
        @test buffer.available == 4

        val = read!(stream, UInt32)
        @test val == UInt32(123456)
    end

    @testset "Write-Read-Int64" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, Int64(-123456789))
        @test buffer.available == 8

        val = read!(stream, Int64)
        @test val == Int64(-123456789)
    end

    @testset "Write-Read-UInt64" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, UInt64(123456789))
        @test buffer.available == 8

        val = read!(stream, UInt64)
        @test val == UInt64(123456789)
    end

    @testset "Write-Read-Complex-Float64" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, Complex{Float64}(1.5, 2.5))
        @test buffer.available == 16

        val = read!(stream, Complex{Float64})
        @test val == Complex{Float64}(1.5, 2.5)
    end

    @testset "Write-Read-Complex-Float32" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, Complex{Float32}(1.5, 2.5))
        @test buffer.available == 8

        val = read!(stream, Complex{Float32})
        @test val == Complex{Float32}(1.5, 2.5)
    end
end


@testset "Stream-Buffer-Write-Read-Arrays" begin

    @testset "Write-Read-Float64-Array" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        arr_write = [1.0, 2.0, 3.0, 4.0, 5.0]
        write!(stream, arr_write)
        @test buffer.available == 40  # 5 * 8 bytes

        arr_read = Vector{Float64}(undef, 5)
        read!(stream, arr_read)
        @test arr_read == arr_write
    end

    @testset "Write-Read-Int32-Array" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        arr_write = Int32[10, 20, 30, 40]
        write!(stream, arr_write)
        @test buffer.available == 16  # 4 * 4 bytes

        arr_read = Vector{Int32}(undef, 4)
        read!(stream, arr_read)
        @test arr_read == arr_write
    end

    @testset "Write-Read-Bool-Array" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        arr_write = [true, false, true, false, true]
        write!(stream, arr_write)
        @test buffer.available == 5  # 5 * 1 byte

        arr_read = Vector{Bool}(undef, 5)
        read!(stream, arr_read)
        @test arr_read == arr_write
    end

    @testset "Write-Read-Complex-Array" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        arr_write = [Complex{Float64}(1.0, 2.0), Complex{Float64}(3.0, 4.0)]
        write!(stream, arr_write)
        @test buffer.available == 32  # 2 * 16 bytes

        arr_read = Vector{Complex{Float64}}(undef, 2)
        read!(stream, arr_read)
        @test arr_read == arr_write
    end

    @testset "Write-Read-Large-Array" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024 * 100), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        arr_write = collect(Float64(i) for i in 1:10000)
        write!(stream, arr_write)
        @test buffer.available == 80000  # 10000 * 8 bytes

        arr_read = Vector{Float64}(undef, 10000)
        read!(stream, arr_read)
        @test arr_read == arr_write
    end

    @testset "Write-Read-Empty-Array" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        arr_write = Float64[]
        write!(stream, arr_write)
        @test buffer.available == 0

        arr_read = Float64[]
        read!(stream, arr_read)
        @test arr_read == arr_write
    end
end


@testset "Stream-Buffer-Write-Read-Strings" begin

    @testset "Write-Read-Simple-String" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        str_write = "hello"
        write!(stream, str_write)
        # 8 bytes for length + 5 bytes for string
        @test buffer.available == 13

        str_read = read!(stream, String)
        @test str_read == str_write
    end

    @testset "Write-Read-Empty-String" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        str_write = ""
        write!(stream, str_write)
        @test buffer.available == 8  # Just the length

        str_read = read!(stream, String)
        @test str_read == str_write
    end

    @testset "Write-Read-Unicode-String" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        str_write = "Hello 世界 🚀"
        write!(stream, str_write)
        expected_bytes = ncodeunits(str_write)
        @test buffer.available == 8 + expected_bytes

        str_read = read!(stream, String)
        @test str_read == str_write
    end

    @testset "Write-Read-Long-String" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024 * 10), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        str_write = repeat("abcdefghij", 100)  # 1000 characters
        write!(stream, str_write)
        @test buffer.available == 8 + 1000

        str_read = read!(stream, String)
        @test str_read == str_write
    end
end


@testset "Stream-Buffer-Multiple-Operations" begin

    @testset "Write-Multiple-Read-Multiple" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        # Write multiple values
        write!(stream, Int32(42))
        write!(stream, Float64(3.14))
        write!(stream, "test")
        write!(stream, UInt8(255))

        # Read them back in order
        val1 = read!(stream, Int32)
        val2 = read!(stream, Float64)
        val3 = read!(stream, String)
        val4 = read!(stream, UInt8)

        @test val1 == Int32(42)
        @test val2 == 3.14
        @test val3 == "test"
        @test val4 == UInt8(255)
    end

    @testset "Interleaved-Write-Read" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        write!(stream, Float64(1.5))
        val1 = read!(stream, Float64)
        @test val1 == 1.5

        write!(stream, Int32(100))
        val2 = read!(stream, Int32)
        @test val2 == Int32(100)

        write!(stream, "hello")
        val3 = read!(stream, String)
        @test val3 == "hello"
    end
end


@testset "Stream-Buffer-Discard" begin

    @testset "Discard-Bytes" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        # Write some data
        write!(stream, Float64(1.0))
        write!(stream, Float64(2.0))
        write!(stream, Float64(3.0))

        # Read first value
        val1 = read!(stream, Float64)
        @test val1 == 1.0

        # Discard the second value (8 bytes)
        discard!(stream, 8)

        # Read the third value
        val3 = read!(stream, Float64)
        @test val3 == 3.0
    end

    @testset "Discard-Multiple" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        # Write array of 10 Int32 values
        arr = Int32[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        write!(stream, arr)

        # Discard first 5 values (20 bytes)
        discard!(stream, 20)

        # Read remaining 5 values
        remaining = Vector{Int32}(undef, 5)
        read!(stream, remaining)
        @test remaining == Int32[6, 7, 8, 9, 10]
    end
end


@testset "Stream-Buffer-EdgeCases" begin

    @testset "Buffer-Position-Tracking" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        initial_pos = buffer.position
        initial_avail = buffer.available

        write!(stream, Float64(42.0))
        @test buffer.available == initial_avail + 8
        @test buffer.position == initial_pos

        val = read!(stream, Float64)
        @test buffer.position == initial_pos + 8
    end

    @testset "Sequential-Writes" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        for i in 1:100
            write!(stream, Int32(i))
        end

        @test buffer.available == 400  # 100 * 4 bytes

        for i in 1:100
            val = read!(stream, Int32)
            @test val == Int32(i)
        end
    end

    @testset "Write-Read-Zero-Length-Array" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        stream = BufferedUDS(C_NULL, buffer, buffer)

        arr_write = Float64[]
        write!(stream, arr_write)

        arr_read = Float64[]
        read!(stream, arr_read)

        @test length(arr_read) == 0
    end
end


@testset "Stream-Memcpy" begin

    @testset "Memcpy-Basic" begin
        src = UInt8[1, 2, 3, 4, 5]
        dest = Vector{UInt8}(undef, 5)

        memcpy_mat(pointer(dest), pointer(src), Csize_t(5))

        @test dest == src
    end

    @testset "Memcpy-Int64-Size" begin
        src = UInt8[10, 20, 30, 40]
        dest = Vector{UInt8}(undef, 4)

        memcpy_mat(pointer(dest), pointer(src), Int64(4))

        @test dest == src
    end

    @testset "Memcpy-Large-Block" begin
        src = collect(UInt8(i % 256) for i in 1:1000)
        dest = Vector{UInt8}(undef, 1000)

        memcpy_mat(pointer(dest), pointer(src), Csize_t(1000))

        @test dest == src
    end
end


@testset "Stream-Buffer-State" begin

    @testset "Buffer-Initialization" begin
        buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)

        @test buffer.position == 0
        @test buffer.available == 0
        @test length(buffer.data) == 1024
    end

    @testset "Buffer-Custom-Size" begin
        buffer = Buffer(Vector{UInt8}(undef, 2048), 0, 0)

        @test length(buffer.data) == 2048
    end

    @testset "BufferedUDS-Initialization" begin
        in_buffer = Buffer(Vector{UInt8}(undef, 1024), 0, 0)
        out_buffer = Buffer(Vector{UInt8}(undef, 2048), 0, 0)
        stream = BufferedUDS(C_NULL, in_buffer, out_buffer)

        @test stream.input === in_buffer
        @test stream.output === out_buffer
    end
end

end
