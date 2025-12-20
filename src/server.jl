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
function MATFrost.matfrostserve(socket_path::String)
    # Remove existing socket file if it exists
    isfile(socket_path) && rm(socket_path)
    
    server = listen(socket_path)
    
    client = accept(server)
    
    println("MATFrost server connected. Ready for requests.")
    
    while true  
        try 
            callsequence(client)
        catch e
            Base.showerror(stdout, e)
            Base.show_backtrace(stdout, Base.catch_backtrace())
            exit()
        end
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
