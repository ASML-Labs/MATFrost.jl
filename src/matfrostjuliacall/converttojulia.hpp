
#include <julia.h>
#include "mex.hpp"
#include "mexAdapter.hpp"

#include <tuple>
// stdc++ lib
#include <string>
#include <complex>


namespace MATFrost {
namespace ConvertToJulia {


/**
 * Converter is a bare interface class. Each object of Converter is linked to a Julia type 
 * and is able of convert MATLAB values to this linked Julia type. 
 *  
 */ 
class Converter {
public:
    virtual jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr);
};

/**
 * Construct a converter of given Julia type
 *  
 * @param jltype Construct converter graph of jltype.
 */ 
std::unique_ptr<Converter> converter(jl_datatype_t* jltype);

/**
 * Converts a MATLAB value to a Julia value of a given type. This is the entrypoint for conversions. 
 *  
 * @param marr MATLAB value as matlab::data:Array
 * @param jltype Julia type to convert MATLAB value to
 * @param matlabPtr MATLABEngine.
 */ 
jl_value_t* convert(matlab::data::Array &&marr, jl_datatype_t* jltype, std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr){
    std::unique_ptr<Converter> conv = converter(jltype);
    return conv->convert(std::move(marr), matlabPtr.get());
}


void throw_incompatible_array_dimensions_error(matlab::data::ArrayDimensions dimsmat, jl_datatype_t* jltype, matlab::engine::MATLABEngine* matlabPtr){
    size_t ndims = jl_unbox_int64(jl_tparam1((jl_value_t*) jltype));
    
    jl_value_t* jlts = jl_call1(jl_get_function(jl_base_module, "string"), (jl_value_t*) jltype);
    
    std::stringstream ss;
    ss << "\nMATFrost.jl conversion error:\n\nConverting to: " << jl_string_ptr(jlts) << "\n\nArray dimensions incompatible:\n";
    if (ndims == 1){
        ss << "    Expect array: column-vector (:, 1)"  << "\n";
    } else {
        ss << "    Expect array: numdims=" << 
                std::to_string(ndims) << "\n";
    }

    size_t actualnumdims = 0;
    for (size_t idim = 0; idim < dimsmat.size(); idim++){
        if (dimsmat[idim] != 1){
            actualnumdims = idim+1;
        }
    }

    ss << "    Actual array: numdims=" << std::to_string(actualnumdims) <<
        "; dimensions=[" << dimsmat[0];
    for (size_t idim = 1; idim < dimsmat.size(); idim++){
        ss << ", " << dimsmat[idim];
    }
    ss << "]\n";
    throw matlab::engine::MATLABException(
        "matfrostjulia:conversion:incompatibleArrayDimensions",
        matlab::engine::convertUTF8StringToUTF16String(ss.str()));
}

void throw_not_scalar_value_error(matlab::data::ArrayDimensions dimsmat, jl_datatype_t* jltype, matlab::engine::MATLABEngine* matlabPtr){
    jl_value_t* jlts = jl_call1(jl_get_function(jl_base_module, "string"), (jl_value_t*) jltype);
    
    std::stringstream ss;
    ss << "\nMATFrost.jl conversion error:\n\nConverting to: " << jl_string_ptr(jlts) << 
        "\n\nNot scalar value:\n    Expect array: scalar (1, 1)\n";

    size_t actualnumdims = 0;
    for (size_t idim = 0; idim < dimsmat.size(); idim++){
        if (dimsmat[idim] != 1){
            actualnumdims = idim+1;
        }
    }

    ss << "    Actual array: numdims=" << std::to_string(actualnumdims) <<
        "; dimensions=[" << dimsmat[0];
    for (size_t idim = 1; idim < dimsmat.size(); idim++){
        ss << ", " << dimsmat[idim];
    }
    ss << "]\n";
    throw matlab::engine::MATLABException(
        "matfrostjulia:conversion:notScalarValue",
        matlab::engine::convertUTF8StringToUTF16String(ss.str()));
}


void throw_argument_invalid(matlab::data::Array &&marr, jl_datatype_t* jltype,  matlab::engine::MATLABEngine* matlabPtr){
    std::string sarr(jl_string_ptr((jl_call1(jl_get_function(jl_main_module, "string"), (jl_value_t*) jltype))));

    std::vector<matlab::data::Array> dispo = matlabPtr->feval(u"formattedDisplayText", 1, std::vector<matlab::data::Array>({marr}));
    matlab::data::MATLABString msval = ((matlab::data::StringArray) dispo[0])[0];
    std::string sval = matlab::engine::convertUTF16StringToUTF8String(*msval);
    
    std::vector<matlab::data::Array> typeo = matlabPtr->feval(u"class", 1, std::vector<matlab::data::Array>({marr}));
    matlab::data::CharArray mstype = (matlab::data::CharArray) typeo[0];
    std::string stype = matlab::engine::convertUTF16StringToUTF8String(mstype.toUTF16());

    matlab::data::ArrayFactory factory;
    matlabPtr->feval(u"error", 0, std::vector<matlab::data::Array>({
        factory.createScalar("matfrostjulia:argumentInvalid"),
        factory.createScalar("\nMATFrost.jl error:\n\nNo conversion exists for:\n    MATLAB value: \n" + sval + "\n    MATLAB type:\n    " + stype + "[]\n->\n    Julia type: \n    " + sarr)}));
}

template<typename T>
class PrimitiveConverter : public Converter {
    jl_datatype_t* jltype;
    jl_value_t* (*jlbox)(T);
    matlab::data::ArrayType mattype;
    
public:
    PrimitiveConverter(jl_datatype_t* jltype, jl_value_t* (*jlbox)(T), matlab::data::ArrayType mattype):
        jltype(jltype), 
        jlbox(jlbox), 
        mattype(mattype) 
    {
    }

    jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr) {
        if (marr.getType() != mattype ) {
            throw_argument_invalid(std::move(marr), jltype, matlabPtr);
        } else if(marr.getNumberOfElements() != 1) {
            throw_not_scalar_value_error(marr.getDimensions(), jltype, matlabPtr);
        } else {
            return jlbox(((matlab::data::TypedArray<T>&&) std::move(marr))[0]);
        }
    }
};

template<typename T>
class ComplexPrimitiveConverter : public Converter {
    jl_datatype_t* jltype;
    jl_value_t* (*jlbox)(T);
    matlab::data::ArrayType mattype;
    
public:
    ComplexPrimitiveConverter(jl_datatype_t* jltype, jl_value_t* (*jlbox)(T), matlab::data::ArrayType mattype):
        jltype(jltype), 
        jlbox(jlbox), 
        mattype(mattype) 
    {
    }

    jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr) {
        if (marr.getType() != mattype) {
            throw_argument_invalid(std::move(marr), jltype, matlabPtr);
        } else if(marr.getNumberOfElements() != 1) {
            throw_not_scalar_value_error(marr.getDimensions(), jltype, matlabPtr);
        } else {
            std::complex<T> v = ((matlab::data::TypedArray<std::complex<T>>&&) std::move(marr))[0];
            return jl_new_struct(jltype, jlbox(v.real()), jlbox(v.imag())); 
        }
    }
};

