using UUIDs

"""
Opaque reference to an object stored in the MATFrost server.
"""
struct MATFrostHandle
    id::UUID
    typename::String
end

"""
Types participate in normal MATFrost conversion by default.

Extensions may override this trait:

    MATFrost.use_matfrost_handle(::Type{MyType}) = true
"""
use_matfrost_handle(::Type) = false

const HANDLE_STORE = Dict{UUID,Any}()
const HANDLE_STORE_LOCK = ReentrantLock()

"""
Store an object and return an opaque handle.
"""
function store_handle(value)::MATFrostHandle
    handle = MATFrostHandle(
        uuid4(),
        string(nameof(typeof(value))),
    )

    lock(HANDLE_STORE_LOCK) do
        HANDLE_STORE[handle.id] = value
    end

    return handle
end

"""
Resolve a handle back to its Julia object.
"""
function resolve_handle(handle::MATFrostHandle)
    lock(HANDLE_STORE_LOCK) do
        haskey(HANDLE_STORE, handle.id) ||
            throw(ArgumentError(
                "Invalid or released MATFrost handle: $(handle.id)"
            ))

        return HANDLE_STORE[handle.id]
    end
end

"""
Release a handle.

Returns true when something was removed.
"""
function release_handle(handle::MATFrostHandle)::Bool
    lock(HANDLE_STORE_LOCK) do
        return pop!(HANDLE_STORE, handle.id, nothing) !== nothing
    end
end

"""
Convenience overload.
"""
function release_handle(id::UUID)::Bool
    return release_handle(
        MATFrostHandle(id, "")
    )
end

"""
Release all stored objects.
Useful during server shutdown and tests.
"""
function release_all_handles!()
    lock(HANDLE_STORE_LOCK) do
        empty!(HANDLE_STORE)
    end

    return nothing
end

"""
Internal test helper.
"""
handle_count() = lock(HANDLE_STORE_LOCK) do
    length(HANDLE_STORE)
end
