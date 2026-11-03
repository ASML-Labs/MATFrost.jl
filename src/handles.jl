using UUIDs

struct MATFrostHandle
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

function resolve_handle(id::UUID)
    return lock(HANDLE_STORE_LOCK) do
        haskey(HANDLE_STORE, id) ||
            throw(
                ArgumentError(
                    "Invalid or released MATFrost handle: $(id)",
                ),
            )

        HANDLE_STORE[id]
    end
end

resolve_handle(handle::MATFrostHandle) = resolve_handle(handle.id)

function release_handle(id::UUID)::Bool
    return lock(HANDLE_STORE_LOCK) do
        haskey(HANDLE_STORE, id) || return false
        delete!(HANDLE_STORE, id)
        return true
    end
end

release_handle(handle::MATFrostHandle)::Bool = release_handle(handle.id)

function release_all_handles!()
    lock(HANDLE_STORE_LOCK) do
        empty!(HANDLE_STORE)
    end

    return nothing
end

handle_count() = lock(HANDLE_STORE_LOCK) do
    length(HANDLE_STORE)
end