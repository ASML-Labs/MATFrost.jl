#include "mex.hpp"
#include "mexAdapter.hpp"

#include <tuple>
// stdc++ lib
#include <string>

// External dependencies
// using namespace matlab::data;
using matlab::mex::ArgumentList;
#include <julia.h>
#include <thread>
#include <condition_variable>
#include <mutex>

#include <complex>

#include <chrono>
#include "converttojulia.hpp"
#include "converttomatlab.hpp"


class MexFunction : public matlab::mex::Function {
private:
    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr;
    ArgumentList* outputs_p;
    ArgumentList* inputs_p;
    std::thread juliaworkerthread;
    
    std::mutex mtx_mex;

    std::mutex mtx_jl;
    std::condition_variable cv_jl;

    
    bool_t                          exception_triggered = false;
    matlab::engine::MATLABException exception_matlab;
    
    // std::string julia_environment_path;


public:
    MexFunction() {
        matlabPtr = getEngine(); 

        std::unique_lock<std::mutex> lk(mtx_jl);

        // Start Julia worker and initialize Julia.
        juliaworkerthread = std::thread(&MexFunction::juliaworker, this);
        
        // wait for Julia init to finish.
        cv_jl.wait(lk);
        

    }

    virtual ~MexFunction(){
        
        matlab::data::ArrayFactory factory;

        matlabPtr->feval(u"fprintf", 0, std::vector<matlab::data::Array>
            ({ factory.createScalar("Closing MEX function")}));
    }

    void operator()(ArgumentList outputs, ArgumentList inputs) {
        
        // lk_mex will sequentialize Julia jobs in case of concurrent MEX-calls.
        std::lock_guard<std::mutex> lk_mex(mtx_mex);
        {
            std::unique_lock<std::mutex> lk(mtx_jl);
            inputs_p = &inputs;
            outputs_p = &outputs;

            // Start Julia worker Job
            cv_jl.notify_one();
            cv_jl.wait(lk);


            if (exception_triggered){ 
                exception_triggered = false;
                throw exception_matlab;
            } 
        }
        
    }

    int juliaworker(){
        std::unique_lock<std::mutex> lk(mtx_jl);
        jl_init();

        while(true){
            cv_jl.notify_one();
            cv_jl.wait(lk);

            juliaworkerjob();
        }
        
        return 0;
    }


    std::string convert_to_string(matlab::data::Array marr)
    {
        if (marr.getType() == matlab::data::ArrayType::CHAR)
        {
            matlab::data::CharArray ca = marr;
            return matlab::engine::convertUTF16StringToUTF8String(ca.toUTF16());
        }

        if(marr.getType() == matlab::data::ArrayType::MATLAB_STRING)
        {
            matlab::data::StringArray  sa = marr;
            matlab::data::MATLABString ms = sa[0];
            matlab::data::String       sv = *ms;
            return matlab::engine::convertUTF16StringToUTF8String(sv);
        }

        throw std::invalid_argument("Expected a string");
    }

    struct BifrostCallStruct {
        std::string function;
        std::string package;
    };

    BifrostCallStruct convert_callstruct(matlab::data::Array marr){
        BifrostCallStruct callstruct;
        if (marr.getType() != matlab::data::ArrayType::STRUCT){
            throw std::invalid_argument("Expecting a callstruct on the first argument");
        }
        matlab::data::StructArray sa = marr;
        matlab::data::Struct      s  = sa[0];

        callstruct.function = convert_to_string(s["function"]);
        callstruct.package  = convert_to_string(s["package"]);
        
        return callstruct;
    }

    struct JuliaFunctionSignature {
        jl_module_t* package;
        jl_function_t* function;
        std::vector<jl_datatype_t*> arguments;
    };

