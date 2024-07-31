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

class MexFunction : public matlab::mex::Function {
private:
    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr;
    ArgumentList* outputs_p;
    ArgumentList* inputs_p;
    std::thread juliaworkerthread;
    
    std::mutex m;
    std::condition_variable cv;

    
    bool_t                          exception_triggered = false;
    matlab::engine::MATLABException exception_matlab;
    
    // std::string julia_environment_path;


public:
    MexFunction() {
        // Start Julia worker and initialization.
        juliaworkerthread = std::thread(&MexFunction::juliaworker, this);

        // wait for Julia init to finish.
        {
            std::unique_lock<std::mutex> lk(m);
            cv.wait(lk);
        }
 

    }

    virtual ~MexFunction(){
        
        matlab::data::ArrayFactory factory;

        matlabPtr->feval(u"fprintf", 0, std::vector<matlab::data::Array>
            ({ factory.createScalar("Closing MEX function")}));
    }

    void operator()(ArgumentList outputs, ArgumentList inputs) {
        inputs_p = &inputs;
        outputs_p = &outputs;

        // Start Julia Worker
        cv.notify_one();

        {  
            // Wait until Julia worker finishes
            std::unique_lock<std::mutex> lk(m);
            cv.wait(lk);
        }


        if (exception_triggered){ 
            exception_triggered = false;
            throw exception_matlab;
        }


    }

    int juliaworker(){
        {
            juliaworkerinit();
            cv.notify_one();
        }


        while(true){
            {
                // Wait until Julia worker can start
                std::unique_lock<std::mutex> lk(m);
                cv.wait(lk);

                juliaworkerjob();

                lk.unlock();

                // Pass back control to main thread.
                cv.notify_one();
            }
        }
        
        return 0;
    }