jl_array_t* new_array(matlab::data::ArrayDimensions dimsmat, jl_datatype_t* jltype, matlab::engine::MATLABEngine* matlabPtr){

    size_t ndims = jl_unbox_int64(jl_tparam1((jl_value_t*) jltype));

    for (size_t idim = ndims; idim < dimsmat.size(); idim++){
        if (dimsmat[idim] != 1){
            throw_incompatible_array_dimensions_error(dimsmat, jltype, matlabPtr);
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

    jl_value_t* dimstup =  jl_call(jl_get_function(jl_base_module, "tuple"), dimsjlv, ndims);
   
    jl_array_t* jlarr = jl_new_array((jl_value_t*) jltype, dimstup);

    return jlarr;

}


template<typename T>
class ArrayPrimitiveConverter : public Converter {
    jl_datatype_t* jltype;
    matlab::data::ArrayType mattype;
    
    
public:
    ArrayPrimitiveConverter(jl_datatype_t* jltype, matlab::data::ArrayType mattype):
        jltype(jltype), 
        mattype(mattype)
    {
    }

    jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr) {
        if (mattype != marr.getType()){            
            throw_argument_invalid(std::move(marr), jltype, matlabPtr);
        }

        matlab::data::TypedArray<T> &&mtarr = (matlab::data::TypedArray<T> &&) std::move(marr);
        size_t nel = mtarr.getNumberOfElements();     
    
        jl_array_t* jlarr  = new_array(mtarr.getDimensions(), jltype, matlabPtr);

        matlab::data::buffer_ptr_t<T> mtarrbuf = mtarr.release();
        memcpy(jl_array_ptr(jlarr), mtarrbuf.get(), nel*sizeof(T)); 

        return (jl_value_t*) jlarr;


    }
};

inline jl_value_t* convert_string(matlab::data::MATLABString &&ms){
    if (ms.has_value()){         
        matlab::data::String sv = *ms;
        
        std::string s8 = matlab::engine::convertUTF16StringToUTF8String(sv);
        return jl_cstr_to_string(s8.c_str());
    } 
    else {
        return jl_cstr_to_string(""); // Empty string
    }
}

inline jl_value_t* convert_string(matlab::data::CharArray &&mcarr){
    auto s = mcarr.toUTF16();
    std::string s8 = matlab::engine::convertUTF16StringToUTF8String(s);
    return jl_cstr_to_string(s8.c_str());
}


class StringConverter : public Converter {
    
public:
    jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr) {
        if(marr.getType() != matlab::data::ArrayType::MATLAB_STRING){
            if (marr.getType() == matlab::data::ArrayType::CHAR){            
                return convert_string((matlab::data::CharArray&&) std::move(marr));
            } else {
                throw_argument_invalid(std::move(marr), jl_string_type, matlabPtr);
            }
        } else if (marr.getNumberOfElements() != 1) {
            throw_not_scalar_value_error(marr.getDimensions(), jl_string_type, matlabPtr);
        } else {
            matlab::data::StringArray &&msarr = (matlab::data::StringArray&&) std::move(marr); 
            return convert_string((matlab::data::MATLABString&&) std::move(msarr[0]));
        }
    }
};

class ArrayStringConverter : public Converter {
    jl_datatype_t* jltype;
    StringConverter conv;
    
    
public:
    ArrayStringConverter(jl_datatype_t* jltype):
        jltype(jltype)
    {
    }

    jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr) {
        if(marr.getType() == matlab::data::ArrayType::MATLAB_STRING){
            matlab::data::StringArray &&msarr = (matlab::data::StringArray&&) std::move(marr);
            size_t nel = msarr.getNumberOfElements();     
    
            jl_array_t* jlarr  = new_array(msarr.getDimensions(), jltype, matlabPtr);
            
            matlab::data::TypedIterator<matlab::data::MATLABString>&& it(std::move(msarr).begin()); 

            jl_function_t *setindex = jl_get_function(jl_base_module, "setindex!");

            for (size_t i = 0; i < nel; i++){
                jl_value_t* jls = convert_string((matlab::data::MATLABString&&) std::move(it[i]));
                jl_call3(setindex, (jl_value_t*) jlarr, jls, jl_box_int64(i+1));
            }
            return (jl_value_t*) jlarr;
        } else if(marr.getType() == matlab::data::ArrayType::CELL){
            // Cell array of strings accepted because of CharArray

            matlab::data::CellArray &&mcarr = (matlab::data::CellArray&&) std::move(marr);
            size_t nel = mcarr.getNumberOfElements();     
    
            jl_array_t* jlarr  = new_array(mcarr.getDimensions(), jltype, matlabPtr);
            
            matlab::data::TypedIterator<matlab::data::Array>&& it(std::move(mcarr).begin()); 

            jl_function_t *setindex = jl_get_function(jl_base_module, "setindex!");

            for (size_t i = 0; i < nel; i++){
                jl_value_t* jls = conv.convert(std::move(it[i]), matlabPtr);
                jl_call3(setindex, (jl_value_t*) jlarr, jls, jl_box_int64(i+1));
            }
            return (jl_value_t*) jlarr;
       
        }
        throw_argument_invalid(std::move(marr), jltype, matlabPtr);
    }
};

