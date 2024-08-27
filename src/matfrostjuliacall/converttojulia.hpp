
#include <julia.h>
#include "mex.hpp"
#include "mexAdapter.hpp"

#include <tuple>
// stdc++ lib
#include <string>
#include <complex>
#include "matfrost.h"

namespace MATFrost::ConvertToJulia {

    struct MATFrostArrayMemory {
        MATFrostArray matfrostarray{0};
        std::vector<size_t> dims;
        std::vector<std::unique_ptr<MATFrostArrayMemory>> subarrays;

        std::vector<std::string> fieldnames;
        std::vector<const char*> fieldnames_cstr;

        std::vector<std::string> strings;
        std::vector<const char*> strings_cstr;
    };

    std::unique_ptr<MATFrostArrayMemory> convert(matlab::data::Array marr);

    template<typename T>
    std::unique_ptr<MATFrostArrayMemory> convert_primitive(const matlab::data::TypedArray<T> mtarr) {

        std::unique_ptr<MATFrostArrayMemory> matfarr(new MATFrostArrayMemory());

        matfarr->dims = mtarr.getDimensions();
        matfarr->matfrostarray.dims  = matfarr->dims.data();
        matfarr->matfrostarray.ndims = matfarr->dims.size();
        matfarr->matfrostarray.type  = (int32_t) mtarr.getType();

        matlab::data::TypedIterator<const T> it(mtarr.begin());
        const T* vs = it.operator->();

        matfarr->matfrostarray.data = vs;
        return matfarr;
    }


    std::unique_ptr<MATFrostArrayMemory> convert_string(const matlab::data::StringArray strarr) {
        std::unique_ptr<MATFrostArrayMemory> matfarr(new MATFrostArrayMemory());

        matfarr->dims = strarr.getDimensions();
        matfarr->matfrostarray.dims  = matfarr->dims.data();
        matfarr->matfrostarray.ndims = matfarr->dims.size();
        matfarr->matfrostarray.type  = (int32_t) strarr.getType();

        matfarr->strings.reserve(strarr.getNumberOfElements());
        matfarr->strings_cstr.reserve(strarr.getNumberOfElements());

        for (const matlab::data::MATLABString matstr: strarr) {
            matfarr->strings.push_back(matlab::engine::convertUTF16StringToUTF8String(matstr));
        }
        for (size_t i = 0; i < strarr.getNumberOfElements(); i++) {
            matfarr->strings_cstr.push_back(matfarr->strings[i].c_str());
        }
        matfarr->matfrostarray.data = matfarr->strings_cstr.data();

        return matfarr;

    }

    std::unique_ptr<MATFrostArrayMemory> convert_cell(const matlab::data::CellArray mcarr) {
        std::unique_ptr<MATFrostArrayMemory> matfarr(new MATFrostArrayMemory());

        matfarr->dims = mcarr.getDimensions();
        matfarr->matfrostarray.dims  = matfarr->dims.data();
        matfarr->matfrostarray.ndims = matfarr->dims.size();
        matfarr->matfrostarray.type  = (int32_t) mcarr.getType();

        size_t nel = mcarr.getNumberOfElements();

        matfarr->subarrays.reserve(nel);
        for (const matlab::data::Array arr: mcarr){
            matfarr->subarrays.push_back(convert(arr));
        }

        matfarr->matfrostarray.data = matfarr->subarrays.data();

        return matfarr;
    }

    std::unique_ptr<MATFrostArrayMemory> convert_struct(const matlab::data::StructArray msarr) {
        std::unique_ptr<MATFrostArrayMemory> matfarr(new MATFrostArrayMemory());

        matfarr->dims = msarr.getDimensions();
        matfarr->matfrostarray.dims  = matfarr->dims.data();
        matfarr->matfrostarray.ndims = matfarr->dims.size();
        matfarr->matfrostarray.type  = (int32_t) msarr.getType();

        size_t nfields = msarr.getNumberOfFields();
        matfarr->fieldnames.reserve(nfields);
        matfarr->fieldnames_cstr.reserve(nfields);
        {
            size_t i = 0;
            for (auto fieldname : msarr.getFieldNames()) {
                matfarr->fieldnames.push_back(fieldname);
                matfarr->fieldnames_cstr.push_back(matfarr->fieldnames[i].c_str());
                i++;
            }
        }

        size_t nel = msarr.getNumberOfElements();
        size_t narrs = nel*nfields;

        matfarr->subarrays.reserve(narrs);

        for (const matlab::data::Struct mats: msarr){
            for (const matlab::data::Array arr: mats) {
                matfarr->subarrays.push_back(convert(arr));
            }
        }

        matfarr->matfrostarray.data = matfarr->subarrays.data();
        matfarr->matfrostarray.fieldnames = matfarr->fieldnames_cstr.data();
        matfarr->matfrostarray.nfields = nfields;

        return matfarr;
    }



