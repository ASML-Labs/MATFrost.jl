using UUIDs

struct MATFrostHandle <: _Types.MATFrostArrayAbstract
    id::UUID
    typename::String
end

use_matfrost_handle(::Type) = false

const HANDLE_STORE = Dict{UUID,Any}()
const HANDLE_STORE_LOCK = ReentrantLock()

function store_handle(value)::MATFrostHandle
    handle = MATFrostHandle(
        uuid4(),
        string(typeof(value)),
    )

    lock(HANDLE_STORE_LOCK) do
        HANDLE_STORE[handle.id] = value
    end

    return handle
end

function resolve_handle(handle::MATFrostHandle)
    return lock(HANDLE_STORE_LOCK) do
        haskey(HANDLE_STORE, handle.id) ||
            throw(
                ArgumentError(
                    "Invalid or released MATFrost handle: $(handle.id)",
                ),
            )

        HANDLE_STORE[handle.id]
    end
end

function release_handle(handle::MATFrostHandle)::Bool
    return lock(HANDLE_STORE_LOCK) do
        pop!(HANDLE_STORE, handle.id, nothing) !== nothing
    end
end

release_handle(id::UUID) =
    release_handle(MATFrostHandle(id, ""))

function release_all_handles!()
    lock(HANDLE_STORE_LOCK) do
        empty!(HANDLE_STORE)
    end

    return nothing
end

handle_count() = lock(HANDLE_STORE_LOCK) do
    length(HANDLE_STORE)
end