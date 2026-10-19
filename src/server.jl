module _Server

import ..MATFrost as MATFrost
import ..MATFrost._Read:  read_matfrostarray!
import ..MATFrost._Write: write_matfrostarray!
using ..MATFrost._Types
using ..MATFrost._Constants
using ..MATFrost._ConvertToJulia: _ConvertToJulia
using ..MATFrost._ConvertToMATLAB: _ConvertToMATLAB
using Sockets


struct CallMeta
    fully_qualified_name::String
    signature::Vector{String}
    # Inner constructors
    function CallMeta(fully_qualified_name::String, signature::Vector{String})
        new(fully_qualified_name, signature)
    end
    function CallMeta(fully_qualified_name::String, signature::String)
        new(fully_qualified_name, [signature])
    end
    function CallMeta(fully_qualified_name::String)
        new(fully_qualified_name, String[])
    end
end

struct MATFrostResultMATLAB{T}
    status::String # ERROR/SUCCESFUL
    log::String
    value::T
end


AmbiguityError(f::Function) = MATFrostException("matfrostjulia:call:ambigiousFunction",ambiguous_method_error(f))
"""
This function is the basis of the MATFrostServer.
"""
function MATFrost.matfrostserve(host::String, port::Int)
    client = connect(host, port)

    Sockets.nagle(client, false)

    println("MATFrost server connected. Ready for requests.")
    
    try 
        while true
            callsequence(client)
        end
    catch e
        if e isa InterruptException
            println("MATFrost server interrupted.")
        else
            Base.showerror(stdout, e)
            Base.show_backtrace(stdout, Base.catch_backtrace())
            exit()
        end
        println("MATFrost server stopped.")
    finally
        close(client)
    end
end

function package_is_loaded(packagename)
    try 
        # Check if package is loaded. 
        getfield(Main, packagename)
        return true
    catch
        return false
    end
end

function callsequence(io::IO)
    callstruct = read_matfrostarray!(io)
    
    marr = try

        if !(callstruct isa MATFrostArrayCell) || length(callstruct.values) != 2
            throw("error")
        end
        
        callmeta = _ConvertToJulia.convert_matfrostarray(CallMeta, callstruct.values[1])

        # Loads the required dependencies for the call described by `callmeta` if not loaded already.
        Base.invokelatest(load_dependencies, callmeta)

        # As packages (currently) are loaded loaded on-demand after MATFrost server has been started,
        # the functions in those packages need to be called from a newer world age.
        # This ofcourse is not ideal and should be treated with care.
        Base.invokelatest(callsequence_latest_world_age, callmeta, callstruct.values[2])

    catch e 
        
        buf = IOBuffer()
        Base.showerror(buf, e)
        Base.show_backtrace(buf, Base.catch_backtrace())
        s = String(take!(buf))

        matfe=if e isa MATFrostException
            MATFrostException(e.id, "$(e.message)\n\n$(s)")
        else
            MATFrostException("matfrostjulia:call:call", s)
        end

        _ConvertToMATLAB.convert_matfrostarray(matfrostexceptionresult(matfe))
    end

    if marr isa MATFrostArrayAbstract
        write_matfrostarray!(io, marr)
        flush(io)
    else
        error("Unclear error")
    end

end

function callsequence_latest_world_age(callmeta, callargs)
    (f,Args) = getMethod(callmeta)
    args = try
        _ConvertToJulia.convert_matfrostarray(Args, callargs)
    catch e
        if e isa MATFrostConversionException
            rethrow(matfrostinputconversionexception(e))
        end
        rethrow(e)
    end

    # Call the function using invokelatest for world age safety
    out = f(args...)

    _ConvertToMATLAB.convert_matfrostarray(MATFrostResultMATLAB("SUCCESFUL", "", out))
end


"""
Matches a dotted identifier chain (`Pkg.Sub.Type`) and captures only its root segment.

- `(?<![\\w.])` prevents the match from starting in the middle of a chain, so `Pkg.Sub.Type`
  yields `Pkg` only and never `Sub` or `Type`. It also rejects roots glued to a preceding
  word character, which keeps the exponent of a float literal such as `1.0e3` from matching.
- `([A-Za-z_]\\w*)` is the captured root. Starting with a non-digit means numeric literals
  can never produce a root.
- `(?:\\s*\\.\\s*[A-Za-z_]\\w*)+` requires at least one dotted segment, so an unqualified name
  such as `Float64` is not matched. `\\s*` tolerates spacing like `Pkg . Type`.
"""
const _QUALIFIED_RE = r"(?<![\w.])([A-Za-z_]\w*)(?:\s*\.\s*[A-Za-z_]\w*)+"

"""
    qualified_roots(s::AbstractString, roots=Set{Symbol}()) -> Set{Symbol}

Collect the root module names of every qualified identifier appearing in `s`.

`s` is a type or function string such as `"Pkg1.T{Pkg2.U, Vector{Pkg3.V}}"`; the returned set
is `Set([:Pkg1, :Pkg2, :Pkg3])`. Nested qualifications inside braces, tuples and `where`
clauses are found because the scan continues after each matched chain.

Roots named `Base`, `Core` or `Main` are skipped, as those modules are always available and
are never loaded as packages.

Pass `roots` to accumulate across several strings; it is mutated in place and also returned,
which lets the results of multiple calls be merged into one set.

Returns an empty set when `s` contains no dotted names, since an unqualified name like
`Float64` carries no package information.

Being purely lexical, this does not distinguish code from text: a qualified name inside a
string literal, a comment, or a quoted expression is still reported. For the type and
function strings handled here that does not occur, and a spurious root only costs one extra
import attempt in [`load_dependencies`](@ref).

A chain already rooted at a wrapper module, such as `Main.MyPkg.foo`, contributes nothing
because the root is `Main`; qualify from the package itself to have it loaded.
"""
function qualified_roots(s::AbstractString, roots=Set{Symbol}())
    for m in eachmatch(_QUALIFIED_RE, s)
        root = m.captures[1]
        root in ("Base", "Core", "Main") && continue
        push!(roots, Symbol(root))
    end
    return roots
