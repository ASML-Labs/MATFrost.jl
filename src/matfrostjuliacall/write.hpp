#include "mex.hpp"
#include "mexAdapter.hpp"

#include <tuple>
// stdc++ lib
#include <string>
#include <complex>


namespace MATFrost::Write {


    void write(const std::shared_ptr<Socket::BufferedTCPSocket> socket, const matlab::data::Array arr);

    template<typename T>
    void write_primitive(const std::shared_ptr<Socket::BufferedTCPSocket> socket, const matlab::data::TypedArray<T> arr) {
        int32_t mattype = (int32_t) arr.getType();
        auto dims = arr.getDimensions();
        size_t ndims = dims.size();

        socket->write(reinterpret_cast<const uint8_t *>(&mattype), sizeof(int32_t));
        socket->write(reinterpret_cast<const uint8_t *>(&ndims), sizeof(size_t));
        socket->write(reinterpret_cast<const uint8_t *>(dims.data()), sizeof(size_t)*ndims);

        const matlab::data::TypedIterator<const T> it(arr.begin());
        const T* vs = it.operator->();

        socket->write(reinterpret_cast<const uint8_t *>(vs), (sizeof(T) * arr.getNumberOfElements()));


    }

    void write_string(const std::shared_ptr<Socket::BufferedTCPSocket> socket, const matlab::data::StringArray strarr) {
        int32_t mattype = static_cast<int32_t>(strarr.getType());
        auto dims = strarr.getDimensions();
        size_t ndims = dims.size();

        socket->write(reinterpret_cast<const uint8_t *>(&mattype), sizeof(int32_t));
        socket->write(reinterpret_cast<const uint8_t *>(&ndims), sizeof(size_t));
        socket->write(reinterpret_cast<const uint8_t *>(dims.data()), sizeof(size_t)*ndims);

        for (const matlab::data::MATLABString matstr: strarr) {
            std::string str(matlab::engine::convertUTF16StringToUTF8String(matstr));
            size_t strlen = str.size();
            socket->write(reinterpret_cast<const uint8_t *>(&strlen), sizeof(size_t));
            socket->write(reinterpret_cast<const uint8_t *>(str.data()), str.size());
        }

    }


    void write_cell(const std::shared_ptr<Socket::BufferedTCPSocket> socket, const matlab::data::CellArray mcarr) {
        int32_t mattype = static_cast<int32_t>(mcarr.getType());
        auto dims = mcarr.getDimensions();
        size_t ndims = dims.size();

        socket->write(reinterpret_cast<const uint8_t *>(&mattype), sizeof(int32_t));
        socket->write(reinterpret_cast<const uint8_t *>(&ndims), sizeof(size_t));
        socket->write(reinterpret_cast<const uint8_t *>(dims.data()), sizeof(size_t)*ndims);


        for (const matlab::data::Array arr: mcarr) {
            write(socket, arr);
        }
    }

    void write_struct(const std::shared_ptr<Socket::BufferedTCPSocket> socket, const matlab::data::StructArray msarr) {
        int32_t mattype = static_cast<int32_t>(msarr.getType());
        auto dims = msarr.getDimensions();
        size_t ndims = dims.size();

        socket->write(reinterpret_cast<const uint8_t *>(&mattype), sizeof(int32_t));
        socket->write(reinterpret_cast<const uint8_t *>(&ndims), sizeof(size_t));
        socket->write(reinterpret_cast<const uint8_t *>(dims.data()), sizeof(size_t)*ndims);


        size_t nfields = msarr.getNumberOfFields();
        socket->write((uint8_t*) &nfields, sizeof(size_t));
        for (auto fieldname : msarr.getFieldNames()) {
            std::string fn(fieldname);
            size_t fnlen = fn.size();
            socket->write(reinterpret_cast<const uint8_t *>(&fnlen), sizeof(size_t));
            socket->write(reinterpret_cast<const uint8_t *>(fn.data()), fn.size());
        }

        for (const matlab::data::Struct mats: msarr){
            for (const matlab::data::Array arr: mats) {
                write(socket, arr);
            }
        }


    }