class StructConverterBase {
    
    jl_datatype_t* jltype;
    std::vector<std::string> fieldnames;
    std::vector<std::unique_ptr<Converter>> converters;

public:
    StructConverterBase(jl_datatype_t* jltype) :
        jltype(jltype)
    {
        fieldnames = std::vector<std::string>(0);
        converters = std::vector<std::unique_ptr<Converter>>(0);

        jl_function_t* fieldnames_f = jl_get_function(jl_base_module, "fieldnames");

        jl_value_t* fieldnames_syms = jl_call1(fieldnames_f, (jl_value_t*) jltype);

        size_t nfields = jl_datatype_nfields(jltype);

        for (size_t ifield = 0; ifield < nfields; ifield++){
            std::string fieldname = jl_symbol_name((jl_sym_t*) jl_get_nth_field(fieldnames_syms, ifield));

            fieldnames.push_back(fieldname);
            
            converters.push_back(converter((jl_datatype_t*) jl_field_type(jltype, ifield)));
        }
    }

    jl_value_t* convert(matlab::data::Struct &&ms, matlab::engine::MATLABEngine* matlabPtr) {
        size_t nfields = fieldnames.size();
        jl_value_t* fieldvalues[nfields];
        for (size_t ifield = 0; ifield < nfields; ifield++){
            fieldvalues[ifield] = converters[ifield]->convert(std::move(ms[fieldnames[ifield]]), matlabPtr);
        }
        return jl_new_structv(jltype, fieldvalues, nfields);

    }

    void validate(matlab::data::StructArray msarr, matlab::engine::MATLABEngine* matlabPtr){
       for (std::string fieldnamejl : fieldnames){        
            bool found = false;   
            for (auto fieldnamemat: msarr.getFieldNames()){
                if (fieldnamejl.compare(fieldnamemat) == 0){
                    found = true;
                    break;
                }
            }
            if(!found){
                throw_missing_fields_error(std::move(msarr), matlabPtr);
            }
        }

        for (auto fieldnamemat: msarr.getFieldNames()){ 
            bool found = false;   
            for (std::string fieldnamejl : fieldnames){       
                if (fieldnamejl.compare(fieldnamemat) == 0){
                    found = true;
                    break;
                }
            }
            if(!found){
                throw_additional_fields_error(std::move(msarr), matlabPtr);
            }
        }
    }

    void throw_missing_fields_error(matlab::data::StructArray &&marr, matlab::engine::MATLABEngine* matlabPtr){
        jl_value_t* jlts = jl_call1(jl_get_function(jl_base_module, "string"), (jl_value_t*) jltype);
        std::stringstream ss;
        ss << "\nMATFrost.jl conversion error:\n\nConverting to: " << jl_string_ptr(jlts) << "\n\nInput struct value is missing fields from specified Julia type.\n\nMissing fields:\n";

        for (std::string fieldnamejl : fieldnames){   
            bool found = false;
            
            for (auto fieldnamemat: marr.getFieldNames()){
                if (fieldnamejl.compare(fieldnamemat) == 0){
                    found = true;
                    break;
                }
            }
            if (!found){
                ss << "    " << fieldnamejl << "\n";
            }
        }
        ss << "\nExpected fields:\n";
        
        for (std::string fieldnamejl : fieldnames){   
            ss << "    " << fieldnamejl << "\n";
        }
        ss << "\nActual fields:\n";
        
        for (matlab::data::MATLABFieldIdentifier fieldnamemat: marr.getFieldNames()){
            ss << "    " << std::string(fieldnamemat) << "\n";
        }

        throw matlab::engine::MATLABException(
        "matfrostjulia:conversion:missingFields",
            matlab::engine::convertUTF8StringToUTF16String(ss.str()));
    }

