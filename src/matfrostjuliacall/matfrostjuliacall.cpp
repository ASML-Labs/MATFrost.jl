

#include <cstdint>
#include <winsock2.h>

#include "mex.hpp"
#include "mexAdapter.hpp"

#include <tuple>
// stdc++ lib
#include <map>
#include <string>

// External dependencies
// using namespace matlab::data;
using matlab::mex::ArgumentList;
#include <thread>
#include <condition_variable>
#include <mutex>

#include <complex>

#include <chrono>

#include "server.hpp"
#include "socket.hpp"
#include "write.hpp"

#include "read.hpp"



#define EXPERIMENT_SIZE 1000000

std::map<uint64_t, std::shared_ptr<MATFrost::MATFrostServer>> matfrost_server{};
std::map<uint64_t, std::shared_ptr<MATFrost::Socket::BufferedUnixDomainSocket>> matfrost_connections{};

class MexFunction : public matlab::mex::Function {
private:



public:
    MexFunction() {


    }

    ~MexFunction() override {

    }

    void operator()(ArgumentList outputs, ArgumentList inputs) {
        // matlab::data::ArrayFactory factory;
        // std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();
        // matlabPtr->feval(u"disp", 0, std::vector<matlab::data::Array>
        //           ({ factory.createScalar(("###################################\nStarting\n###################################\n"))}));

        const matlab::data::Struct input = static_cast<const matlab::data::StructArray>(inputs[0])[0];

        const uint64_t id = static_cast<const matlab::data::TypedArray<uint64_t>>(input["id"])[0];
        const std::u16string action = static_cast<const matlab::data::StringArray>(input["action"])[0];

        if (action == u"START") {
            std::string cmdline = static_cast<const matlab::data::StringArray>(input["cmdline"])[0];
            const std::string host = static_cast<const matlab::data::StringArray>(input["host"])[0];
            const int port = static_cast<const matlab::data::TypedArray<int64_t>>(input["port"])[0];
            const uint64_t timeout = static_cast<const matlab::data::TypedArray<uint64_t>>(input["timeout"])[0];

            if (matfrost_server.find(id) != matfrost_server.end() || matfrost_connections.find(id) != matfrost_connections.end()) {
                throw(matlab::engine::MATLABException("MATFrost server already started"));
            }
            auto matlab = getEngine();
            auto socket = MATFrost::Socket::BufferedUnixDomainSocket::start_server();
            cmdline += " " + socket->get_host() + " " + std::to_string(socket->get_port());
            auto server = MATFrost::MATFrostServer::spawn(cmdline);
            socket->accept_connection(server, matlab, timeout);

            matfrost_server[id] = server;
            matfrost_connections[id] = socket;


        } else if (action == u"STOP") {
            if (matfrost_connections.find(id) != matfrost_connections.end()) {
                matfrost_connections.erase(id);
            }
            if (matfrost_server.find(id) != matfrost_server.end()) {
                matfrost_server.erase(id);
            }
        }
        else if (action == u"CALL") {

            matlab::data::CellArray callstruct = input["callstruct"];

            if ( matfrost_server.find(id) == matfrost_server.end()) {
                throw(matlab::engine::MATLABException("MATFrost server not started"));
            }
            if (matfrost_connections.find(id) == matfrost_connections.end()) {
                throw(matlab::engine::MATLABException("MATFrost server not connected"));
            }

            auto socket = matfrost_connections[id];
            auto server = matfrost_server[id];

            matlab::data::ArrayFactory factory;


            MATFrost::Write::valid(callstruct);

            try {
                outputs[0] = juliacall(socket, server, callstruct);
            } catch (matlab::engine::MATLABException& e) {
                // Unrecoverable discconect and stop server
                matfrost_connections.erase(id);
                matfrost_server.erase(id);
                throw matlab::engine::MATLABException(e);
            }
        }


    }

    matlab::data::Array juliacall(const std::shared_ptr<MATFrost::Socket::BufferedUnixDomainSocket> socket, const std::shared_ptr<MATFrost::MATFrostServer> server, const matlab::data::Array callstruct) {

        auto matlab = getEngine();
        server->dump_logging(matlab);

        matlab::data::ArrayFactory factory;

        if (!socket->is_connected()) {
            throw(matlab::engine::MATLABException("MATFrost server disconnected"));
        }

        MATFrost::Write::write(socket, callstruct);
        socket->flush();

        size_t niters = socket->timeout_ms / 100+1;

        timeval timeout{0, 100000}; // 100ms

        for (size_t i = 0; i < niters; i++) {
            if (socket->wait_for_readable(timeout)) {
                // Data available to read
                auto jlout = MATFrost::Read::read(socket);

                server->dump_logging(matlab);

                return jlout;
            } else {
                server->dump_logging(matlab);

                matlab->feval(u"pause", 0, std::vector<matlab::data::Array>
                    ({ factory.createScalar(0.0)})); // No-operation added to be able interrupt.
            }
        }

        throw(matlab::engine::MATLABException("MATFrost server timeout"));

    }



};