    void write(const std::shared_ptr<Socket::BufferedTCPSocket> socket,const matlab::data::Array arr) {
        switch (arr.getType()) {
             case matlab::data::ArrayType::CELL:
                 return write_cell(socket, arr);
             case matlab::data::ArrayType::STRUCT:
                return write_struct(socket, arr);

             case matlab::data::ArrayType::MATLAB_STRING:
                 return write_string(socket, arr);
             case matlab::data::ArrayType::LOGICAL:
                 return write_primitive<bool>(socket, arr);

             case matlab::data::ArrayType::SINGLE:
                 return write_primitive<float>(socket, arr);
             case matlab::data::ArrayType::DOUBLE:
                 return write_primitive<double>(socket, arr);

             case matlab::data::ArrayType::INT8:
                 return write_primitive<int8_t>(socket, arr);
             case matlab::data::ArrayType::UINT8:
                 return write_primitive<uint8_t>(socket, arr);
             case matlab::data::ArrayType::INT16:
                 return write_primitive<int16_t>(socket, arr);
             case matlab::data::ArrayType::UINT16:
                 return write_primitive<uint16_t>(socket, arr);
             case matlab::data::ArrayType::INT32:
                 return write_primitive<int32_t>(socket, arr);
             case matlab::data::ArrayType::UINT32:
                 return write_primitive<uint32_t>(socket, arr);
             case matlab::data::ArrayType::INT64:
                 return write_primitive<int64_t>(socket, arr);
             case matlab::data::ArrayType::UINT64:
                 return write_primitive<uint64_t>(socket, arr);

             case matlab::data::ArrayType::COMPLEX_SINGLE:
                 return write_primitive<std::complex<float>>(socket, arr);
             case matlab::data::ArrayType::COMPLEX_DOUBLE:
                 return write_primitive<std::complex<double>>(socket, arr);

             case matlab::data::ArrayType::COMPLEX_UINT8:
                 return write_primitive<std::complex<uint8_t>>(socket, arr);
             case matlab::data::ArrayType::COMPLEX_INT8:
                 return write_primitive<std::complex<int8_t>>(socket, arr);
             case matlab::data::ArrayType::COMPLEX_UINT16:
                 return write_primitive<std::complex<uint16_t>>(socket, arr);
             case matlab::data::ArrayType::COMPLEX_INT16:
                 return write_primitive<std::complex<int16_t>>(socket, arr);
             case matlab::data::ArrayType::COMPLEX_UINT32:
                 return write_primitive<std::complex<uint32_t>>(socket, arr);
             case matlab::data::ArrayType::COMPLEX_INT32:
                 return write_primitive<std::complex<int32_t>>(socket, arr);
             case matlab::data::ArrayType::COMPLEX_UINT64:
                 return write_primitive<std::complex<uint64_t>>(socket, arr);
             case matlab::data::ArrayType::COMPLEX_INT64:
                 return write_primitive<std::complex<int64_t>>(socket, arr);

             // Unspported
             default:
                 std::u16string mattype;
                 switch (arr.getType()) {
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

    bool valid(const matlab::data::Array arr);

    bool valid_struct(const matlab::data::StructArray msarr) {

        for (const matlab::data::Struct mats: msarr){
            for (const matlab::data::Array arr: mats) {
                valid(arr);
            }
        }
        return true;
    }

    bool valid_cell(const matlab::data::CellArray mcarr) {
        for (const matlab::data::Array arr: mcarr) {
            valid(arr);
        }
        return true;
    }

    bool valid(const matlab::data::Array arr) {
        switch (arr.getType()) {
             case matlab::data::ArrayType::CELL:
                 return valid_cell(arr);
             case matlab::data::ArrayType::STRUCT:
                return valid_struct(arr);

             case matlab::data::ArrayType::MATLAB_STRING:

             case matlab::data::ArrayType::LOGICAL:

             case matlab::data::ArrayType::SINGLE:
             case matlab::data::ArrayType::DOUBLE:

             case matlab::data::ArrayType::INT8:
             case matlab::data::ArrayType::UINT8:
             case matlab::data::ArrayType::INT16:
             case matlab::data::ArrayType::UINT16:
             case matlab::data::ArrayType::INT32:
             case matlab::data::ArrayType::UINT32:
             case matlab::data::ArrayType::INT64:
             case matlab::data::ArrayType::UINT64:

             case matlab::data::ArrayType::COMPLEX_SINGLE:
             case matlab::data::ArrayType::COMPLEX_DOUBLE:

             case matlab::data::ArrayType::COMPLEX_UINT8:
             case matlab::data::ArrayType::COMPLEX_INT8:
             case matlab::data::ArrayType::COMPLEX_UINT16:
             case matlab::data::ArrayType::COMPLEX_INT16:
             case matlab::data::ArrayType::COMPLEX_UINT32:
             case matlab::data::ArrayType::COMPLEX_INT32:
             case matlab::data::ArrayType::COMPLEX_UINT64:
             case matlab::data::ArrayType::COMPLEX_INT64:
                 return true;

             // Unspported
             default:
                 std::u16string mattype;
                 switch (arr.getType()) {
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