    JuliaFunctionSignature get_jl_function_signature(BifrostCallStruct cs){
        JuliaFunctionSignature jfs;

        jfs.package = (jl_module_t*) jl_eval_string(("try \n import " + cs.package + " \n " + cs.package + "\n catch e \n bt = catch_backtrace() \n sprint(showerror, e, bt) \n end").c_str());
        if (jl_is_string((jl_value_t*) jfs.package)){
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrostjulia:packageDoesNotExist"),
                factory.createScalar(u"\nMATFrost.jl error:\nPackage does not exist. \n\n\n--------------------------------------------------------------------------------\n" 
                    + matlab::engine::convertUTF8StringToUTF16String(jl_string_ptr((jl_value_t*) jfs.package)))}));
        }

        jfs.function = (jl_function_t*) jl_eval_string(("try \n " + cs.package + "." + cs.function + "\n catch e \n bt = catch_backtrace() \n sprint(showerror, e, bt) \n end").c_str());
        if (jl_is_string((jl_value_t*) jfs.function)){
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrostjulia:functionDoesNotExist"),
                factory.createScalar(u"\nMATFrost.jl error:\nFunction does not exist. \n\n\n--------------------------------------------------------------------------------\n" 
                    + matlab::engine::convertUTF8StringToUTF16String(jl_string_ptr((jl_value_t*) jfs.function)))}));
        }

        jl_value_t* jlmethods = jl_call1(jl_get_function(jl_main_module, "methods"), jfs.function);

        if (1 == jl_unbox_int64(jl_call1(jl_get_function(jl_main_module, "length"), jlmethods))){
            jl_value_t* jlmethod = jl_call2(jl_get_function(jl_main_module, "getindex"), jlmethods, jl_box_int64(1));
            jl_value_t* metsig   = jl_call2(jl_get_function(jl_main_module, "getproperty"), jlmethod, (jl_value_t*) jl_symbol("sig"));
            jl_value_t* mettypes = jl_call2(jl_get_function(jl_main_module, "getproperty"), metsig,   (jl_value_t*) jl_symbol("types"));
            // mettypes is a svec containing ([1]=function_type; [2...]=argument_types...)

            int64_t     numargs  = jl_unbox_int64(jl_call1(jl_get_function(jl_main_module, "length"), mettypes)) - 1;

            jfs.arguments = std::vector<jl_datatype_t*>(numargs);

            for (size_t iarg = 0; iarg < numargs; iarg++){
                jfs.arguments[iarg] = (jl_datatype_t*) jl_call2(jl_get_function(jl_main_module, "getindex"), mettypes, jl_box_int64(iarg+2));
            }

        }
        else {
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrost:function"),
                factory.createScalar("\nMATFrost.jl error:\nFunction has more than 1 method implementation.")}));
        }
        return jfs;
    }

    


    int juliaworkerjob() {
        try
        {

            ArgumentList& outputs = *outputs_p;
            ArgumentList& inputs = *inputs_p;
            matlab::data::ArrayFactory factory;
                        
            BifrostCallStruct bcs = convert_callstruct(inputs[0]);
            JuliaFunctionSignature jfs = get_jl_function_signature(bcs);

            jl_gc_collect(JL_GC_AUTO);
            // Disabled to convert to Julia types.
            jl_gc_enable(0);
            
            size_t nargs = inputs.size()-1;
            if (jfs.arguments.size() != nargs){
                matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                    factory.createScalar("matfrost:argument"),
                    factory.createScalar("\nMATFrost.jl error:\nNumber of input arguments doesn't match number of arguments of the function.")}));
                // throw std::invalid_argument("Number of input arguments doesn't match number of arguments on function.");
            }

            // Convert MATLAB values to Julia values
            jl_value_t* jlargs[nargs+1];
            jlargs[0] = (jl_value_t*) jfs.function;

            for (size_t i=0; i < nargs; i++){
                jlargs[i+1] = MATFrost::ConvertToJulia::convert(inputs[i+1], jfs.arguments[i], i, matlabPtr);
            }

            jl_value_t **jlargs_p = jlargs;

            
            JL_GC_PUSHARGS(jlargs_p, nargs+1);
            
            // Enabled as intended Julia function is called.
            jl_gc_enable(1);

            jl_function_t* matfrostcall = (jl_function_t*) jl_eval_string("matfrostcall((@nospecialize f), args...) = try \n (false, f(args...)) \n catch e \n bt = catch_backtrace() \n (true, sprint(showerror, e, bt)) \n end");

            // The JUICE: The Julia call!
            jl_value_t* jlo = jl_call(matfrostcall, jlargs, nargs+1);

            // Disabled as several calls to jl* are made to destructure the data. 
            jl_gc_enable(0);

            JL_GC_POP();

            if (!jl_unbox_bool(jl_get_nth_field(jlo, 0))){
                outputs[0] = MATFrost::ConvertToMATLAB::convert((jl_value_t*) jl_get_nth_field(jlo, 1), matlabPtr);
            } else {
                matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                    factory.createScalar("matfrostjulia:callError"),
                    factory.createScalar(u"\nMATFrost.jl error:\nJulia function call error. \n\n\n--------------------------------------------------------------------------------\n" 
                        + matlab::engine::convertUTF8StringToUTF16String(jl_string_ptr((jl_value_t*) jl_get_nth_field(jlo, 1))))}));
            }
            
            // Data has been copied to MATLAB domain, so Julia can start Garbage collection again.
            jl_gc_enable(1);      

            jl_gc_collect(JL_GC_AUTO);
        }
        catch(const matlab::engine::MATLABException& ex)
        {
            // Disabled to convert to Julia types.
            jl_gc_enable(1); 
            jl_gc_collect(JL_GC_AUTO);

            exception_matlab = ex;
            exception_triggered = true;
        }
        catch(std::exception& ex)
        {
            // Disabled to convert to Julia types.
            jl_gc_enable(1); 
            jl_gc_collect(JL_GC_AUTO);

            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"disp", 0, std::vector<matlab::data::Array>
                ({ factory.createScalar("###################################\nMATFrost error: " + std::string(ex.what()) + "\n###################################\n")}));
        }
        return 0; 
    }


    


};

// class