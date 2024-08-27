
#include <julia.h>
#include "mex.hpp"
#include "mexAdapter.hpp"

#include <tuple>
// stdc++ lib
#include <string>
#include <complex>

#include "matfrost.h"



namespace MATFrost::ConvertToMATLAB {

matlab::data::Array convert(const MATFrostArray mfa);


template<typename T>
matlab::data::Array convert_primitive(const MATFrostArray mfa) {
    matlab::data::ArrayDimensions dims(mfa.ndims);

    size_t nel = 1;
    for (size_t i = 0; i < mfa.ndims; i++){
        dims[i] = mfa.dims[i];
        nel *= dims[i];
    }

    matlab::data::ArrayFactory factory;

    matlab::data::buffer_ptr_t<T> buf = factory.createBuffer<T>(nel);

    memcpy(buf.get(), mfa.data, sizeof(T)*nel);

    return factory.createArrayFromBuffer<T>(dims, std::move(buf));

}

matlab::data::Array convert_string(const MATFrostArray mfa){
    matlab::data::ArrayDimensions dims(mfa.ndims);

    size_t nel = 1;
    for (size_t i = 0; i < mfa.ndims; i++){
        dims[i] = mfa.dims[i];
        nel *= dims[i];
    }

    matlab::data::ArrayFactory factory;

    matlab::data::StringArray strarr = factory.createArray<matlab::data::MATLABString>(dims);

    size_t eli = 0;
    const char** strdata = (const char**) mfa.data;
    for (auto e : strarr) {
        e = matlab::engine::convertUTF8StringToUTF16String(strdata[eli]);
        eli++;
    }
    return strarr;
}


matlab::data::Array convert_struct(const MATFrostArray mfa) {
    matlab::data::ArrayDimensions dims(mfa.ndims);

    size_t nel = 1;
    for (size_t i = 0; i < mfa.ndims; i++){
        dims[i] = mfa.dims[i];
        nel *= dims[i];
    }

    std::vector<std::string> fieldnames(mfa.nfields);
    for (size_t i = 0; i < mfa.nfields; i++){
        fieldnames[i] = mfa.fieldnames[i];
    }

    matlab::data::ArrayFactory factory;

    matlab::data::StructArray matstruct = factory.createStructArray(dims, fieldnames);

    size_t eli = 0;
    const MATFrostArray** mfafields = (const MATFrostArray**) mfa.data;
    for (auto e : matstruct) {
        for (size_t fi = 0; fi < mfa.nfields; fi++){
            e[fieldnames[fi]] = convert(mfafields[eli][0]);

            eli++;
        }
    }

    return matstruct;
}

matlab::data::Array convert_cell(const MATFrostArray mfa) {
    matlab::data::ArrayDimensions dims(mfa.ndims);

    size_t nel = 1;
    for (size_t i = 0; i < mfa.ndims; i++){
        dims[i] = mfa.dims[i];
        nel *= dims[i];
    }

    matlab::data::ArrayFactory factory;

    matlab::data::CellArray carr = factory.createCellArray(dims);

    size_t eli = 0;
    const MATFrostArray** mfafields = (const MATFrostArray**) mfa.data;
    for (auto e : carr) {
        e = convert(mfafields[eli][0]);
        eli++;
    }

    return carr;
}



matlab::data::Array convert(const MATFrostArray mfa) {
    switch ((matlab::data::ArrayType) mfa.type) {
        case matlab::data::ArrayType::CELL:
             return convert_cell(mfa);
        case matlab::data::ArrayType::STRUCT:
            return convert_struct(mfa);
        case matlab::data::ArrayType::MATLAB_STRING:
             return convert_string(mfa);
        case matlab::data::ArrayType::LOGICAL:
            return convert_primitive<bool>(mfa);

        case matlab::data::ArrayType::SINGLE:
            return convert_primitive<float>(mfa);
        case matlab::data::ArrayType::DOUBLE:
            return convert_primitive<double>(mfa);

        case matlab::data::ArrayType::INT8:
            return convert_primitive<int8_t>(mfa);
        case matlab::data::ArrayType::UINT8:
            return convert_primitive<uint8_t>(mfa);
        case matlab::data::ArrayType::INT16:
            return convert_primitive<int16_t>(mfa);
        case matlab::data::ArrayType::UINT16:
            return convert_primitive<uint16_t>(mfa);
        case matlab::data::ArrayType::INT32:
            return convert_primitive<int32_t>(mfa);
        case matlab::data::ArrayType::UINT32:
            return convert_primitive<uint32_t>(mfa);
        case matlab::data::ArrayType::INT64:
            return convert_primitive<int64_t>(mfa);
        case matlab::data::ArrayType::UINT64:
            return convert_primitive<uint64_t>(mfa);

        case matlab::data::ArrayType::COMPLEX_SINGLE:
            return convert_primitive<std::complex<float>>(mfa);
        case matlab::data::ArrayType::COMPLEX_DOUBLE:
            return convert_primitive<std::complex<double>>(mfa);

        case matlab::data::ArrayType::COMPLEX_UINT8:
            return convert_primitive<std::complex<uint8_t>>(mfa);
        case matlab::data::ArrayType::COMPLEX_INT8:
            return convert_primitive<std::complex<int8_t>>(mfa);
        case matlab::data::ArrayType::COMPLEX_UINT16:
            return convert_primitive<std::complex<uint16_t>>(mfa);
        case matlab::data::ArrayType::COMPLEX_INT16:
            return convert_primitive<std::complex<int16_t>>(mfa);
        case matlab::data::ArrayType::COMPLEX_UINT32:
            return convert_primitive<std::complex<uint32_t>>(mfa);
        case matlab::data::ArrayType::COMPLEX_INT32:
            return convert_primitive<std::complex<int32_t>>(mfa);
        case matlab::data::ArrayType::COMPLEX_UINT64:
            return convert_primitive<std::complex<uint64_t>>(mfa);
        case matlab::data::ArrayType::COMPLEX_INT64:
            return convert_primitive<std::complex<int64_t>>(mfa);



    }
}




}

