module _JuliaCall
    using ..MATFrost: _MATFrostArray as MATFrostArray

    using ..MATFrost: _ConvertToJulia
    
    using ..MATFrost: _ConvertToMATLAB

    using ..MATFrost: _MATFrostException as MATFrostException

    struct MATFrostInput
        package::String
        func::String
        args::Any
    end

    struct MATFrostOutput
        value::MATFrostArray
        data::Any
        exception::Bool
    end
    
    struct MATFrostOutputUnwrap
        exception::Bool
        value::MATFrostArray
    end

    # module MATFrostPackage
    # end

    function juliacall(mfa::MATFrostArray)

        try
            fns = [Symbol(unsafe_string(unsafe_load(mfa.fieldnames, i))) for i in 1:mfa.nfields]

            if !(:package in fns && :func in fns && :args in fns)
                s = _ConvertToMATLAB.convert("Not working2" * string(fns))
                return MATFrostOutput(s.matfrostarray, s, false)
            end

            package_i  = findfirst(fn -> fn == :package, fns)
            func_i     = findfirst(fn -> fn == :func, fns)
            args_i     = findfirst(fn -> fn == :args, fns)

            
            mfadata = reinterpret(Ptr{Ptr{MATFrostArray}}, mfa.data)
            
            package_sym = Symbol(_ConvertToJulia.convert_to_julia(String, unsafe_load(unsafe_load(mfadata, package_i))))
            func_sym    = Symbol(_ConvertToJulia.convert_to_julia(String, unsafe_load(unsafe_load(mfadata, func_i))))

            try 
                Main.eval(:(import $(package_sym)))
            catch e
                throw(MATFrostException("matfrostjulia:packageDoesNotExist", """
                Package does not exist.
                
                $(sprint(showerror, e, catch_backtrace()))
                """
                ))
            end


            func = try 
                getproperty(getproperty(Main, package_sym), func_sym)
            catch e
                throw(MATFrostException("matfrostjulia:functionDoesNotExist", """
                Function does not exist.

                $(sprint(showerror, e, catch_backtrace()))
                """
                )) 
            end

            if (length(methods(func)) != 1)
                throw(MATFrostException("matfrostjulia:multipleMethodDefinitions", """
                Function contains multiple method implementations:

                $(methods(func))
                """
                )) 
            end

            argstypes = Tuple{(methods(func)[1].sig.types[2:end]...,)...}

            args_mfa = unsafe_load(unsafe_load(mfadata, args_i))
            
            args = _ConvertToJulia.convert_to_julia(argstypes, args_mfa)

            # The main Julia call
            vo = func(args...)
            
            vom = _ConvertToMATLAB.convert(vo)

            return MATFrostOutput(vom.matfrostarray, vom, false)
        catch e
            if isa(e, MATFrostException)
                mfe = _ConvertToMATLAB.convert(e)
                return MATFrostOutput(mfe.matfrostarray, mfe, true)
            else
                s = _ConvertToMATLAB.convert(MATFrostException("matfrostjulia:crashed", sprint(showerror, e, catch_backtrace())))
                return MATFrostOutput(s.matfrostarray, s, true)
            end
        end

    end

    function juliacall_test(mfa::MATFrostArray)
        s = _ConvertToMATLAB.convert("Is this working on Linux?")

        MATFrostOutput(s.matfrostarray, s, false)
    end

    juliacall_c() = @cfunction(juliacall, Any, (MATFrostArray,))


    unwrap(val::MATFrostOutput) = MATFrostOutputUnwrap(val.exception, val.value)

    unwrap_c() = @cfunction(unwrap, MATFrostOutputUnwrap, (Any,))



    test2 = ["SDF", "SDFS", "FD"]

    mfa = MATFrostArray(0, 0, 0, 0, 0, 0)

    test1 = juliacall(mfa)
    

end
