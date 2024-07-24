#include "mex.hpp"
#include "mexAdapter.hpp"

// windows
#define WIN32_LEAN_AND_MEAN
#include <windows.h>

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
    
        jl_eval_string("import Pkg; Pkg.instantiate()");
                
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
                factory.createScalar(u"\nMATFrost.jl error:\nPackage does not exist! \n\n\n " + matlab::engine::convertUTF8StringToUTF16String(jl_string_ptr((jl_value_t*) jfs.package)))}));
        }

        jfs.function = (jl_function_t*) jl_eval_string(("try \n " + cs.package + "." + cs.function + "\n catch e \n bt = catch_backtrace() \n sprint(showerror, e, bt) \n end").c_str());
        if (jl_is_string((jl_value_t*) jfs.function)){
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrostjulia:functionDoesNotExist"),
                factory.createScalar(u"\nMATFrost.jl error:\nFunction does not exist! \n\n\n " + matlab::engine::convertUTF8StringToUTF16String(jl_string_ptr((jl_value_t*) jfs.function)))}));
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
            jl_value_t* jlargs[nargs];
            for (size_t i=0; i < nargs; i++){
                jlargs[i] = convert_to_julia_typed(std::move(inputs[i+1]), jfs.arguments[i]);
            }

            jl_value_t **jlargs_p = jlargs;

            
            JL_GC_PUSHARGS(jlargs_p, nargs);
            
            // Enabled as intended Julia function is called.
            jl_gc_enable(1);

            // The JUICE: The Julia call!
            jl_value_t* jlo = jl_call(jfs.function, jlargs, nargs);

            
            if (jlo != nullptr){

                // Disabled as several calls to jl* are made to destructure the data. 
                jl_gc_enable(0);

                outputs[0] = convert_to_matlab((jl_value_t*) jlo);

                // Data has been copied to MATLAB domain, so Julia can start Garbage collection again.
                jl_gc_enable(1);             
            }

            JL_GC_POP();
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


    jl_value_t* convert_to_julia(matlab::data::Array &&marr){
        if (marr.getNumberOfElements() == 1){
            return convert_to_julia_scalar(std::move(marr));
        } else {
            return convert_to_julia_array(std::move(marr));
        }
    }

    
    jl_value_t* convert_to_julia_primitive_or_complex_scalar(matlab::data::Array &&marr){
        if (marr.getNumberOfElements() != 1){
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrostjulia:argumentInvalid"),
                factory.createScalar(u"\nMATFrost.jl error:\nExpecting a scalar value on MATLAB side.")}));
        }
        switch (marr.getType())
        {
            case matlab::data::ArrayType::SINGLE:
                return jl_box_float32(((matlab::data::TypedArray<float>) std::move(marr))[0]); 
            case matlab::data::ArrayType::DOUBLE:
                return jl_box_float64(((matlab::data::TypedArray<double>) std::move(marr))[0]);

                
            case matlab::data::ArrayType::COMPLEX_SINGLE:
                return convert_to_julia_complex_scalar<float>(std::move(marr), jl_box_float32, jl_float32_type);
            case matlab::data::ArrayType::COMPLEX_DOUBLE:
                return convert_to_julia_complex_scalar<double>(std::move(marr), jl_box_float64, jl_float64_type);

            case matlab::data::ArrayType::LOGICAL:
                return jl_box_bool(((matlab::data::TypedArray<bool>) std::move(marr))[0]); 

            case matlab::data::ArrayType::INT8:
                return jl_box_int8(((matlab::data::TypedArray<int8_t>) std::move(marr))[0]); 
            case matlab::data::ArrayType::UINT8:
                return jl_box_uint8(((matlab::data::TypedArray<uint8_t>) std::move(marr))[0]); 
            case matlab::data::ArrayType::INT16:
                return jl_box_int16(((matlab::data::TypedArray<int16_t>) std::move(marr))[0]); 
            case matlab::data::ArrayType::UINT16:
                return jl_box_uint16(((matlab::data::TypedArray<uint16_t>) std::move(marr))[0]); 
            case matlab::data::ArrayType::INT32:
                return jl_box_int32(((matlab::data::TypedArray<int32_t>) std::move(marr))[0]); 
            case matlab::data::ArrayType::UINT32:
                return jl_box_uint32(((matlab::data::TypedArray<uint32_t>) std::move(marr))[0]); 
            case matlab::data::ArrayType::INT64:
                return jl_box_int64(((matlab::data::TypedArray<int64_t>) std::move(marr))[0]); 
            case matlab::data::ArrayType::UINT64:
                return jl_box_uint64(((matlab::data::TypedArray<uint64_t>) std::move(marr))[0]); 

            case matlab::data::ArrayType::COMPLEX_INT8:
                return convert_to_julia_complex_scalar<int8_t>(std::move(marr), jl_box_int8, jl_int8_type);
            case matlab::data::ArrayType::COMPLEX_UINT8:
                return convert_to_julia_complex_scalar<uint8_t>(std::move(marr), jl_box_uint8, jl_uint8_type);
                
            case matlab::data::ArrayType::COMPLEX_INT16:
                return convert_to_julia_complex_scalar<int16_t>(std::move(marr), jl_box_int16, jl_int16_type);
            case matlab::data::ArrayType::COMPLEX_UINT16:
                return convert_to_julia_complex_scalar<uint16_t>(std::move(marr), jl_box_uint16, jl_uint16_type);

            case matlab::data::ArrayType::COMPLEX_INT32:
                return convert_to_julia_complex_scalar<int32_t>(std::move(marr), jl_box_int32, jl_int32_type);
            case matlab::data::ArrayType::COMPLEX_UINT32:
                return convert_to_julia_complex_scalar<uint32_t>(std::move(marr), jl_box_uint32, jl_uint32_type);

            case matlab::data::ArrayType::COMPLEX_INT64:
                return convert_to_julia_complex_scalar<int64_t>(std::move(marr), jl_box_int64, jl_int64_type);
            case matlab::data::ArrayType::COMPLEX_UINT64:
                return convert_to_julia_complex_scalar<uint64_t>(std::move(marr), jl_box_uint64, jl_uint64_type);

        }
        matlab::data::ArrayFactory factory;
        matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
            factory.createScalar("matfrostjulia:argumentInvalid"),
            factory.createScalar(u"\nMATFrost.jl error:\nUnsupported MATLAB Type")}));
    }


   

    jl_value_t* convert_to_julia_scalar(matlab::data::Array &&marr){
        switch (marr.getType())
        {
            case matlab::data::ArrayType::CELL:
                return convert_to_julia_cell_array((matlab::data::CellArray) std::move(marr));        
            case matlab::data::ArrayType::STRUCT:
                return convert_to_julia_struct_scalar((matlab::data::StructArray) std::move(marr));

            
            case matlab::data::ArrayType::CHAR:
                return convert_to_julia_string((matlab::data::CharArray) std::move(marr)); 
            case matlab::data::ArrayType::MATLAB_STRING:
                return convert_to_julia_string_scalar((matlab::data::StringArray) std::move(marr));

            default:
                return convert_to_julia_primitive_or_complex_scalar(std::move(marr));

        }
        // throw std::invalid_argument("Unsupported MATLAB Type" );
    }

    template<typename T>
    jl_value_t* convert_to_julia_complex_scalar(matlab::data::Array &&marr, jl_value_t* (*jlbox)(T), jl_datatype_t* jldat){
        jl_value_t* jlcomplex = (jl_value_t*) jl_get_function(jl_base_module, "Complex");
        std::complex<T> v = ((matlab::data::TypedArray<std::complex<T>>) std::move(marr))[0];
        return jl_new_struct((jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jldat), jlbox(v.real()), jlbox(v.imag())); 
    }


    jl_value_t* convert_to_julia_array(matlab::data::Array &&marr){
        jl_value_t* jlcomplex = (jl_value_t*) jl_get_function(jl_base_module, "Complex");
        switch (marr.getType())
        {
            case matlab::data::ArrayType::CELL:
                return convert_to_julia_cell_array((matlab::data::CellArray) std::move(marr));        
            case matlab::data::ArrayType::STRUCT:
                return convert_to_julia_struct_array((matlab::data::StructArray) std::move(marr));
            
            case matlab::data::ArrayType::CHAR:
                return convert_to_julia_string((matlab::data::CharArray) std::move(marr)); 
            case matlab::data::ArrayType::MATLAB_STRING:
                return convert_to_julia_string_array((matlab::data::StringArray) std::move(marr));

            case matlab::data::ArrayType::SINGLE:
                return convert_to_julia_primitive_array<float>(std::move(marr), jl_float32_type); 
            case matlab::data::ArrayType::DOUBLE:
                return convert_to_julia_primitive_array<double>(std::move(marr), jl_float64_type);

                
            case matlab::data::ArrayType::COMPLEX_SINGLE:
                return convert_to_julia_primitive_array<std::complex<float>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_float32_type)); 
            case matlab::data::ArrayType::COMPLEX_DOUBLE:
                return convert_to_julia_primitive_array<std::complex<double>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_float64_type));

            case matlab::data::ArrayType::LOGICAL:
                return convert_to_julia_primitive_array<bool>(std::move(marr), jl_bool_type);

            case matlab::data::ArrayType::INT8:
                return convert_to_julia_primitive_array<int8_t>(std::move(marr), jl_int8_type);
            case matlab::data::ArrayType::UINT8:
                return convert_to_julia_primitive_array<uint8_t>(std::move(marr), jl_uint8_type);
            case matlab::data::ArrayType::INT16:
                return convert_to_julia_primitive_array<int16_t>(std::move(marr), jl_int16_type);
            case matlab::data::ArrayType::UINT16:
                return convert_to_julia_primitive_array<uint16_t>(std::move(marr), jl_uint16_type);
            case matlab::data::ArrayType::INT32:
                return convert_to_julia_primitive_array<int32_t>(std::move(marr), jl_int32_type);
            case matlab::data::ArrayType::UINT32:
                return convert_to_julia_primitive_array<uint32_t>(std::move(marr), jl_uint32_type);
            case matlab::data::ArrayType::INT64:
                return convert_to_julia_primitive_array<int64_t>(std::move(marr), jl_int64_type);
            case matlab::data::ArrayType::UINT64:
                return convert_to_julia_primitive_array<uint64_t>(std::move(marr), jl_uint64_type);


            
            case matlab::data::ArrayType::COMPLEX_INT8:
                return convert_to_julia_primitive_array<std::complex<int8_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_int8_type)); 
            case matlab::data::ArrayType::COMPLEX_UINT8:
                return convert_to_julia_primitive_array<std::complex<uint8_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_uint8_type));
                
            case matlab::data::ArrayType::COMPLEX_INT16:
                return convert_to_julia_primitive_array<std::complex<int16_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_int16_type)); 
            case matlab::data::ArrayType::COMPLEX_UINT16:
                return convert_to_julia_primitive_array<std::complex<uint16_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_uint16_type));
                
            case matlab::data::ArrayType::COMPLEX_INT32:
                return convert_to_julia_primitive_array<std::complex<int32_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_int32_type)); 
            case matlab::data::ArrayType::COMPLEX_UINT32:
                return convert_to_julia_primitive_array<std::complex<uint32_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_uint32_type));
                
            case matlab::data::ArrayType::COMPLEX_INT64:
                return convert_to_julia_primitive_array<std::complex<int64_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_int64_type)); 
            case matlab::data::ArrayType::COMPLEX_UINT64:
                return convert_to_julia_primitive_array<std::complex<uint64_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_uint64_type));

        }
        matlab::data::ArrayFactory factory;
        matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
            factory.createScalar("matfrostjulia:argumentInvalid"),
            factory.createScalar(u"\nMATFrost.jl error:\nUnsupported MATLAB Type")}));
        
    }

    jl_value_t* convert_to_julia_struct_scalar(matlab::data::StructArray &&marr){
        auto fieldnames_it = marr.getFieldNames();

        // i.e. 3 for struct('x', 1, 'y', 2, 'z', 3)
        size_t nfields = marr.getNumberOfFields();
        size_t nel     = marr.getNumberOfElements();

        size_t fname_i = 0;

        std::string fieldnames[nfields];
        jl_sym_t *fieldnames_jlsym[nfields];

        for (auto fieldname:fieldnames_it){
            fieldnames[fname_i] = std::string(fieldname);
            fieldnames_jlsym[fname_i] = jl_symbol(fieldnames[fname_i].c_str());
            fname_i++;
        }
        
        jl_function_t* tup_f     = jl_get_function(jl_base_module, "tuple");
        jl_function_t* ntup_t    = jl_get_function(jl_base_module, "NTuple");

        // i.e. NamedTuple{(:x,:y,:z), NTuple{3, Any}}
        jl_value_t* nametup_s_t = jl_apply_type1(
            (jl_value_t*) jl_namedtuple_type,
            jl_call(tup_f, (jl_value_t**) fieldnames_jlsym, nfields));


        matlab::data::Struct st = std::move(marr[0]);

        jl_value_t* fieldvalues[nfields];

        for (size_t fi = 0 ; fi<nfields; fi++){
            fieldvalues[fi] = (jl_value_t*) convert_to_julia(std::move(st[fieldnames[fi]]));
        }
        
        return jl_call1(nametup_s_t, jl_call(tup_f, fieldvalues, nfields));


       
    }

    jl_value_t* convert_to_julia_struct_array(matlab::data::StructArray &&marr){
        auto fieldnames_it = marr.getFieldNames();

        // i.e. 3 for struct('x', 1, 'y', 2, 'z', 3)
        size_t nfields = marr.getNumberOfFields();
        size_t nel     = marr.getNumberOfElements();

        size_t fname_i = 0;

        std::string fieldnames[nfields];
        jl_sym_t *fieldnames_jlsym[nfields];

        for (auto fieldname:fieldnames_it){
            fieldnames[fname_i] = std::string(fieldname);
            fieldnames_jlsym[fname_i] = jl_symbol(fieldnames[fname_i].c_str());
            fname_i++;
        }
        
        jl_function_t* tup_f     = jl_get_function(jl_base_module, "tuple");

        // i.e. NamedTuple{(:x,:y,:z)}
        jl_value_t* nametup_s_t = jl_apply_type1(
            (jl_value_t*) jl_namedtuple_type,
            jl_call(tup_f, (jl_value_t**) fieldnames_jlsym, nfields));

        size_t ndims;
        jl_value_t* dimstup;
        std::tie(dimstup, ndims) = convert_to_julia_array_dimensions(marr.getDimensions());
        // i.e. Array{NamedTuple{(:x,:y,:z), NTuple{3, Any}}, 2}
      
        matlab::data::TypedIterator<matlab::data::Struct> it(std::move(marr).begin()); 

        jl_datatype_t* jlstruct_t[nel];
        jl_value_t* jlstructs[nel];

        for (size_t i = 0; i < nel; i++){
            matlab::data::Struct st = std::move(it[i]);

            jl_value_t* fieldvalues[nfields];

            for (size_t fi = 0 ; fi<nfields; fi++){
                fieldvalues[fi] = (jl_value_t*) convert_to_julia(std::move(st[fieldnames[fi]]));
            }
            
            jlstructs[i] = jl_call1(nametup_s_t, jl_call(tup_f, fieldvalues, nfields));
            jlstruct_t[i] = (jl_datatype_t*) jl_typeof(jlstructs[i]);
            // jl_call3(setindex, (jl_value_t*) jlarr, jlstruct, jl_box_int64(i+1));
        }

        // Determine the common type
        jl_value_t* jleltype = jl_call(jl_get_function(jl_base_module, "promote_type"), (jl_value_t**) jlstruct_t, nel);

        jl_value_t* jlarr_t = jl_apply_array_type(jleltype, ndims);
        jl_array_t* jlarr = jl_new_array(jlarr_t, dimstup);
        
        jl_function_t *setindex = jl_get_function(jl_base_module, "setindex!");

        for (size_t i = 0; i < nel; i++){
            jl_call3(setindex, (jl_value_t*) jlarr, jlstructs[i], jl_box_int64(i+1));
        }
        
        return (jl_value_t*) jlarr;
    }

    jl_value_t* convert_to_julia_cell_array(matlab::data::CellArray &&marr){
        
        size_t nel = marr.getNumberOfElements();

        size_t ndims;
        jl_value_t* dimstup;
        std::tie(dimstup, ndims) = convert_to_julia_array_dimensions(marr.getDimensions());

        jl_value_t* jlarr_t = jl_apply_array_type((jl_value_t*) jl_any_type, ndims);
        jl_array_t* jlarr = jl_new_array(jlarr_t, dimstup);

        matlab::data::TypedIterator<matlab::data::Array> it(std::move(marr).begin()); 

        jl_function_t *setindex = jl_get_function(jl_base_module, "setindex!");
        
        for (size_t i = 0; i < nel; i++){
            jl_value_t* subarr = convert_to_julia(std::move(it[i]));
            jl_call3(setindex, (jl_value_t*) jlarr, subarr, jl_box_int64(i+1));
        }
        return (jl_value_t*) jlarr;
    }

    jl_value_t* convert_to_julia_string_array(matlab::data::StringArray &&mtarr){
        size_t nel = mtarr.getNumberOfElements();     
        
        matlab::data::ArrayDimensions dims = mtarr.getDimensions();

        size_t ndims;
        jl_value_t* dimstup;
        std::tie(dimstup, ndims) = convert_to_julia_array_dimensions(mtarr.getDimensions());
   
        jl_value_t* jlarr_t = jl_apply_array_type((jl_value_t*) jl_string_type, ndims);
        jl_array_t* jlarr = jl_new_array(jlarr_t, dimstup);
        
        matlab::data::TypedIterator<matlab::data::MATLABString> it(std::move(mtarr).begin()); 

        jl_function_t *setindex = jl_get_function(jl_base_module, "setindex!");

        for (size_t i = 0; i < nel; i++){
            jl_value_t* jls = convert_to_julia_string(std::move(it[i]));
            jl_call3(setindex, (jl_value_t*) jlarr, jls, jl_box_int64(i+1));
        }
        return (jl_value_t*) jlarr;

    }

    jl_value_t* convert_to_julia_string(matlab::data::MATLABString &&ms){
        
        if (ms.has_value()){         
    
            matlab::data::String sv = *ms;
            
            std::string s8 = matlab::engine::convertUTF16StringToUTF8String(sv);
            return jl_cstr_to_string(s8.c_str());
        } 
        else {
            return jl_cstr_to_string(""); // Empty string
        }
    }

    jl_value_t* convert_to_julia_string_scalar(matlab::data::StringArray &&mtarr){

        return convert_to_julia_string(std::move(mtarr[0]));

    }

    jl_value_t* convert_to_julia_string(matlab::data::CharArray &&mtarr){
        size_t nel = mtarr.getNumberOfElements();     
        

        auto s = mtarr.toUTF16();
        std::string s8 = matlab::engine::convertUTF16StringToUTF8String(s);

        return jl_cstr_to_string(s8.c_str());
    }


    template<typename T>
    jl_value_t* convert_to_julia_primitive_array(matlab::data::Array &&marr, jl_datatype_t* jl_prim_type){
        matlab::data::TypedArray<T> &&mtarr = (matlab::data::TypedArray<T> &&) std::move(marr);
        size_t nel = mtarr.getNumberOfElements();     
    
        size_t ndims;
        jl_value_t* dimstup;
        std::tie(dimstup, ndims) = convert_to_julia_array_dimensions(mtarr.getDimensions());
   
        jl_value_t* jlarr_t = jl_apply_array_type((jl_value_t*) jl_prim_type, ndims);
        jl_array_t* jlarr = jl_new_array(jlarr_t, dimstup);

        matlab::data::buffer_ptr_t<T> mtarrbuf = mtarr.release();
        void* jlarr_p = jl_array_ptr(jlarr);
        memcpy(jlarr_p, mtarrbuf.get(), nel*sizeof(T)); 

        return (jl_value_t*) jlarr;
    }
    
    std::tuple<jl_value_t*, size_t> convert_to_julia_array_dimensions(matlab::data::ArrayDimensions dims){
        size_t n = dims.size();

        // Map to Vector if Matrix of size: n x 1
        if (n == 2 && dims[1] == 1){
            n = 1;
        }

        jl_value_t* dimsjlv[n];
        
        for (size_t di = 0; di < n; di++){
            dimsjlv[di] = jl_box_int64(dims[di]);
        }  
        return std::make_tuple(jl_call(jl_get_function(jl_base_module, "tuple"), dimsjlv, n), n);

    }

    std::string convert_to_julia_typed_cannot_convert(matlab::data::Array &&marr, jl_datatype_t* jldat_t){
        std::string sarr = convert_to_u8string(jl_call1(jl_get_function(jl_main_module, "string"), (jl_value_t*) jldat_t));

        std::vector<matlab::data::Array> dispo = matlabPtr->feval(u"formattedDisplayText", 1, std::vector<matlab::data::Array>({marr}));
        matlab::data::MATLABString msval = ((matlab::data::StringArray) dispo[0])[0];
        std::string sval = matlab::engine::convertUTF16StringToUTF8String(*msval);
        
        std::vector<matlab::data::Array> typeo = matlabPtr->feval(u"class", 1, std::vector<matlab::data::Array>({marr}));
        matlab::data::CharArray mstype = (matlab::data::CharArray) typeo[0];
        std::string stype = matlab::engine::convertUTF16StringToUTF8String(mstype.toUTF16());

        return "\nNo conversion exists for:\n    MATLAB value: \n" + sval + "\n    MATLAB type:\n    " + stype + "[]\n->\n    Julia type: \n    " + sarr;
    }
    
    // Typed governs the conversion if the argument types were given on the frontend. 

    jl_value_t* convert_to_julia_typed(matlab::data::Array &&marr, jl_datatype_t* jldat_t){
        
        jl_value_t* jlcomplex = (jl_value_t*) jl_get_function(jl_base_module, "Complex");

        if (jl_is_primitivetype(jldat_t) || jl_subtype((jl_value_t*) jldat_t, jlcomplex)){
            return convert_to_julia_typed_primitive_or_complex_scalar(std::move(marr), jldat_t);
        }
        else if(jldat_t == jl_string_type){
            switch (marr.getType())
            {
                case matlab::data::ArrayType::CHAR:
                    return convert_to_julia_string((matlab::data::CharArray &&) std::move(marr)); 
                case matlab::data::ArrayType::MATLAB_STRING:
                    matlab::data::StringArray&& msa = (matlab::data::StringArray &&) std::move(marr);
                    return convert_to_julia_string(std::move(msa[0]));
            }
        }
        else if (jl_is_tuple_type(jldat_t)){
            return convert_to_julia_typed_tuple(std::move(marr), jldat_t);
        }
        else if (jl_is_array_type(jldat_t)){
            return convert_to_julia_typed_array(std::move(marr), jldat_t);
        } else if(jl_is_structtype(jldat_t) || jl_is_namedtuple_type(jldat_t)){
            if (marr.getType() == matlab::data::ArrayType::STRUCT){
                matlab::data::StructArray&& mtarr = (matlab::data::StructArray&&) std::move(marr);
                return convert_to_julia_typed_struct(std::move(mtarr[0]), jldat_t);
            } 
        }

        matlab::data::ArrayFactory factory;
        matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
            factory.createScalar("matfrostjulia:argumentInvalid"),
            factory.createScalar("\nMATFrost.jl error:\n" + convert_to_julia_typed_cannot_convert(std::move(marr), jldat_t))}));

    }

    
    template<typename T>
    jl_value_t* convert_to_julia_typed_primitive_scalar(matlab::data::Array &&marr, jl_value_t* (*jlbox)(T), jl_datatype_t* matelt, jl_datatype_t* jldat){
        
        if (matelt !=  jldat){
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrostjulia:argumentInvalid"),
                factory.createScalar("\nMATFrost.jl error:\n" + convert_to_julia_typed_cannot_convert(std::move(marr), jldat))}));

        }

        return jlbox(((matlab::data::TypedArray<T>&&) std::move(marr))[0]); 

    }

    template<typename T>
    jl_value_t* convert_to_julia_typed_complex_scalar(matlab::data::Array &&marr, jl_value_t* (*jlbox)(T), jl_datatype_t* matelt, jl_datatype_t* jldat){
        
        jl_value_t* jlcomplex = (jl_value_t*) jl_get_function(jl_base_module, "Complex");
        if (jldat != (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) matelt)){
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrostjulia:argumentInvalid"),
                factory.createScalar("\nMATFrost.jl error:\n" + convert_to_julia_typed_cannot_convert(std::move(marr), jldat))}));
        }

        std::complex<T> v = ((matlab::data::TypedArray<std::complex<T>>&&) std::move(marr))[0];

        return jl_new_struct(jldat, jlbox(v.real()), jlbox(v.imag())); 

    }

    jl_value_t* convert_to_julia_typed_primitive_or_complex_scalar(matlab::data::Array &&marr, jl_datatype_t* jldat){
        if (marr.getNumberOfElements() == 1){
            switch (marr.getType())
            {
                case matlab::data::ArrayType::SINGLE:
                    return convert_to_julia_typed_primitive_scalar<float>(std::move(marr), jl_box_float32, jl_float32_type, jldat);
                case matlab::data::ArrayType::DOUBLE:
                    return convert_to_julia_typed_primitive_scalar<double>(std::move(marr), jl_box_float64, jl_float64_type, jldat);
                    
                case matlab::data::ArrayType::COMPLEX_SINGLE:
                    return convert_to_julia_typed_complex_scalar<float>(std::move(marr), jl_box_float32, jl_float32_type, jldat);
                case matlab::data::ArrayType::COMPLEX_DOUBLE:
                    return convert_to_julia_typed_complex_scalar<double>(std::move(marr), jl_box_float64, jl_float64_type, jldat);

                case matlab::data::ArrayType::LOGICAL:
                    return convert_to_julia_typed_primitive_scalar<int8_t>(std::move(marr), jl_box_bool, jl_bool_type, jldat);

                case matlab::data::ArrayType::INT8:
                    return convert_to_julia_typed_primitive_scalar<int8_t>(std::move(marr), jl_box_int8, jl_int8_type, jldat);
                case matlab::data::ArrayType::UINT8:
                    return convert_to_julia_typed_primitive_scalar<uint8_t>(std::move(marr), jl_box_uint8, jl_uint8_type, jldat);
                case matlab::data::ArrayType::INT16:
                    return convert_to_julia_typed_primitive_scalar<int16_t>(std::move(marr), jl_box_int16, jl_int16_type, jldat);
                case matlab::data::ArrayType::UINT16:
                    return convert_to_julia_typed_primitive_scalar<uint16_t>(std::move(marr), jl_box_uint16, jl_uint16_type, jldat); 
                case matlab::data::ArrayType::INT32:
                    return convert_to_julia_typed_primitive_scalar<int32_t>(std::move(marr), jl_box_int32, jl_int32_type, jldat);
                case matlab::data::ArrayType::UINT32:
                    return convert_to_julia_typed_primitive_scalar<uint32_t>(std::move(marr), jl_box_uint32, jl_uint32_type, jldat); 
                case matlab::data::ArrayType::INT64:
                    return convert_to_julia_typed_primitive_scalar<int64_t>(std::move(marr), jl_box_int64, jl_int64_type, jldat); 
                case matlab::data::ArrayType::UINT64:
                    return convert_to_julia_typed_primitive_scalar<uint64_t>(std::move(marr), jl_box_uint64, jl_uint64_type, jldat); 

                case matlab::data::ArrayType::COMPLEX_INT8:
                    return convert_to_julia_typed_complex_scalar<int8_t>(std::move(marr), jl_box_int8, jl_int8_type, jldat);
                case matlab::data::ArrayType::COMPLEX_UINT8:
                    return convert_to_julia_typed_complex_scalar<uint8_t>(std::move(marr), jl_box_uint8, jl_uint8_type, jldat);
                case matlab::data::ArrayType::COMPLEX_INT16:
                    return convert_to_julia_typed_complex_scalar<int16_t>(std::move(marr), jl_box_int16, jl_int16_type, jldat);
                case matlab::data::ArrayType::COMPLEX_UINT16:
                    return convert_to_julia_typed_complex_scalar<uint16_t>(std::move(marr), jl_box_uint16, jl_uint16_type, jldat); 
                case matlab::data::ArrayType::COMPLEX_INT32:
                    return convert_to_julia_typed_complex_scalar<int32_t>(std::move(marr), jl_box_int32, jl_int32_type, jldat);
                case matlab::data::ArrayType::COMPLEX_UINT32:
                    return convert_to_julia_typed_complex_scalar<uint32_t>(std::move(marr), jl_box_uint32, jl_uint32_type, jldat); 
                case matlab::data::ArrayType::COMPLEX_INT64:
                    return convert_to_julia_typed_complex_scalar<int64_t>(std::move(marr), jl_box_int64, jl_int64_type, jldat); 
                case matlab::data::ArrayType::COMPLEX_UINT64:
                    return convert_to_julia_typed_complex_scalar<uint64_t>(std::move(marr), jl_box_uint64, jl_uint64_type, jldat); 

            }
        }
        matlab::data::ArrayFactory factory;
        matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
            factory.createScalar("matfrostjulia:argumentInvalid"),
            factory.createScalar("\nMATFrost.jl error:\n" + convert_to_julia_typed_cannot_convert(std::move(marr), jldat))}));
    }
    

    template<typename T>
    jl_value_t* convert_to_julia_typed_primitive_array(matlab::data::Array &&marr, jl_datatype_t* matelt, jl_datatype_t* jlarr_t){
        
        if (matelt != (jl_datatype_t*) jl_tparam0((jl_value_t*) jlarr_t) ){
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrostjulia:argumentInvalid"),
                factory.createScalar("\nMATFrost.jl error:\n" + convert_to_julia_typed_cannot_convert(std::move(marr), jlarr_t))}));
        }

        matlab::data::TypedArray<T> &&mtarr = (matlab::data::TypedArray<T> &&) std::move(marr);
        size_t nel = mtarr.getNumberOfElements();     
    
        jl_value_t* dimstup = convert_to_julia_typed_array_dimensions(mtarr.getDimensions(), jlarr_t);
   
        jl_array_t* jlarr = jl_new_array((jl_value_t*) jlarr_t, dimstup);

        matlab::data::buffer_ptr_t<T> mtarrbuf = mtarr.release();
        void* jlarr_p = jl_array_ptr(jlarr);
        memcpy(jlarr_p, mtarrbuf.get(), nel*sizeof(T)); 

        return (jl_value_t*) jlarr;
    }

    jl_value_t* convert_to_julia_typed_string_array(matlab::data::StringArray &&mtarr, jl_datatype_t* jlarr_t){

        // return jl_cstr_to_string("");

        if (jl_string_type != (jl_datatype_t*) jl_tparam0((jl_value_t*) jlarr_t) ){
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrostjulia:argumentInvalid"),
                factory.createScalar("\nMATFrost.jl error:\nCannot convert array. Expecting Strings")}));
        }

        size_t nel = mtarr.getNumberOfElements();     
    
        jl_value_t* dimstup = convert_to_julia_typed_array_dimensions(mtarr.getDimensions(), jlarr_t);
   
        jl_array_t* jlarr = jl_new_array((jl_value_t*) jlarr_t, dimstup);
        
        matlab::data::TypedIterator<matlab::data::MATLABString> it(std::move(mtarr).begin()); 

        jl_function_t *setindex = jl_get_function(jl_base_module, "setindex!");

        for (size_t i = 0; i < nel; i++){
            jl_value_t* jls = convert_to_julia_string(std::move(it[i]));
            jl_call3(setindex, (jl_value_t*) jlarr, jls, jl_box_int64(i+1));
        }
        return (jl_value_t*) jlarr;

    }

    jl_value_t* convert_to_julia_typed_string_array(matlab::data::CharArray &&mtarr, jl_datatype_t* jlarr_t){

        if (jl_string_type != (jl_datatype_t*) jl_tparam0((jl_value_t*) jlarr_t) ){
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                factory.createScalar("matfrostjulia:argumentInvalid"),
                factory.createScalar("\nMATFrost.jl error:\nCannot convert array. Expecting Strings")}));
        }
    
        jl_value_t* dimstup = convert_to_julia_typed_array_dimensions(matlab::data::ArrayDimensions{1,1}, jlarr_t);
   
        jl_array_t* jlarr = jl_new_array((jl_value_t*) jlarr_t, dimstup);
        
        jl_function_t *setindex = jl_get_function(jl_base_module, "setindex!");

        jl_value_t* jls = convert_to_julia_string(std::move(mtarr));
        jl_call3(setindex, (jl_value_t*) jlarr, jls, jl_box_int64(1));
       
        return (jl_value_t*) jlarr;

    }
    
    jl_value_t* convert_to_julia_typed_array_dimensions(matlab::data::ArrayDimensions dimsmat, jl_datatype_t* jlarr_t){

        size_t ndims = jl_unbox_int64(jl_tparam1((jl_value_t*) jlarr_t));

        for (size_t idim = ndims; idim < dimsmat.size(); idim++){
            if (dimsmat[idim] != 1){
                std::stringstream ss;

                size_t actualnumdims = 0;
                for (size_t idim = ndims; idim < dimsmat.size(); idim++){
                     if (dimsmat[idim] != 1){
                        actualnumdims = idim+1;
                    }
                }

                ss << "\nArray dimensions incompatible:\n    Expect array: numdims=" << 
                    std::to_string(ndims) << "\n    Actual array: numdims=" << std::to_string(actualnumdims) << 
                    "; dimensions=[";
                for (size_t idim = 0; idim < dimsmat.size(); idim++){
                    ss << dimsmat[idim] << ", ";
                }
                ss << "]\n";
                matlab::data::ArrayFactory factory;
                matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
                    factory.createScalar("matfrostjulia:argumentInvalid"),
                    factory.createScalar("\nMATFrost.jl error:\n" + ss.str())}));
            }
        }

        jl_value_t* dimsjlv[ndims];
        
        for (size_t di = 0; di < ndims; di++){
            if (di < dimsmat.size()){
                dimsjlv[di] = jl_box_int64(dimsmat[di]);
            } else {
                dimsjlv[di] = jl_box_int64(1);
            }
        }  
        return jl_call(jl_get_function(jl_base_module, "tuple"), dimsjlv, ndims);

    }


    jl_value_t* convert_to_julia_typed_array(matlab::data::Array &&marr, jl_datatype_t* jlarr_t){
        
        jl_datatype_t* jlel_t = (jl_datatype_t*) jl_tparam0(jlarr_t);

        jl_value_t* jlcomplex = (jl_value_t*) jl_get_function(jl_base_module, "Complex");

        if (jl_is_primitivetype(jlel_t)){
            switch (marr.getType())
            {
                case matlab::data::ArrayType::SINGLE:
                    return convert_to_julia_typed_primitive_array<float>(std::move(marr), jl_float32_type, jlarr_t); 
                case matlab::data::ArrayType::DOUBLE:
                    return convert_to_julia_typed_primitive_array<double>(std::move(marr), jl_float64_type, jlarr_t);
                case matlab::data::ArrayType::LOGICAL:
                    return convert_to_julia_typed_primitive_array<bool>(std::move(marr), jl_bool_type, jlarr_t);
                case matlab::data::ArrayType::INT8:
                    return convert_to_julia_typed_primitive_array<int8_t>(std::move(marr), jl_int8_type, jlarr_t);
                case matlab::data::ArrayType::UINT8:
                    return convert_to_julia_typed_primitive_array<uint8_t>(std::move(marr), jl_uint8_type, jlarr_t);
                case matlab::data::ArrayType::INT16:
                    return convert_to_julia_typed_primitive_array<int16_t>(std::move(marr), jl_int16_type, jlarr_t);
                case matlab::data::ArrayType::UINT16:
                    return convert_to_julia_typed_primitive_array<uint16_t>(std::move(marr), jl_uint16_type, jlarr_t);
                case matlab::data::ArrayType::INT32:
                    return convert_to_julia_typed_primitive_array<int32_t>(std::move(marr), jl_int32_type, jlarr_t);
                case matlab::data::ArrayType::UINT32:
                    return convert_to_julia_typed_primitive_array<uint32_t>(std::move(marr), jl_uint32_type, jlarr_t);
                case matlab::data::ArrayType::INT64:
                    return convert_to_julia_typed_primitive_array<int64_t>(std::move(marr), jl_int64_type, jlarr_t);
                case matlab::data::ArrayType::UINT64:
                    return convert_to_julia_typed_primitive_array<uint64_t>(std::move(marr), jl_uint64_type, jlarr_t);
            }
        }
        else if (jl_subtype((jl_value_t*) jlel_t, jlcomplex)){
            switch (marr.getType())
            {                       
                case matlab::data::ArrayType::COMPLEX_SINGLE:
                    return convert_to_julia_typed_primitive_array<std::complex<float>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_float32_type), jlarr_t); 
                case matlab::data::ArrayType::COMPLEX_DOUBLE:
                    return convert_to_julia_typed_primitive_array<std::complex<double>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_float64_type), jlarr_t);
                case matlab::data::ArrayType::COMPLEX_INT8:
                    return convert_to_julia_typed_primitive_array<std::complex<int8_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_int8_type), jlarr_t); 
                case matlab::data::ArrayType::COMPLEX_UINT8:
                    return convert_to_julia_typed_primitive_array<std::complex<uint8_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_uint8_type), jlarr_t);
                case matlab::data::ArrayType::COMPLEX_INT16:
                    return convert_to_julia_typed_primitive_array<std::complex<int16_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_int16_type), jlarr_t); 
                case matlab::data::ArrayType::COMPLEX_UINT16:
                    return convert_to_julia_typed_primitive_array<std::complex<uint16_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_uint16_type), jlarr_t);
                case matlab::data::ArrayType::COMPLEX_INT32:
                    return convert_to_julia_typed_primitive_array<std::complex<int32_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_int32_type), jlarr_t); 
                case matlab::data::ArrayType::COMPLEX_UINT32:
                    return convert_to_julia_typed_primitive_array<std::complex<uint32_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_uint32_type), jlarr_t);
                case matlab::data::ArrayType::COMPLEX_INT64:
                    return convert_to_julia_typed_primitive_array<std::complex<int64_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_int64_type), jlarr_t); 
                case matlab::data::ArrayType::COMPLEX_UINT64:
                    return convert_to_julia_typed_primitive_array<std::complex<uint64_t>>(std::move(marr), (jl_datatype_t*) jl_apply_type1(jlcomplex, (jl_value_t*) jl_uint64_type), jlarr_t);

            }
        }
        else if (jlel_t == jl_string_type){
            switch (marr.getType())
            {
                case matlab::data::ArrayType::CHAR:
                    return convert_to_julia_typed_string_array((matlab::data::CharArray &&) std::move(marr), jlarr_t);

                case matlab::data::ArrayType::MATLAB_STRING:
                    return convert_to_julia_typed_string_array((matlab::data::StringArray &&) std::move(marr), jlarr_t);
            }
        }
        else if(jl_is_array_type(jlel_t)||jl_is_tuple_type(jlel_t)){

            if (marr.getType() == matlab::data::ArrayType::CELL){

                matlab::data::CellArray&& ca = (matlab::data::CellArray&&) std::move(marr);

                size_t nel = ca.getNumberOfElements();     
            
                jl_value_t* dimstup = convert_to_julia_typed_array_dimensions(ca.getDimensions(), jlarr_t);
        
                jl_array_t* jlarr = jl_new_array((jl_value_t*) jlarr_t, dimstup);

                jl_function_t* setindex_f = jl_get_function(jl_base_module, "setindex!");

                matlab::data::TypedIterator<matlab::data::Array> it(std::move(ca).begin()); 

                for (size_t i = 0; i < nel; i++){
                    matlab::data::Array&& elmat = std::move(it[i]);

                    jl_value_t* eljl = convert_to_julia_typed(std::move(elmat), jlel_t);

                    jl_call3(setindex_f, (jl_value_t*) jlarr, eljl, jl_box_int64(i+1));

                }

                return (jl_value_t*) jlarr;
            }           
            
        }
        else if (jl_is_structtype(jlel_t) || jl_is_namedtuple_type(jlel_t)){
            if (marr.getType() == matlab::data::ArrayType::STRUCT){
                return convert_to_julia_typed_struct_array((matlab::data::StructArray&&) std::move(marr), jlarr_t);
            }
        }

        matlab::data::ArrayFactory factory;
        matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
        factory.createScalar("matfrostjulia:argumentInvalid"),
            factory.createScalar("\nMATFrost.jl error:\n" + convert_to_julia_typed_cannot_convert(std::move(marr), jlarr_t))}));
    }

    jl_value_t* convert_to_julia_typed_tuple(matlab::data::Array &&marr, jl_datatype_t* jltup_t){
        if (marr.getType() == matlab::data::ArrayType::CELL){
            matlab::data::CellArray&& ca = (matlab::data::CellArray&&) std::move(marr);
            size_t nel = ca.getNumberOfElements();             
            jl_value_t* jlvals[nel];
            matlab::data::TypedIterator<matlab::data::Array> it(std::move(ca).begin()); 
            for (size_t i = 0; i < nel; i++){
                jlvals[i] = convert_to_julia_typed(std::move(it[i]), (jl_datatype_t*) jl_field_type(jltup_t, i));
            }
        
            return jl_call(jl_get_function(jl_base_module, "tuple"), jlvals, nel);
        } else {
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
            factory.createScalar("matfrostjulia:argumentInvalid"),
                factory.createScalar("\nMATFrost.jl error:\n" + convert_to_julia_typed_cannot_convert(std::move(marr), jltup_t))}));
        }
    }

    jl_value_t* convert_to_julia_typed_struct(matlab::data::Struct &&mats, jl_datatype_t* jlstruct_t){

        jl_function_t* fieldnames_f = jl_get_function(jl_base_module, "fieldnames");

        jl_value_t* fieldnames_syms = jl_call1(fieldnames_f, (jl_value_t*) jlstruct_t);

        size_t nfields = jl_datatype_nfields(jlstruct_t);

        jl_value_t* fieldvalues[nfields];

        for (size_t ifield = 0; ifield < nfields; ifield++){
            std::string fieldname = jl_symbol_name((jl_sym_t*) jl_get_nth_field(fieldnames_syms, ifield));
            fieldvalues[ifield] = convert_to_julia_typed(
                std::move(mats[fieldname]), (jl_datatype_t*) jl_field_type(jlstruct_t, ifield));
        }

        return jl_new_structv(jlstruct_t, fieldvalues, nfields);

    }

    jl_value_t* convert_to_julia_typed_struct_array(matlab::data::StructArray &&mtarr, jl_datatype_t* jlarr_t){

        jl_datatype_t* jlel_t = (jl_datatype_t*) jl_tparam0(jlarr_t);

        jl_function_t* fieldnames_f = jl_get_function(jl_base_module, "fieldnames");

        jl_value_t* fieldnames_syms = jl_call1(fieldnames_f, (jl_value_t*) jlel_t);

        size_t nfields = jl_datatype_nfields(jlel_t);

        size_t nel = mtarr.getNumberOfElements();     
    
        jl_value_t* dimstup = convert_to_julia_typed_array_dimensions(mtarr.getDimensions(), jlarr_t);
   
        jl_array_t* jlarr = jl_new_array((jl_value_t*) jlarr_t, dimstup);

        jl_function_t* setindex_f = jl_get_function(jl_base_module, "setindex!");


        matlab::data::TypedIterator<matlab::data::Struct> it(std::move(mtarr).begin()); 

        for (size_t i = 0; i < nel; i++){
            matlab::data::Struct&& matstruct = std::move(it[i]);

            jl_value_t* fieldvalues[nfields];
       

            for (size_t ifield = 0; ifield < nfields; ifield++){
                std::string fieldname = jl_symbol_name((jl_sym_t*) jl_get_nth_field(fieldnames_syms, ifield));
                fieldvalues[ifield] = convert_to_julia_typed(
                    std::move(matstruct[fieldname]), (jl_datatype_t*) jl_field_type(jlel_t, ifield));
            }
            jl_value_t* jlstruct = jl_new_structv(jlel_t, fieldvalues, nfields);

            jl_call3(setindex_f, (jl_value_t*) jlarr, jlstruct, jl_box_int64(i+1));
        }

        return (jl_value_t*) jlarr;
        

    }

    


};