    int juliaworkerinit(){
        matlabPtr = getEngine(); 

        jl_init();
                    
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
                jlargs[i+1] = MATFrost::ConvertToJulia::convert(std::move(inputs[i+1]), jfs.arguments[i], matlabPtr);
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
                outputs[0] = convert_to_matlab((jl_value_t*) jl_get_nth_field(jlo, 1));
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


    matlab::data::Array convert_to_matlab(jl_value_t* jlval){
        if (jl_is_array(jlval)){
            return convert_to_matlab_array(jlval);
        }
        else {
            return convert_to_matlab_scalar(jlval);
        }
    }
    matlab::data::Array convert_to_matlab_scalar(jl_value_t* jlval){

        jl_function_t* jlcomplex = jl_get_function(jl_base_module, "Complex");
        
        jl_datatype_t* jltype = (jl_datatype_t*) jl_typeof(jlval);

        if(jl_is_primitivetype(jltype)){
            matlab::data::ArrayFactory factory;
            if (jltype == jl_float64_type){           
                return factory.createScalar(jl_unbox_float64(jlval));
            }
            if (jltype == jl_float32_type){ 
                return factory.createScalar(jl_unbox_float32(jlval));
            }
            if (jltype == jl_int64_type){ 
                return factory.createScalar(jl_unbox_int64(jlval));
            }
            if (jltype == jl_uint64_type){ 
                return factory.createScalar(jl_unbox_uint64(jlval));
            }
            if (jltype == jl_int32_type){ 
                return factory.createScalar(jl_unbox_int32(jlval));
            }
            if (jltype == jl_uint32_type){ 
                return factory.createScalar(jl_unbox_uint32(jlval));
            }
            if (jltype == jl_int16_type){ 
                return factory.createScalar(jl_unbox_int16(jlval));
            }
            if (jltype == jl_uint16_type){ 
                return factory.createScalar(jl_unbox_uint16(jlval));
            }
            if (jltype == jl_int8_type){ 
                return factory.createScalar(jl_unbox_int8(jlval));
            }
            if (jltype == jl_uint8_type){ 
                return factory.createScalar(jl_unbox_uint8(jlval));
            }
            if (jltype == jl_bool_type){ 
                return factory.createScalar((bool) jl_unbox_bool(jlval));
            }
        } 
        else if (jl_subtype((jl_value_t*) jltype, jlcomplex)){
            matlab::data::ArrayFactory factory;

            jl_datatype_t* complexof = (jl_datatype_t*) jl_tparam0(jltype);

            if (complexof == jl_float64_type){       
                return factory.createScalar(std::complex<double>(
                    jl_unbox_float64(jl_get_nth_field(jlval, 0)),
                    jl_unbox_float64(jl_get_nth_field(jlval, 1))
                ));
            }
            if (complexof == jl_float32_type){ 
                return factory.createScalar(std::complex<float>(
                    jl_unbox_float32(jl_get_nth_field(jlval, 0)),
                    jl_unbox_float32(jl_get_nth_field(jlval, 1))
                ));
            }
            if (complexof == jl_int64_type){ 
                return factory.createScalar(std::complex<int64_t>(
                    jl_unbox_int64(jl_get_nth_field(jlval, 0)),
                    jl_unbox_int64(jl_get_nth_field(jlval, 1))
                ));
            }
            if (complexof == jl_uint64_type){ 
                return factory.createScalar(std::complex<uint64_t>(
                    jl_unbox_uint64(jl_get_nth_field(jlval, 0)),
                    jl_unbox_uint64(jl_get_nth_field(jlval, 1))
                ));
            }
            if (complexof == jl_int32_type){ 
                return factory.createScalar(std::complex<int32_t>(
                    jl_unbox_int32(jl_get_nth_field(jlval, 0)),
                    jl_unbox_int32(jl_get_nth_field(jlval, 1))
                ));
            }
            if (complexof ==  jl_uint32_type){ 
                return factory.createScalar(std::complex<uint32_t>(
                    jl_unbox_uint32(jl_get_nth_field(jlval, 0)),
                    jl_unbox_uint32(jl_get_nth_field(jlval, 1))
                ));
            }
            if (complexof == jl_int16_type){ 
                return factory.createScalar(std::complex<int16_t>(
                    jl_unbox_int16(jl_get_nth_field(jlval, 0)),
                    jl_unbox_int16(jl_get_nth_field(jlval, 1))
                ));
            }
            if (complexof == jl_uint16_type){ 
                return factory.createScalar(std::complex<uint16_t>(
                    jl_unbox_uint16(jl_get_nth_field(jlval, 0)),
                    jl_unbox_uint16(jl_get_nth_field(jlval, 1))
                ));
            }
            if (complexof == jl_int8_type){ 
                return factory.createScalar(std::complex<int8_t>(
                    jl_unbox_int8(jl_get_nth_field(jlval, 0)),
                    jl_unbox_int8(jl_get_nth_field(jlval, 1))
                ));
            }
            if (complexof == jl_uint8_type){ 
                return factory.createScalar(std::complex<uint8_t>(
                    jl_unbox_uint8(jl_get_nth_field(jlval, 0)),
                    jl_unbox_uint8(jl_get_nth_field(jlval, 1))
                ));
            }
        }
        else if (jltype == jl_string_type){
            return convert_to_matlab_string_scalar(jlval);
        }
        else if (jl_is_tuple_type(jltype)){
            size_t nfields = jl_datatype_nfields(jltype); 

            matlab::data::ArrayFactory factory;

            matlab::data::CellArray matstruct = factory.createCellArray({nfields, 1});

            for (size_t fi = 0; fi < nfields; fi++){
                matstruct[fi] = convert_to_matlab(jl_get_nth_field(jlval, fi));
            }
            
            return matstruct;
        }
        else if (jl_is_namedtuple_type(jltype) || jl_is_structtype(jltype)){
            size_t nfields = jl_datatype_nfields(jltype); 

            matlab::data::ArrayFactory factory;
            jl_function_t* fieldnames_f = jl_get_function(jl_base_module, "fieldnames");

            // Tuple of fieldnames symbols
            jl_value_t* fieldnames_syms = jl_call1(fieldnames_f, (jl_value_t*) jltype);

            std::vector<std::string> fieldnames(nfields);
            
            for (size_t fi = 0; fi < nfields; fi++){
                fieldnames[fi] = jl_symbol_name((jl_sym_t*) jl_get_nth_field(fieldnames_syms, fi)); 
            }
                        
            matlab::data::StructArray matstruct = factory.createStructArray({1, 1}, fieldnames);
                
            
            for (size_t fi = 0; fi < nfields; fi++){
                matstruct[0][fieldnames[fi]] = convert_to_matlab(jl_get_nth_field(jlval, fi));
            }
            return matstruct;


        }       
        

        matlab::data::ArrayFactory factory;
        return factory.createEmptyArray();

    }


    matlab::data::Array convert_to_matlab_array(jl_value_t* jlval){

        jl_function_t* jlcomplex = jl_get_function(jl_base_module, "Complex");

        jl_function_t* eltype = jl_get_function(jl_base_module, "eltype");
        
        jl_datatype_t* jltype = (jl_datatype_t*) jl_typeof(jlval);
       
        jl_datatype_t* elt = (jl_datatype_t*) jl_call1(eltype, jlval);
        
        if(jl_is_primitivetype(elt)){
            if (elt == jl_float64_type){           
                return convert_to_matlab_primitive_array<double>((jl_array_t*) jlval);
            }
            if (elt == jl_float32_type){ 
                return convert_to_matlab_primitive_array<float>((jl_array_t*) jlval);
            }
            if (elt == jl_int64_type){ 
                return convert_to_matlab_primitive_array<int64_t>((jl_array_t*) jlval);
            }
            if (elt == jl_uint64_type){ 
                return convert_to_matlab_primitive_array<uint64_t>((jl_array_t*) jlval);
            }
            if (elt == jl_int32_type){ 
                return convert_to_matlab_primitive_array<int32_t>((jl_array_t*) jlval);
            }
            if (elt == jl_uint32_type){ 
                return convert_to_matlab_primitive_array<uint32_t>((jl_array_t*) jlval);
            }
            if (elt == jl_int16_type){ 
                return convert_to_matlab_primitive_array<int16_t>((jl_array_t*) jlval);
            }
            if (elt == jl_uint16_type){ 
                return convert_to_matlab_primitive_array<uint16_t>((jl_array_t*) jlval);
            }
            if (elt == jl_int8_type){ 
                return convert_to_matlab_primitive_array<int8_t>((jl_array_t*) jlval);
            }
            if (elt == jl_uint8_type){ 
                return convert_to_matlab_primitive_array<uint8_t>((jl_array_t*) jlval);
            }
            if (elt == jl_bool_type){ 
                return convert_to_matlab_primitive_array<bool>((jl_array_t*) jlval);
            }
        }
        else if (elt == jl_string_type){
            return convert_to_matlab_string_array(jlval);
        }
        else if (jl_subtype((jl_value_t*) elt, jlcomplex)){
            
            jl_datatype_t* complexof = (jl_datatype_t*) jl_tparam0(elt);
            
            if (complexof == jl_float64_type){           
                return convert_to_matlab_primitive_array<std::complex<double>>((jl_array_t*) jlval);
            }
            if (complexof == jl_float32_type){ 
                return convert_to_matlab_primitive_array<std::complex<float>>((jl_array_t*) jlval);
            }
            if (complexof == jl_int64_type){ 
                return convert_to_matlab_primitive_array<std::complex<int64_t>>((jl_array_t*) jlval);
            }
            if (complexof == jl_uint64_type){ 
                return convert_to_matlab_primitive_array<std::complex<uint64_t>>((jl_array_t*) jlval);
            }
            if (complexof == jl_int32_type){ 
                return convert_to_matlab_primitive_array<std::complex<int32_t>>((jl_array_t*) jlval);
            }
            if (complexof == jl_uint32_type){ 
                return convert_to_matlab_primitive_array<std::complex<uint32_t>>((jl_array_t*) jlval);
            }
            if (complexof == jl_int16_type){ 
                return convert_to_matlab_primitive_array<std::complex<int16_t>>((jl_array_t*) jlval);
            }
            if (complexof == jl_uint16_type){ 
                return convert_to_matlab_primitive_array<std::complex<uint16_t>>((jl_array_t*) jlval);
            }
            if (complexof == jl_int8_type){ 
                return convert_to_matlab_primitive_array<std::complex<int8_t>>((jl_array_t*) jlval);
            }
            if (complexof == jl_uint8_type){ 
                return convert_to_matlab_primitive_array<std::complex<uint8_t>>((jl_array_t*) jlval);
            }
        }    
        else if (jl_is_namedtuple_type(elt) || jl_is_structtype(elt)){

            matlab::data::ArrayDimensions dims(jl_array_ndims(jlval));
            size_t nel = jl_array_len(jlval);
            for (size_t i = 0; i < jl_array_ndims(jlval); i++){
                dims[i] = jl_array_dim(jlval, i);
            }

            size_t nfields = jl_datatype_nfields(elt); 

            matlab::data::ArrayFactory factory;
            jl_function_t* fieldnames_f = jl_get_function(jl_base_module, "fieldnames");

            // Tuple of fieldnames symbols
            jl_value_t* fieldnames_syms = jl_call1(fieldnames_f, (jl_value_t*) elt);

            std::vector<std::string> fieldnames(nfields);
            
            for (size_t fi = 0; fi < nfields; fi++){
                fieldnames[fi] = jl_symbol_name((jl_sym_t*) jl_get_nth_field(fieldnames_syms, fi)); 
            }
                        
            matlab::data::StructArray matstruct = factory.createStructArray(dims, fieldnames);
                
            jl_function_t *getindex = jl_get_function(jl_base_module, "getindex");
            size_t eli = 1;
            for (auto e : matstruct) {
                jl_value_t* jlvale = jl_call2(getindex, jlval, jl_box_int64(eli));
                for (size_t fi = 0; fi < nfields; fi++){
                    e[fieldnames[fi]] = convert_to_matlab(jl_get_nth_field(jlvale, fi));
                }
                eli++;
            }
            return matstruct;
        }    
        else {
            // Array{Tuple}, Array{Any}, Array{AbstractType}

            matlab::data::ArrayDimensions dims(jl_array_ndims(jlval));
            size_t nel = jl_array_len(jlval);
            for (size_t i = 0; i < jl_array_ndims(jlval); i++){
                dims[i] = jl_array_dim(jlval, i);
            }

            matlab::data::ArrayFactory factory;
                    
            matlab::data::CellArray matstruct = factory.createCellArray(dims);
                
            jl_function_t *getindex = jl_get_function(jl_base_module, "getindex");
            size_t eli = 1;
            for (auto e : matstruct) {
                jl_value_t* jlvale = jl_call2(getindex, jlval, jl_box_int64(eli));
                e =  convert_to_matlab(jlvale);
                eli++;
            }
            return matstruct;

        }
      

        matlab::data::ArrayFactory factory;
        return factory.createEmptyArray();

    }


    template<typename T>
    matlab::data::TypedArray<T> convert_to_matlab_primitive_array(jl_array_t* jlval){
        
        matlab::data::ArrayDimensions dims(jl_array_ndims(jlval));
        size_t nel = jl_array_len(jlval);
        for (size_t i = 0; i < jl_array_ndims(jlval); i++){
            dims[i] = jl_array_dim(jlval, i);
        }

        matlab::data::ArrayFactory factory;

        matlab::data::buffer_ptr_t<T> buf = factory.createBuffer<T>(nel);

        memcpy(buf.get(), jl_array_ptr(jlval), sizeof(T)*nel);
        
        matlab::data::TypedArray<T> marr = factory.createArrayFromBuffer<T>(dims, std::move(buf));
        
        return marr;
    }

    std::string convert_to_u8string(jl_value_t* jlval){
        std::string s8(jl_string_ptr(jlval));
        return s8;
    }

    matlab::data::String convert_to_u16string(jl_value_t* jlval){
        std::string s8(jl_string_ptr(jlval));
        return matlab::engine::convertUTF8StringToUTF16String(s8);
    }

    matlab::data::StringArray convert_to_matlab_string_array(jl_value_t* jlval){

        matlab::data::ArrayDimensions dims(jl_array_ndims(jlval));
        size_t nel = jl_array_len(jlval);
        for (size_t i = 0; i < jl_array_ndims(jlval); i++){
            dims[i] = jl_array_dim(jlval, i);
        }

        jl_function_t *getindex = jl_get_function(jl_base_module, "getindex");

        matlab::data::ArrayFactory factory;
        matlab::data::StringArray sa = factory.createArray<matlab::data::MATLABString>(dims);

        size_t i = 1;
        for (auto e : sa) {
            jl_value_t* jlvale = jl_call2(getindex, jlval, jl_box_int64(i));
            e = convert_to_u16string(jlvale);
            i++;
        }

        return sa;

    }

    matlab::data::StringArray convert_to_matlab_string_scalar(jl_value_t* jlval){
        matlab::data::ArrayDimensions dims(2);
        dims[0] = 1;
        dims[1] = 1;
        matlab::data::ArrayFactory factory;
        matlab::data::StringArray sa = factory.createArray<matlab::data::MATLABString>(dims);
        for (auto e : sa) {
            e = convert_to_u16string(jlval);
        }
        return sa;
    }
    


};

// class