
#include <julia.h>
#include "mex.hpp"
#include "mexAdapter.hpp"

#include <tuple>
// stdc++ lib
#include <string>
#include <complex>


namespace MATFrost {
namespace ConvertToMATLAB {

/**
 * Converter is an abstract interface class. Each object of Converter is linked to a Julia type 
 * and is able of convert Julia values of that type to MATLAB values. 
 *  
 */ 
class Converter {
public:
    virtual matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr);
};

/**
 * Construct a converter of given Julia type
 *  
 * @param jltype Construct converter graph of jltype.
 */ 
std::unique_ptr<Converter> converter(jl_datatype_t* jltype);


/**
 * Converts a Julia value to a MATLAB value. This is the entrypoint for conversions. 
 *  
 * @param jlval Julia value to convert
 * @param matlabPtr MATLABEngine.
 */ 
matlab::data::Array convert(jl_value_t* jlval, std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr){

    std::unique_ptr<Converter> conv = converter((jl_datatype_t*) jl_typeof(jlval));
    return conv->convert(jlval, matlabPtr.get());
}


template<typename T>
class PrimitiveConverter : public Converter {
    T (*jlunbox)(jl_value_t*);
    
public:
    PrimitiveConverter(T (*jlunbox)(jl_value_t*)):
        jlunbox(jlunbox)
    {
    }

    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {
        
        matlab::data::ArrayFactory factory;
        return factory.createScalar(jlunbox(jlval));
    }
};

template<typename T>
class ComplexPrimitiveConverter : public Converter {
    T (*jlunbox)(jl_value_t*);
    
public:
    ComplexPrimitiveConverter(T (*jlunbox)(jl_value_t*)):
        jlunbox(jlunbox)
    {
    }

    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {
        
        matlab::data::ArrayFactory factory;

        return factory.createScalar(std::complex<T>(
            jlunbox(jl_get_nth_field(jlval, 0)), 
            jlunbox(jl_get_nth_field(jlval, 1)) 
        ));
    }
};

template<typename T>
class ArrayPrimitiveConverter : public Converter {
    
public:

    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {
        matlab::data::ArrayDimensions dims(jl_array_ndims(jlval));
        size_t nel = jl_array_len(jlval);
        for (size_t i = 0; i < jl_array_ndims(jlval); i++){
            dims[i] = jl_array_dim(jlval, i);
        }

        matlab::data::ArrayFactory factory;

        matlab::data::buffer_ptr_t<T> buf = factory.createBuffer<T>(nel);

        memcpy(buf.get(), jl_array_ptr((jl_array_t*) jlval), sizeof(T)*nel);
        
        matlab::data::TypedArray<T> marr = factory.createArrayFromBuffer<T>(dims, std::move(buf));
        
        return marr;
    }
};

inline matlab::data::String convert_string(jl_value_t* jlval){
    std::string s8(jl_string_ptr(jlval));
    return matlab::engine::convertUTF8StringToUTF16String(s8);
}


class StringConverter : public Converter {
    
public:
    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {

        matlab::data::ArrayDimensions dims(2);
        dims[0] = 1;
        dims[1] = 1;
        matlab::data::ArrayFactory factory;
        matlab::data::StringArray sa = factory.createArray<matlab::data::MATLABString>(dims);
        for (auto e : sa) {
            e = convert_string(jlval);
        }
        return sa;

    }
};

class ArrayStringConverter : public Converter {
    
public:
    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {
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
            e = convert_string(jlvale);
            i++;
        }

        return sa;
        
    }
};


class StructConverterBase {
public:    