    void throw_additional_fields_error(matlab::data::StructArray &&marr, matlab::engine::MATLABEngine* matlabPtr){
        jl_value_t* jlts = jl_call1(jl_get_function(jl_base_module, "string"), (jl_value_t*) jltype);
        std::stringstream ss;
        ss << "\nMATFrost.jl conversion error:\n\nConverting to: " << jl_string_ptr(jlts) << "\n\nInput struct value has more fields than specified Julia type.\n\nAdditional fields:\n";

        for (auto fieldnamemat: marr.getFieldNames()){
            bool found = false;
            for (std::string fieldnamejl : fieldnames){   
                if (fieldnamejl.compare(fieldnamemat) == 0){
                    found = true;
                    break;
                }
            }
            if (!found){
                ss << "    " << std::string(fieldnamemat) << "\n";
            }
        }
        ss << "\nExpected fields:\n";
        
        for (std::string fieldnamejl : fieldnames){   
            ss << "    " << fieldnamejl << "\n";
        }
        ss << "\nActual fields:\n";
        
        for (matlab::data::MATLABFieldIdentifier fieldnamemat: marr.getFieldNames()){
            ss << "    " << std::string(fieldnamemat) << "\n";
        }

        throw matlab::engine::MATLABException(
        "matfrostjulia:conversion:additionalFields",
            matlab::engine::convertUTF8StringToUTF16String(ss.str()));
    }
};

class StructConverter : public Converter {
    jl_datatype_t* jltype;
    StructConverterBase base;
public:

    StructConverter(jl_datatype_t* jltype) :
        jltype(jltype),
        base(jltype)
    {
    }

    jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr) {
        if (marr.getType() != matlab::data::ArrayType::STRUCT){
            throw_argument_invalid(std::move(marr), jltype, matlabPtr);
        } else if (marr.getNumberOfElements() != 1){
            throw_not_scalar_value_error(marr.getDimensions(), jltype, matlabPtr);
        } else {
            matlab::data::StructArray &&msarr = (matlab::data::StructArray&&) std::move(marr);
            base.validate(msarr, matlabPtr);
            return base.convert(std::move(msarr[0]), matlabPtr);
        }
    }
};

class ArrayStructConverter : public Converter {
    jl_datatype_t* jltype;
    StructConverterBase base;

public:

    ArrayStructConverter(jl_datatype_t* jltype) :
         base((jl_datatype_t*) jl_tparam0(jltype)),
         jltype(jltype)
    {
    }

    jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr) {
        if (marr.getType() == matlab::data::ArrayType::STRUCT){
            matlab::data::StructArray &&msarr = (matlab::data::StructArray&&) std::move(marr);
            base.validate(msarr, matlabPtr);
            jl_array_t* jlarr  = new_array(msarr.getDimensions(), jltype, matlabPtr);
            
            jl_function_t* setindex_f = jl_get_function(jl_base_module, "setindex!");

            matlab::data::TypedIterator<matlab::data::Struct>&& it(std::move(msarr).begin()); 

            size_t nel = msarr.getNumberOfElements(); 

            for (size_t i = 0; i < nel; i++){
                matlab::data::Struct&& matstruct = std::move(it[i]);

                jl_value_t* jlval = base.convert(std::move(it[i]), matlabPtr);;

                jl_call3(setindex_f, (jl_value_t*) jlarr, jlval, jl_box_int64(i+1));
            }
            return (jl_value_t*) jlarr;

        } else if (marr.getType() == matlab::data::ArrayType::CELL){


            matlab::data::CellArray &&mcarr = (matlab::data::CellArray&&) std::move(marr);
            
            jl_array_t* jlarr  = new_array(mcarr.getDimensions(), jltype, matlabPtr);

            jl_function_t* setindex_f = jl_get_function(jl_base_module, "setindex!");

            matlab::data::TypedIterator<matlab::data::Array>&& it(std::move(mcarr).begin()); 

            size_t nel = mcarr.getNumberOfElements(); 

            for (size_t i = 0; i < nel; i++){

                matlab::data::Array&& mcv = std::move(it[i]);
                if (mcv.getType() == matlab::data::ArrayType::STRUCT && mcv.getNumberOfElements() == 1){
                    matlab::data::StructArray &&msarr = (matlab::data::StructArray&&) std::move(mcv);                    
                    base.validate(msarr, matlabPtr);                    
                    jl_value_t* jlval =  base.convert(std::move(msarr[0]), matlabPtr);
                    jl_call3(setindex_f, (jl_value_t*) jlarr, jlval, jl_box_int64(i+1));
                } else {
                    throw_argument_invalid(std::move(mcv), jltype, matlabPtr);
                }

            }
            return (jl_value_t*) jlarr;
        }
        throw_argument_invalid(std::move(marr), jltype, matlabPtr);

    }
};

class TupleConverter : public Converter {
    
    jl_datatype_t* jltype;
    std::vector<std::unique_ptr<Converter>> converters;

public:
    TupleConverter(jl_datatype_t* jltype) :
        jltype(jltype)
    {
        converters = std::vector<std::unique_ptr<Converter>>(0);

        size_t nfields = jl_datatype_nfields(jltype);

        for (size_t ifield = 0; ifield < nfields; ifield++){
            converters.push_back(converter((jl_datatype_t*) jl_field_type(jltype, ifield)));
        }
    }

    jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr) {
        if (marr.getType() == matlab::data::ArrayType::CELL && marr.getNumberOfElements() == converters.size()){
            matlab::data::CellArray &&mcarr = (matlab::data::CellArray&&) marr;
            size_t nel = converters.size();
            jl_value_t* fieldvalues[nel];
            for (size_t ifield = 0; ifield < nel; ifield++){
                fieldvalues[ifield] = converters[ifield]->convert(std::move(mcarr[ifield]), matlabPtr);
            }
            
            return jl_call(jl_get_function(jl_base_module, "tuple"), fieldvalues, nel);
        }
        throw_argument_invalid(std::move(marr), jltype, matlabPtr);
    }
};

class ArrayAnyConverter : public Converter {
    
    jl_datatype_t* jltype;
    std::unique_ptr<Converter> anyconverter;

public:
    ArrayAnyConverter(jl_datatype_t* jltype) :
        jltype(jltype)
    {
        jl_datatype_t* jlarrayof = (jl_datatype_t*) jl_tparam0(jltype);
        anyconverter = converter(jlarrayof);
    }

    jl_value_t* convert(matlab::data::Array &&marr, matlab::engine::MATLABEngine* matlabPtr) {
        if (marr.getType() == matlab::data::ArrayType::CELL){
            matlab::data::CellArray &&mcarr = (matlab::data::CellArray&&) marr;
            
            jl_array_t* jlarr  = new_array(mcarr.getDimensions(), jltype, matlabPtr);

            jl_function_t* setindex_f = jl_get_function(jl_base_module, "setindex!");

            size_t nel = mcarr.getNumberOfElements(); 

            matlab::data::TypedIterator<matlab::data::Array>&& it(std::move(mcarr).begin()); 

            for (size_t i = 0; i < nel; i++){
                matlab::data::Array&& anyval = std::move(it[i]);

                jl_value_t* jlval = anyconverter->convert(std::move(anyval), matlabPtr);;

                jl_call3(setindex_f, (jl_value_t*) jlarr, jlval, jl_box_int64(i+1));
            }

            return (jl_value_t*) jlarr;
        }
        throw_argument_invalid(std::move(marr), jltype, matlabPtr);
    }
};



