using UUIDs

"""
    MATFrostHandle(id, typename)

Opaque reference to an object held in the MATFrost Julia server process.
MATFrost normally creates handles during conversion; users usually receive
them as MATLAB structs rather than constructing them directly.
"""
struct MATFrostHandle
    id::UUID
    typename::String
end

const HANDLE_MARKER_FIELD = :dataType
const HANDLE_MARKER_VALUE = "matfrost_handle"
const HANDLE_ID_FIELD = :id
const HANDLE_TYPENAME_FIELD = :typename

"""
    use_matfrost_handle(::Type{T})

Trait controlling whether values of `T` are converted to handles. It returns
`false` by default. An integration package can opt in a concrete type with a
more specific method returning `true`.
"""
use_matfrost_handle(::Type) = false

const HANDLE_STORE = Dict{UUID,Any}()
const HANDLE_STORE_LOCK = ReentrantLock()

"""
    store_handle(value) -> MATFrostHandle

Retain `value` in the current Julia server process and return an opaque handle.
Most integrations should opt a type in with [`use_matfrost_handle`](@ref)
instead of calling this function directly.
"""
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

"""
    resolve_handle(handle::MATFrostHandle)
    resolve_handle(id::UUID)

Return the object associated with a handle. Throws `ArgumentError` if the
handle is unknown or has already been released.
"""
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

"""
    release_handle(handle::MATFrostHandle)
    release_handle(id::UUID)

Release a stored object. Returns `true` if the handle existed and was removed,
or `false` if it had already been released or was unknown.
"""
function release_handle(id::UUID)::Bool
    return lock(HANDLE_STORE_LOCK) do
        haskey(HANDLE_STORE, id) || return false
        delete!(HANDLE_STORE, id)
        return true
    end
end

release_handle(handle::MATFrostHandle)::Bool = release_handle(handle.id)

"""
    release_all_handles!()

Release every object retained by the current Julia server process. All
outstanding handles from that process become invalid.
"""
function release_all_handles!()
    lock(HANDLE_STORE_LOCK) do
        empty!(HANDLE_STORE)
    end

    return nothing
end

handle_count() = lock(HANDLE_STORE_LOCK) do
    length(HANDLE_STORE)
end