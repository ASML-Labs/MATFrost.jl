
module _Write


using .._Constants
using .._Types


@noinline function write_matfrostarray_empty!(io::IO, ::MATFrostArrayEmpty)
    write(io, DOUBLE)
    write(io, 1)
    write(io, 0)
end

@noinline function write_matfrostarray_primitive!(io::IO, marr::MATFrostArrayPrimitive{T}) where {T<: Number}
    write(io, matlab_type(T))
    write(io, length(marr.dims))
    for dim in marr.dims
        write(io, dim)
    end
    write(io, marr.values)
end

@noinline function write_matfrostarray_string!(io::IO, marr::MATFrostArrayString)
    write(io, MATLAB_STRING)
    write(io, length(marr.dims))
    for dim in marr.dims
        write(io, dim)
    end
    for s in marr.values
        write(io, s)
    end
end

@noinline function write_matfrostarray_cell!(io::IO, marr::MATFrostArrayCell)
    write(io, CELL)
    write(io, length(marr.dims))
    for dim in marr.dims
        write(io, dim)
    end

    for v in marr.values
        write_matfrostarray!(io, v)
    end
end

@noinline function write_matfrostarray_struct!(io::IO, marr::MATFrostArrayStruct)
    write(io, STRUCT)
    write(io, length(marr.dims))
    for dim in marr.dims
        write(io, dim)
    end

    write(io, length(marr.fieldnames))
    for fn in marr.fieldnames
        write(io, String(fn))
    end

    for v in marr.values
        write_matfrostarray!(io, v)
    end
end

@noinline function write_matfrostarray!(io::IO, @nospecialize(marr::MATFrostArrayAbstract))
    if marr isa MATFrostArrayEmpty
        write_matfrostarray_empty!(io, marr)

    elseif marr isa MATFrostArrayStruct
        write_matfrostarray_struct!(io, marr)

    elseif marr isa MATFrostArrayCell
        write_matfrostarray_cell!(io, marr)

    elseif marr isa MATFrostArrayString
        write_matfrostarray_string!(io, marr)
        
    elseif marr isa MATFrostArrayPrimitive{Bool}
        write_matfrostarray_primitive!(io, marr)

    elseif marr isa MATFrostArrayPrimitive{Float64}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Float32}
        write_matfrostarray_primitive!(io, marr)

    elseif marr isa MATFrostArrayPrimitive{Complex{Float64}}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{Float32}}
        write_matfrostarray_primitive!(io, marr)

    elseif marr isa MATFrostArrayPrimitive{Int8}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{UInt8}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Int16}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{UInt16}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Int32}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{UInt32}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Int64}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{UInt64}
        write_matfrostarray_primitive!(io, marr)

    elseif marr isa MATFrostArrayPrimitive{Complex{Int8}}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{UInt8}}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{Int16}}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{UInt16}}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{Int32}}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{UInt32}}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{Int64}}
        write_matfrostarray_primitive!(io, marr)
    elseif marr isa MATFrostArrayPrimitive{Complex{UInt64}}
        write_matfrostarray_primitive!(io, marr)
    else
        error("Unrecoverable crash - MATFrost communication channel corrupted at write side")
    end


end


end