std::unique_ptr<Converter> converter(jl_datatype_t* jltype){
    jl_value_t* jlcomplex = (jl_value_t*) jl_get_function(jl_base_module, "Complex");
    if(jl_is_primitivetype(jltype)){
        if (jltype == jl_float32_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<float>(jltype, jl_box_float32, matlab::data::ArrayType::SINGLE));
        } else if (jltype == jl_float64_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<double>(jltype, jl_box_float64, matlab::data::ArrayType::DOUBLE));    
        } else if (jltype == jl_bool_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<int8_t>(jltype, jl_box_bool, matlab::data::ArrayType::LOGICAL));
        } else if (jltype == jl_uint8_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<uint8_t>(jltype, jl_box_uint8, matlab::data::ArrayType::UINT8));
        } else if (jltype == jl_int8_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<int8_t>(jltype, jl_box_int8, matlab::data::ArrayType::INT8));
        } else if (jltype == jl_uint16_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<uint16_t>(jltype, jl_box_uint16, matlab::data::ArrayType::UINT16));
        } else if (jltype == jl_int16_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<int16_t>(jltype, jl_box_int16, matlab::data::ArrayType::INT16));
        } else if (jltype == jl_uint32_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<uint32_t>(jltype, jl_box_uint32, matlab::data::ArrayType::UINT32));
        } else if (jltype == jl_int32_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<int32_t>(jltype, jl_box_int32, matlab::data::ArrayType::INT32));
        } else if (jltype == jl_uint64_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<uint64_t>(jltype, jl_box_uint64, matlab::data::ArrayType::UINT64));
        } else if (jltype == jl_int64_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<int64_t>(jltype, jl_box_int64, matlab::data::ArrayType::INT64));
        }
    } else if(jl_subtype((jl_value_t*) jltype, jlcomplex)){
        jl_datatype_t* jlcomplexof = (jl_datatype_t*) jl_tparam0(jltype);
        if (jlcomplexof == jl_float32_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<float>(jltype, jl_box_float32, matlab::data::ArrayType::COMPLEX_SINGLE));
        } else if (jlcomplexof == jl_float64_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<double>(jltype, jl_box_float64, matlab::data::ArrayType::COMPLEX_DOUBLE));    
        } else if (jlcomplexof == jl_uint8_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<uint8_t>(jltype, jl_box_uint8, matlab::data::ArrayType::COMPLEX_UINT8));
        } else if (jlcomplexof == jl_int8_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<int8_t>(jltype, jl_box_int8, matlab::data::ArrayType::COMPLEX_INT8));
        } else if (jlcomplexof == jl_uint16_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<uint16_t>(jltype, jl_box_uint16, matlab::data::ArrayType::COMPLEX_UINT16));
        } else if (jlcomplexof == jl_int16_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<int16_t>(jltype, jl_box_int16, matlab::data::ArrayType::COMPLEX_INT16));
        } else if (jlcomplexof == jl_uint32_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<uint32_t>(jltype, jl_box_uint32, matlab::data::ArrayType::COMPLEX_UINT32));
        } else if (jlcomplexof == jl_int32_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<int32_t>(jltype, jl_box_int32, matlab::data::ArrayType::COMPLEX_INT32));
        } else if (jlcomplexof == jl_uint64_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<uint64_t>(jltype, jl_box_uint64, matlab::data::ArrayType::COMPLEX_UINT64));
        } else if (jlcomplexof == jl_int64_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<int64_t>(jltype, jl_box_int64, matlab::data::ArrayType::COMPLEX_INT64));
        }
    } else if(jltype == jl_string_type){
        return std::unique_ptr<Converter>(new StringConverter());
    } else if(jl_is_tuple_type(jltype)){
        return std::unique_ptr<Converter>(new TupleConverter(jltype));  
    } else if(jl_is_array_type(jltype)){
        jl_datatype_t* jlarrayof = (jl_datatype_t*) jl_tparam0(jltype);
        if(jl_is_primitivetype(jlarrayof)){
            if (jlarrayof == jl_float32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<float>(jltype, matlab::data::ArrayType::SINGLE));
            } else if (jlarrayof == jl_float64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<double>(jltype, matlab::data::ArrayType::DOUBLE));    
            } else if (jlarrayof == jl_bool_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<int8_t>(jltype, matlab::data::ArrayType::LOGICAL));
            } else if (jlarrayof == jl_uint8_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<uint8_t>(jltype, matlab::data::ArrayType::UINT8));
            } else if (jlarrayof == jl_int8_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<int8_t>(jltype,  matlab::data::ArrayType::INT8));
            } else if (jlarrayof == jl_uint16_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<uint16_t>(jltype,  matlab::data::ArrayType::UINT16));
            } else if (jlarrayof == jl_int16_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<int16_t>(jltype, matlab::data::ArrayType::INT16));
            } else if (jlarrayof == jl_uint32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<uint32_t>(jltype, matlab::data::ArrayType::UINT32));
            } else if (jlarrayof == jl_int32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<int32_t>(jltype, matlab::data::ArrayType::INT32));
            } else if (jlarrayof == jl_uint64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<uint64_t>(jltype, matlab::data::ArrayType::UINT64));
            } else if (jlarrayof == jl_int64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<int64_t>(jltype, matlab::data::ArrayType::INT64));
            }
        } else if(jl_subtype((jl_value_t*) jlarrayof, jlcomplex)){
            jl_datatype_t* jlcomplexof = (jl_datatype_t*) jl_tparam0(jlarrayof);
            if (jlcomplexof == jl_float32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<float>>(jltype, matlab::data::ArrayType::COMPLEX_SINGLE));
            } else if (jlcomplexof == jl_float64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<double>>(jltype, matlab::data::ArrayType::COMPLEX_DOUBLE));    
            } else if (jlcomplexof == jl_uint8_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<uint8_t>>(jltype, matlab::data::ArrayType::COMPLEX_UINT8));
            } else if (jlcomplexof == jl_int8_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<int8_t>>(jltype, matlab::data::ArrayType::COMPLEX_INT8));
            } else if (jlcomplexof == jl_uint16_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<uint16_t>>(jltype, matlab::data::ArrayType::COMPLEX_UINT16));
            } else if (jlcomplexof == jl_int16_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<int16_t>>(jltype, matlab::data::ArrayType::COMPLEX_INT16));
            } else if (jlcomplexof == jl_uint32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<uint32_t>>(jltype, matlab::data::ArrayType::COMPLEX_UINT32));
            } else if (jlcomplexof == jl_int32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<int32_t>>(jltype, matlab::data::ArrayType::COMPLEX_INT32));
            } else if (jlcomplexof == jl_uint64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<uint64_t>>(jltype, matlab::data::ArrayType::COMPLEX_UINT64));
            } else if (jlcomplexof == jl_int64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<int64_t>>(jltype, matlab::data::ArrayType::COMPLEX_INT64));
            }
        } 
        else if(jlarrayof == jl_string_type){
            return std::unique_ptr<Converter>(new ArrayStringConverter(jltype));
        } 
        else if (jl_is_array_type(jlarrayof) || jl_is_tuple_type(jlarrayof)) {
            return std::unique_ptr<Converter>(new ArrayAnyConverter(jltype));
        }
        else if (jl_is_structtype(jlarrayof) || jl_is_namedtuple_type(jlarrayof)){
            return std::unique_ptr<Converter>(new ArrayStructConverter(jltype));
        }
        
    } else if (jl_is_structtype(jltype) || jl_is_namedtuple_type(jltype)){
        return std::unique_ptr<Converter>(new StructConverter(jltype));
    }
    throw std::invalid_argument("Wrong input MATFRost test - Cannot find matching type.");
}


}
}
