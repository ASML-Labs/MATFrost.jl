#include "mex.hpp"
#include "mexAdapter.hpp"

#include <tuple>
// stdc++ lib
#include <string>
#include <complex>
#include <memory>


namespace MATFrost::Read {

    matlab::data::Array read(const std::shared_ptr<Socket::BufferedTCPSocket> socket);

    template<typename T>
    matlab::data::Array read_primitive(const std::shared_ptr<Socket::BufferedTCPSocket> socket, matlab::data::ArrayDimensions dims) {
        size_t nel = 1;
        for (const auto dim : dims){
            nel *= dim;
        }

        matlab::data::ArrayFactory factory;
        matlab::data::buffer_ptr_t<T> buf = factory.createBuffer<T>(nel);

        socket->read(reinterpret_cast<uint8_t *>(buf.get()), sizeof(T)*nel);

        return factory.createArrayFromBuffer<T>(dims, std::move(buf));

    }

    matlab::data::Array read_string(const std::shared_ptr<Socket::BufferedTCPSocket> socket, matlab::data::ArrayDimensions dims) {
        size_t nel = 1;
        for (const auto dim : dims){
            nel *= dim;
        }

        matlab::data::ArrayFactory factory;

        matlab::data::StringArray strarr = factory.createArray<matlab::data::MATLABString>(dims);

        for (auto e : strarr) {
            size_t strbytes;

            socket->read(reinterpret_cast<uint8_t *>(&strbytes), sizeof(size_t));

            auto strdata = std::vector<uint8_t>(strbytes);

            socket->read(strdata.data(), strbytes);
            e = matlab::engine::convertUTF8StringToUTF16String(std::string(reinterpret_cast<char*>(strdata.data()), strbytes));

        }
        return strarr;
    }

    matlab::data::Array read_cell(const std::shared_ptr<Socket::BufferedTCPSocket> socket, matlab::data::ArrayDimensions dims) {
        matlab::data::ArrayFactory factory;

        matlab::data::CellArray carr = factory.createCellArray(dims);

        for (auto e : carr) {
            e = read(socket);
        }
        return carr;
    }

    matlab::data::Array read_struct(const std::shared_ptr<Socket::BufferedTCPSocket> socket, matlab::data::ArrayDimensions dims) {
        size_t nel = 1;
        for (const auto dim : dims){
            nel *= dim;
        }
        size_t nfields;

        socket->read(reinterpret_cast<uint8_t *>(&nfields), sizeof(size_t));

        std::vector<std::string> fieldnames(nfields);
        for (size_t i = 0; i < nfields; i++){
            size_t strbytes;

            socket->read(reinterpret_cast<uint8_t *>(&strbytes), sizeof(size_t));

            auto strdata = std::vector<uint8_t>(strbytes);

            socket->read(strdata.data(), strbytes);

            fieldnames[i] = std::string(reinterpret_cast<char*>(strdata.data()), strbytes);
        }

        matlab::data::ArrayFactory factory;


        matlab::data::StructArray matstruct = factory.createStructArray(dims, fieldnames);

        for (auto e : matstruct) {
            for (size_t fi = 0; fi < nfields; fi++){
                e[fieldnames[fi]] = read(socket);
            }
        }

        return matstruct;
    }


matlab::data::Array read(const std::shared_ptr<Socket::BufferedTCPSocket> socket){
    int32_t type;
    size_t ndims;
    socket->read(reinterpret_cast<uint8_t *>(&type), sizeof(int32_t));
    socket->read(reinterpret_cast<uint8_t *>(&ndims), sizeof(size_t));
    matlab::data::ArrayDimensions dims(ndims);
    socket->read(reinterpret_cast<uint8_t *>(dims.data()), sizeof(size_t)*ndims);

    switch (static_cast<matlab::data::ArrayType>(type)) {
        case matlab::data::ArrayType::CELL:
             return read_cell(socket, dims);
        case matlab::data::ArrayType::STRUCT:
            return read_struct(socket, dims);
        case matlab::data::ArrayType::MATLAB_STRING:
             return read_string(socket, dims);
        case matlab::data::ArrayType::LOGICAL:
            return read_primitive<bool>(socket, dims);

        case matlab::data::ArrayType::SINGLE:
            return read_primitive<float>(socket, dims);
        case matlab::data::ArrayType::DOUBLE:
            return read_primitive<double>(socket, dims);

        case matlab::data::ArrayType::INT8:
            return read_primitive<int8_t>(socket, dims);
        case matlab::data::ArrayType::UINT8:
            return read_primitive<uint8_t>(socket, dims);
        case matlab::data::ArrayType::INT16:
            return read_primitive<int16_t>(socket, dims);
        case matlab::data::ArrayType::UINT16:
            return read_primitive<uint16_t>(socket, dims);
        case matlab::data::ArrayType::INT32:
            return read_primitive<int32_t>(socket, dims);
        case matlab::data::ArrayType::UINT32:
            return read_primitive<uint32_t>(socket, dims);
        case matlab::data::ArrayType::INT64:
            return read_primitive<int64_t>(socket, dims);
        case matlab::data::ArrayType::UINT64:
            return read_primitive<uint64_t>(socket, dims);

        case matlab::data::ArrayType::COMPLEX_SINGLE:
            return read_primitive<std::complex<float>>(socket, dims);
        case matlab::data::ArrayType::COMPLEX_DOUBLE:
            return read_primitive<std::complex<double>>(socket, dims);

        case matlab::data::ArrayType::COMPLEX_UINT8:
            return read_primitive<std::complex<uint8_t>>(socket, dims);
        case matlab::data::ArrayType::COMPLEX_INT8:
            return read_primitive<std::complex<int8_t>>(socket, dims);
        case matlab::data::ArrayType::COMPLEX_UINT16:
            return read_primitive<std::complex<uint16_t>>(socket, dims);
        case matlab::data::ArrayType::COMPLEX_INT16:
            return read_primitive<std::complex<int16_t>>(socket, dims);
        case matlab::data::ArrayType::COMPLEX_UINT32:
            return read_primitive<std::complex<uint32_t>>(socket, dims);
        case matlab::data::ArrayType::COMPLEX_INT32:
            return read_primitive<std::complex<int32_t>>(socket, dims);
        case matlab::data::ArrayType::COMPLEX_UINT64:
            return read_primitive<std::complex<uint64_t>>(socket, dims);
        case matlab::data::ArrayType::COMPLEX_INT64:
            return read_primitive<std::complex<int64_t>>(socket, dims);

        default:
            throw matlab::engine::MATLABException("matfrostjulia:conversion:typeNotSupported", u"MATFrost does not support conversions to MATLAB from Julia with array_type: ");

    }
}




}

