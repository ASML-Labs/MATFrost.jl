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

        if !(callstruct isa MATFrostArrayCell) || !(length(callstruct.values) in (2, 3))
            throw("error")
        end
        
        callmeta = _ConvertToJulia.convert_matfrostarray(CallMeta, callstruct.values[1])
        syms = Symbol.(split(callmeta.fully_qualified_name,"."))
        packagename = syms[1]


        if !Base.invokelatest(package_is_loaded, packagename)
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

        # As packages (currently) are loaded loaded on-demand after MATFrost server has been started,
        # the functions in those packages need to be called from a newer world age.
        # This ofcourse is not ideal and should be treated with care.
        kwargs_payload = length(callstruct.values) == 3 ? callstruct.values[3] : MATFrostArrayEmpty()
        Base.invokelatest(callsequence_latest_world_age, callmeta, callstruct.values[2], kwargs_payload)

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

function callsequence_latest_world_age(callmeta, callargs, kwargs_payload=MATFrostArrayEmpty())
    (f,Args) = getMethod(callmeta)
    args = try
        _ConvertToJulia.convert_matfrostarray(Args, callargs)
    catch e
        if e isa MATFrostConversionException
            rethrow(matfrostinputconversionexception(e))
        end
        rethrow(e)
    end

    kwargs = convert_kwargs_payload(kwargs_payload)

    # Call the function using invokelatest for world age safety
    out = f(args...; kwargs...)

    _ConvertToMATLAB.convert_matfrostarray(MATFrostResultMATLAB("SUCCESFUL", "", out))
end

function convert_kwargs_payload(payload::MATFrostArrayAbstract)::NamedTuple
    if payload isa MATFrostArrayEmpty
        return (;)
    elseif payload isa MATFrostArrayStruct
        if prod(payload.dims; init=1) != 1
            throw(MATFrostException(
                "matfrostjulia:call:invalidKwargs",
                "Keyword arguments must be supplied as a scalar struct."
            ))
        end

        names = Tuple(payload.fieldnames)
        values = [convert_untyped_matfrost(get_struct_value(payload, fn, 1)) for fn in payload.fieldnames]
        return NamedTuple{names}(Tuple(values))
    else
        throw(MATFrostException(
            "matfrostjulia:call:invalidKwargs",
            "Keyword arguments payload must be a struct."
        ))
    end
end

function get_struct_value(marr::MATFrostArrayStruct, fn::Symbol, i::Int)
    fns = marr.fieldnames
    for fni in eachindex(fns)
        if fns[fni] == fn
            return marr.values[fni + length(fns) * (i-1)]
        end
    end
    throw("Cannot find field")
end

function convert_untyped_matfrost(marr::MATFrostArrayAbstract)
    if marr isa MATFrostArrayEmpty
        return nothing
    elseif marr isa MATFrostArrayPrimitive
        return reshape_untyped_values(copy(marr.values), marr.dims)
    elseif marr isa MATFrostArrayString
        return reshape_untyped_values(copy(marr.values), marr.dims)
    elseif marr isa MATFrostArrayCell
        values = [convert_untyped_matfrost(v) for v in marr.values]
        return reshape_untyped_values(values, marr.dims)
    elseif marr isa MATFrostArrayStruct
        nel = prod(marr.dims; init=1)
        fieldnames_tuple = Tuple(marr.fieldnames)
        values = [NamedTuple{fieldnames_tuple}(Tuple(
            convert_untyped_matfrost(get_struct_value(marr, fn, i)) for fn in marr.fieldnames
        )) for i in 1:nel]
        return reshape_untyped_values(values, marr.dims)
    else
        throw(MATFrostException(
            "matfrostjulia:conversion:typeNotSupported",
            "Unsupported MATLAB payload type in keyword argument conversion."
        ))
    end
end

function reshape_untyped_values(values::Vector, dims::Vector{Int64})
    nel = prod(dims; init=1)
    if isempty(dims) || nel == 1
        return values[1]
    end

    highdims = count(>(1), dims)
    if highdims <= 1
        return values
    end

    return reshape(values, Tuple(dims))
end


function _load_and_eval_type(typestring::AbstractString)
    """
    Parse and evaluate a type string, loading any required packages first.
    Handles fully qualified types like "myPkg.DataType" and nested cases
    like "Pkg1.Type{Pkg2.OtherType}" by importing all package prefixes.
    """
    pkg_names = Set{String}()

    # Collect top-level package names from any qualified identifiers.
    for m in eachmatch(r"\b([A-Za-z_][A-Za-z0-9_]*)\.(?:[A-Za-z_][A-Za-z0-9_]*)(?:\.[A-Za-z_][A-Za-z0-9_]*)*", typestring)
        pkg = m.captures[1]
        if !(pkg in ("Base", "Core", "Main"))
            push!(pkg_names, pkg)
        end
    end

    for pkg_name in pkg_names
        if !Base.invokelatest(package_is_loaded, Symbol(pkg_name))
            try
                Main.eval(:(import $(Symbol(pkg_name))))
            catch e
                throw(MATFrostException("matfrostjulia:call:packageNotFound",
                    "Package not found: $pkg_name required for type $typestring"
                ))
            end
        end
    end

    return Main.eval(Meta.parse(typestring))
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
        [_load_and_eval_type(strip(s)) for sig in meta.signature for s in split_types_respecting_braces(sig)] :
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