    jl_datatype_t* jltype;
    std::vector<std::string> fieldnames;
    std::vector<std::unique_ptr<Converter>> converters;

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

    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {
        size_t nfields = base.converters.size(); 

        matlab::data::ArrayFactory factory;

        matlab::data::StructArray matstruct = factory.createStructArray({1, 1}, base.fieldnames);
                    
        for (size_t fi = 0; fi < nfields; fi++){
            matstruct[0][base.fieldnames[fi]] = base.converters[fi]->convert(jl_get_nth_field(jlval, fi), matlabPtr);
        }
        return matstruct;
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

    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {

        matlab::data::ArrayDimensions dims(jl_array_ndims(jlval));
        size_t nel = jl_array_len(jlval);
        for (size_t i = 0; i < jl_array_ndims(jlval); i++){
            dims[i] = jl_array_dim(jlval, i);
        }

        size_t nfields = base.converters.size();

        matlab::data::ArrayFactory factory;
                            
        matlab::data::StructArray matstruct = factory.createStructArray(dims, base.fieldnames);
            
        jl_function_t *getindex = jl_get_function(jl_base_module, "getindex");
        size_t eli = 1;

        for (auto e : matstruct) {
            jl_value_t* jlvale = jl_call2(getindex, jlval, jl_box_int64(eli));
            for (size_t fi = 0; fi < nfields; fi++){
                e[base.fieldnames[fi]] = base.converters[fi]->convert(jl_get_nth_field(jlvale, fi), matlabPtr);
            }
            eli++;
        }
        return matstruct;

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

    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {
        size_t nfields = converters.size(); 

        matlab::data::ArrayFactory factory;

        matlab::data::CellArray matstruct = factory.createCellArray({nfields, 1});

        for (size_t fi = 0; fi < nfields; fi++){
            matstruct[fi] = converters[fi]->convert(jl_get_nth_field(jlval, fi), matlabPtr);
        }
        
        return matstruct;

    }
};


/**
 * ArrayConverter is an unspecialized array converter. For each element in the array a new convert routine is called. 
 */
class ArrayConverter : public Converter {
    
    jl_datatype_t* jltype;
    std::unique_ptr<Converter> conv;

public:
    ArrayConverter(jl_datatype_t* jltype) :
        jltype(jltype)
    {
        jl_datatype_t* jlarrayof = (jl_datatype_t*) jl_tparam0(jltype);
        conv = converter(jlarrayof);
    }
    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {

        matlab::data::ArrayDimensions dims(jl_array_ndims(jlval));
        size_t nel = jl_array_len(jlval);
        for (size_t i = 0; i < jl_array_ndims(jlval); i++){
            dims[i] = jl_array_dim(jlval, i);
        }

        matlab::data::ArrayFactory factory;
                
        matlab::data::CellArray carr = factory.createCellArray(dims);
            
        jl_function_t *getindex = jl_get_function(jl_base_module, "getindex");
        size_t eli = 1;
        for (auto e : carr) {
            jl_value_t* jlvale = jl_call2(getindex, jlval, jl_box_int64(eli));
            e = conv->convert(jlvale, matlabPtr);
            eli++;
        }
        return carr;

    }
};

/**
 * AbstractConverter will construct a new converter for every provided Julia value.
 */
class AbstractConverter : public Converter {
public:

    matlab::data::Array convert(jl_value_t* jlval, matlab::engine::MATLABEngine* matlabPtr) {
        std::unique_ptr<Converter> conv = converter((jl_datatype_t*) jl_typeof(jlval));
        return conv->convert(jlval, matlabPtr);

    }
};


bool unbox_bool(jl_value_t* jlval){
    return (bool) jl_unbox_bool(jlval);
}

std::unique_ptr<Converter> converter(jl_datatype_t* jltype){
    jl_value_t* jlcomplex = (jl_value_t*) jl_get_function(jl_base_module, "Complex");
    if (jl_is_abstracttype(jltype)){
        return std::unique_ptr<Converter>(new AbstractConverter());
    } else if(jl_is_primitivetype(jltype)){
        if (jltype == jl_float32_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<float>(jl_unbox_float32));
        } else if (jltype == jl_float64_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<double>(jl_unbox_float64));    
        } else if (jltype == jl_bool_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<bool>(unbox_bool));
        } else if (jltype == jl_uint8_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<uint8_t>(jl_unbox_uint8));
        } else if (jltype == jl_int8_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<int8_t>(jl_unbox_int8));
        } else if (jltype == jl_uint16_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<uint16_t>(jl_unbox_uint16));
        } else if (jltype == jl_int16_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<int16_t>(jl_unbox_int16));
        } else if (jltype == jl_uint32_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<uint32_t>(jl_unbox_uint32));
        } else if (jltype == jl_int32_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<int32_t>(jl_unbox_int32));
        } else if (jltype == jl_uint64_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<uint64_t>(jl_unbox_uint64));
        } else if (jltype == jl_int64_type){
            return std::unique_ptr<Converter>(new PrimitiveConverter<int64_t>(jl_unbox_int64));
        }
    } else if(jl_subtype((jl_value_t*) jltype, jlcomplex)){
        jl_datatype_t* jlcomplexof = (jl_datatype_t*) jl_tparam0(jltype);
        if (jlcomplexof == jl_float32_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<float>(jl_unbox_float32));
        } else if (jlcomplexof == jl_float64_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<double>(jl_unbox_float64));    
        } else if (jlcomplexof == jl_uint8_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<uint8_t>(jl_unbox_uint8));
        } else if (jlcomplexof == jl_int8_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<int8_t>(jl_unbox_int8));
        } else if (jlcomplexof == jl_uint16_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<uint16_t>(jl_unbox_uint16));
        } else if (jlcomplexof == jl_int16_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<int16_t>(jl_unbox_int16));
        } else if (jlcomplexof == jl_uint32_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<uint32_t>(jl_unbox_uint32));
        } else if (jlcomplexof == jl_int32_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<int32_t>(jl_unbox_int32));
        } else if (jlcomplexof == jl_uint64_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<uint64_t>(jl_unbox_uint64));
        } else if (jlcomplexof == jl_int64_type){
            return std::unique_ptr<Converter>(new ComplexPrimitiveConverter<int64_t>(jl_unbox_int64));
        }
    } else if(jltype == jl_string_type){
        return std::unique_ptr<Converter>(new StringConverter());
    } else if(jl_is_tuple_type(jltype)){
        return std::unique_ptr<Converter>(new TupleConverter(jltype));  
    } else if(jl_is_array_type(jltype)){
        jl_datatype_t* jlarrayof = (jl_datatype_t*) jl_tparam0(jltype);
        if(jl_is_primitivetype(jlarrayof)){
            if (jlarrayof == jl_float32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<float>());
            } else if (jlarrayof == jl_float64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<double>());    
            } else if (jlarrayof == jl_bool_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<bool>());
            } else if (jlarrayof == jl_uint8_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<uint8_t>());
            } else if (jlarrayof == jl_int8_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<int8_t>());
            } else if (jlarrayof == jl_uint16_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<uint16_t>());
            } else if (jlarrayof == jl_int16_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<int16_t>());
            } else if (jlarrayof == jl_uint32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<uint32_t>());
            } else if (jlarrayof == jl_int32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<int32_t>());
            } else if (jlarrayof == jl_uint64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<uint64_t>());
            } else if (jlarrayof == jl_int64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<int64_t>());
            }
        } else if(jl_subtype((jl_value_t*) jlarrayof, jlcomplex)){
            jl_datatype_t* jlcomplexof = (jl_datatype_t*) jl_tparam0(jlarrayof);
            if (jlcomplexof == jl_float32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<float>>());
            } else if (jlcomplexof == jl_float64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<double>>());    
            } else if (jlcomplexof == jl_uint8_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<uint8_t>>());
            } else if (jlcomplexof == jl_int8_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<int8_t>>());
            } else if (jlcomplexof == jl_uint16_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<uint16_t>>());
            } else if (jlcomplexof == jl_int16_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<int16_t>>());
            } else if (jlcomplexof == jl_uint32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<uint32_t>>());
            } else if (jlcomplexof == jl_int32_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<int32_t>>());
            } else if (jlcomplexof == jl_uint64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<uint64_t>>());
            } else if (jlcomplexof == jl_int64_type){
                return std::unique_ptr<Converter>(new ArrayPrimitiveConverter<std::complex<int64_t>>());
            }
        } 
        else if(jlarrayof == jl_string_type){
            return std::unique_ptr<Converter>(new ArrayStringConverter());
        } 
        else if (jl_is_array_type(jlarrayof) || jl_is_tuple_type(jlarrayof)) {
            return std::unique_ptr<Converter>(new ArrayConverter(jltype));
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