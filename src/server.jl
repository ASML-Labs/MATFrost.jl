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
        new(fully_qualified_name, split(signature, ",") .|> strip)
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
        close(server)
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
        [Main.eval(Meta.parse(s)) for s in meta.signature] :
        (length(mtds) == 1 ? mtds[1].sig.types[2:end] : nothing)

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
    raw_types = split(strip(example_args, ['(', ')']), ",")
types = [occursin("::", p) ? strip(split(split(p, "::"; limit=2)[2], "="; limit=2)[1]) : "Any"
         for p in raw_types if !isempty(strip(p))]
    sigstring = join(types, ",")
    return """
        Ambiguous function call: The function $(f) has multiple methods.
        Please specify the desired method signature to disambiguate your call.

        Available methods:
        $(join(numbered, "\n"))

        Example usage:
        CallMeta(\"$(example_name)\", \"$(sigstring)\")
        """
end

end