end

"""
    load_dependencies(callmeta::CallMeta)

Import every package the call described by `callmeta` needs, before the call is resolved.

Root module names are collected with [`qualified_roots`](@ref) from both
`callmeta.fully_qualified_name` and each entry of `callmeta.signature`, so packages appearing
only in an argument type (for example `"Pkg2.U"` in a signature) are loaded as well. Each
root that is not already available is imported into `Main`.

Throws a `MATFrostException` with id `matfrostjulia:call:packageNotFound` when a package
cannot be imported, naming the package so the MATLAB side can report which dependency is
missing from the active environment.

Packages are loaded on demand while the server is already running, so importing here
advances the world age. Call this through `Base.invokelatest`, as `callsequence` does, and
resolve the function itself in a later world age.
"""
function load_dependencies(callmeta::CallMeta)

    roots = qualified_roots(callmeta.fully_qualified_name)

    foreach(callmeta.signature) do signature
        qualified_roots(signature, roots)
    end
    
    for packagename in roots
        if !package_is_loaded(packagename)
            try
                Main.eval(:(import $packagename))
            catch e
                throw(MATFrostException("matfrostjulia:call:packageNotFound", 
                    """
                    Package not found exception:

                    Package: $(packagename)
                    """
                ))
            end
        end
    end
end


function getMethod(meta::CallMeta)
    # Parse fully qualified name
    m = match(r"^([^.]+)\.([^(]+)$", meta.fully_qualified_name)
    if m === nothing
        throw(ErrorException("Incompatible fully_qualified_name: $(meta.fully_qualified_name)"))
    end
    (packagename, function_name) = m.captures

    # Get function object
    f = getfield(Main, Symbol(packagename))
    for sym in Symbol.(split(function_name, "."))
        try
            f = getfield(f, sym)
        catch
            if isa(f, Function)
                continue
            else
                throw(MATFrostException("matfrostjulia:call:functionNotFound",
                    """
                    Function not found exception:
                    Function $(meta.fully_qualified_name) 
                    """
                ))
            end
        end
    end

    mtds = methods(f)
    argtypes = !isempty(meta.signature) ?
        [Main.eval(Meta.parse(strip(s))) for sig in meta.signature for s in split_types_respecting_braces(sig)] :
        (length(mtds) == 1 ? collect(mtds[1].sig.types[2:end]) : nothing)

    if argtypes === nothing
        throw(MATFrostException(
            "matfrostjulia:call:multipleMethodDefinitions",
            ambiguous_method_error(f)
        ))
    end

    return (f, Tuple{argtypes...})
end

function matfrostinputconversionexception(e::MATFrostConversionException)
    tracereverse = reverse(e.stacktrace)

    tracestring = (
        if s isa Int64
            "[$(s)]" 
        elseif s isa Symbol
            ".$s"
        else
            ""
        end for s in tracereverse)
            
    message = "$(e.message)\n\nInput invalid at: arg$(tracestring...)"
    MATFrostException(e.id, message)
end

function matfrostexceptionresult(e)
    if e isa MATFrostException
        MATFrostResultMATLAB{MATFrostException}(
            "ERROR",
            "",
            e
        )
    else
        MATFrostResultMATLAB(
            "ERROR",
            "",
            e
        )
    end
end

function ambiguous_method_error(f)
    mtd = methods(f)
    numbered = ["   [$i] $(strip(split(string(sig), '@')[1]))" for (i, sig) in enumerate(mtd)]
    example = split(numbered[1], "] ")[2]
    m = match(r"^([^(]+)(\(.*\))$", example)
    example_name, example_args = m !== nothing ? (strip(m.captures[1]), strip(m.captures[2])) : (example, "")
    raw_types = split_types_respecting_braces(example_args)
    types = [occursin("::", p) ? split(split(p, "::"; limit=2)[2], "="; limit=2)[1] : "Any"
         for p in raw_types if !isempty(strip(p))]
    sigstring = join(types, ", ")
    return """
        Ambiguous function call: The function $(f) has multiple methods.
        Please specify the desired method signature to disambiguate your call.

        Available methods:
        $(join(numbered, "\n"))

        Example usage:
        CallMeta(\"$(example_name)\", \"$(sigstring)\")
        """
end

function split_types_respecting_braces(signature_args::AbstractString)::Vector{String}
    """
    Split a comma-separated list of type parameters while respecting nested braces.
    Only splits on commas at depth 0 (outside braces).
    """
    parts = String[]
    current = ""
    depth = 0
    
    for c in strip(signature_args, ['(', ')'])
        if c == '{' 
            depth += 1
        elseif c == '}' 
            depth -= 1
        elseif c == ',' && depth == 0
            push!(parts, current)
            current = ""
            continue
        end
        current *= c
    end
    push!(parts, current)
    return parts
end

end