    std::unique_ptr<MATFrostArrayMemory> convert(const matlab::data::Array marr) {
        switch (marr.getType()) {
            case matlab::data::ArrayType::CELL:
                return convert_cell(marr);
            case matlab::data::ArrayType::STRUCT:
                return convert_struct(marr);

            case matlab::data::ArrayType::MATLAB_STRING:
                return convert_string(marr);
            case matlab::data::ArrayType::LOGICAL:
                return convert_primitive<bool>(marr);

            case matlab::data::ArrayType::SINGLE:
                return convert_primitive<float>(marr);
            case matlab::data::ArrayType::DOUBLE:
                return convert_primitive<double>(marr);

            case matlab::data::ArrayType::INT8:
                return convert_primitive<int8_t>(marr);
            case matlab::data::ArrayType::UINT8:
                return convert_primitive<uint8_t>(marr);
            case matlab::data::ArrayType::INT16:
                return convert_primitive<int16_t>(marr);
            case matlab::data::ArrayType::UINT16:
                return convert_primitive<uint16_t>(marr);
            case matlab::data::ArrayType::INT32:
                return convert_primitive<int32_t>(marr);
            case matlab::data::ArrayType::UINT32:
                return convert_primitive<uint32_t>(marr);
            case matlab::data::ArrayType::INT64:
                return convert_primitive<int64_t>(marr);
            case matlab::data::ArrayType::UINT64:
                return convert_primitive<uint64_t>(marr);

            case matlab::data::ArrayType::COMPLEX_SINGLE:
                return convert_primitive<std::complex<float>>(marr);
            case matlab::data::ArrayType::COMPLEX_DOUBLE:
                return convert_primitive<std::complex<double>>(marr);

            case matlab::data::ArrayType::COMPLEX_UINT8:
                return convert_primitive<std::complex<uint8_t>>(marr);
            case matlab::data::ArrayType::COMPLEX_INT8:
                return convert_primitive<std::complex<int8_t>>(marr);
            case matlab::data::ArrayType::COMPLEX_UINT16:
                return convert_primitive<std::complex<uint16_t>>(marr);
            case matlab::data::ArrayType::COMPLEX_INT16:
                return convert_primitive<std::complex<int16_t>>(marr);
            case matlab::data::ArrayType::COMPLEX_UINT32:
                return convert_primitive<std::complex<uint32_t>>(marr);
            case matlab::data::ArrayType::COMPLEX_INT32:
                return convert_primitive<std::complex<int32_t>>(marr);
            case matlab::data::ArrayType::COMPLEX_UINT64:
                return convert_primitive<std::complex<uint64_t>>(marr);
            case matlab::data::ArrayType::COMPLEX_INT64:
                return convert_primitive<std::complex<int64_t>>(marr);

            // Unspported
            default:
                std::u16string mattype;
                switch (marr.getType()) {
                    case matlab::data::ArrayType::CHAR:
                        mattype = u"char"; break;
                    case matlab::data::ArrayType::OBJECT:
                        mattype = u"object"; break;
                    case matlab::data::ArrayType::VALUE_OBJECT:
                        mattype = u"value object"; break;
                    case matlab::data::ArrayType::HANDLE_OBJECT_REF:
                        mattype = u"handle object ref"; break;
                    case matlab::data::ArrayType::ENUM:
                        mattype = u"enum"; break;
                    case matlab::data::ArrayType::SPARSE_LOGICAL:
                        mattype = u"sparse logical"; break;
                    case matlab::data::ArrayType::SPARSE_DOUBLE:
                        mattype = u"sparse double"; break;
                    case matlab::data::ArrayType::SPARSE_COMPLEX_DOUBLE:
                        mattype = u"sparse complex double"; break;
                    default:
                        mattype = u"unknown"; break;

                }
                throw matlab::engine::MATLABException("matfrostjulia:conversion:typeNotSupported", u"MATFrost does not support conversions of MATLAB type: " + mattype);

        }
    }
}
