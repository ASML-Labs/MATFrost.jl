//
// Created by jbelier on 19/10/2025.
//

#ifndef MATFROST_JL_SOCKET_HPP
#define MATFROST_JL_SOCKET_HPP

#include <cstdint>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <tchar.h>
#include <cstdio>
#include <strsafe.h>

#include <memory>

#include <string>
#include <iostream>
#include <array>

#define BUFSIZE 65536 // 16384

namespace MATFrost::Socket {

    bool wsa_initialized = false;
    WSADATA wsa_data = { 0 };


    struct Buffer {
        std::array<uint8_t, BUFSIZE> data{};
        size_t position = 0;
        size_t available = 0;
    };


    class BufferedUnixDomainSocket {
        const std::string host;
        int port;
        SOCKET socket_fd = INVALID_SOCKET;

        timeval timeout = {5, 0};


        Buffer input{};
        Buffer output{};

    public:

        const long timeout_ms = 0;

        BufferedUnixDomainSocket(const std::string &host, int port, SOCKET socket, timeval timeout, uint64_t timeout_ms) :
            host(host),
            port(port),
            socket_fd(socket),
            timeout(timeout),
            timeout_ms(timeout_ms)
        {  }

        ~BufferedUnixDomainSocket() {
            if (socket_fd != INVALID_SOCKET) {
                closesocket(socket_fd);
            }
        }


        void read(uint8_t *data, const size_t nb) {
            size_t br = 0;

            while (br < nb) {
                if (input.available - input.position > 0) {
                    size_t brn = std::min(input.available - input.position, nb - br);
                    memcpy(&data[br], &input.data[input.position], brn);
                    input.position += brn;
                    br += brn;
                } else if (nb - br >= BUFSIZE) {
                    br += read_from_socket(&data[br], BUFSIZE);;
                } else {
                    input.position = 0;
                    input.available = read_from_socket(&input.data[0], BUFSIZE);
                }
            }
        };

        void write(const uint8_t *data, const size_t nb) {
            size_t bw = std::min(BUFSIZE - output.available, nb);
            memcpy(&output.data[output.available], data, bw);
            output.available += bw;

            if (bw >= nb) {
                return;
            }

            flush();

            while (nb - bw >= BUFSIZE) {
                bw += write_to_socket(&data[bw], BUFSIZE);
            }

            if (bw < nb) {
                output.position = 0;
                output.available = nb - bw;
                memcpy(&output.data[0], &data[bw], output.available);
            }
        }

        void flush() {
            while (output.available > output.position) {
                output.position += write_to_socket(&output.data[output.position], output.available - output.position);
            }
            output.position = 0;
            output.available = 0;
        }

        int write_to_socket(const uint8_t *data, const size_t nb) {

            if (!wait_for_writable(timeout)) {
                throw matlab::engine::MATLABException("Write socket timeout: " + std::to_string(timeout.tv_sec) + " seconds");
            }

            int sent = send(socket_fd,
                reinterpret_cast<const char*>(data),
                static_cast<int>(nb),
                0);

            if (sent > 0) {
                return sent;
                // Might block here on next iteration if buffer fills
            } else if (sent == 0) {
                throw matlab::engine::MATLABException("Connection closed");
            } else {
                throw matlab::engine::MATLABException("Socket send error: " +
                                       std::to_string(WSAGetLastError()));
            }

        }

        int read_from_socket(uint8_t *data, const int nb) {
            // Use select to wait for data with timeout
            if (!wait_for_readable(timeout)) {
                throw matlab::engine::MATLABException("MATFrost timeout: " + std::to_string(timeout.tv_sec) + " seconds");
            }

            auto brn = recv(
                        socket_fd,
                        reinterpret_cast<char *>(data),
                        nb,
                        0);

            if (brn > 0) {
                return brn;
            } else if (brn == 0) {
                throw matlab::engine::MATLABException("Connection closed by peer during read");
            } else {
                throw matlab::engine::MATLABException("Socket read error: " + std::to_string(WSAGetLastError()));
            }
        }

        bool wait_for_readable(timeval time_out) const {
            if (socket_fd == INVALID_SOCKET) {
                throw matlab::engine::MATLABException("Invalid socket");
            }

            fd_set read_set, error_set;
            FD_ZERO(&read_set);
            FD_ZERO(&error_set);

            FD_SET(socket_fd, &read_set);
            FD_SET(socket_fd, &error_set);


            int result = select(0, &read_set, nullptr, &error_set, &time_out);

            if (result == SOCKET_ERROR) {
                throw matlab::engine::MATLABException("Socket error: " + std::to_string(WSAGetLastError()));
            }

            if (result == 0) {
                // Timeout
                return false;
            }

            // Check for errors
            if (FD_ISSET(socket_fd, &error_set)) {
                throw matlab::engine::MATLABException("Socket error:");
            }

            // Check if data is available
            if (FD_ISSET(socket_fd, &read_set)) {
                // Verify it's not EOF
                char buf[1];
                int peek_result = recv(socket_fd, buf, 1, MSG_PEEK);
                if (peek_result == 0) {
                    // EOF - connection closed
                    throw matlab::engine::MATLABException("Socket - EOF connection closed");
                }
                return true;
            }
            throw matlab::engine::MATLABException("Socket error:");
        }

        bool wait_for_writable(timeval time_out) const {
            if (socket_fd == INVALID_SOCKET) {
                throw matlab::engine::MATLABException("Invalid socket");
            }

            fd_set write_set, error_set;
            FD_ZERO(&write_set);
            FD_ZERO(&error_set);

            FD_SET(socket_fd, &write_set);
            FD_SET(socket_fd, &error_set);



            int result = select(0, nullptr, &write_set, &error_set, &time_out);

            if (result == SOCKET_ERROR) {
                
                throw matlab::engine::MATLABException("Socket error: " + std::to_string(WSAGetLastError()));
                // return false;
            }

            if (result == 0) {
                // Timeout
                return false;

            }

            // Check for errors first
            if (FD_ISSET(socket_fd, &error_set)) {
                throw matlab::engine::MATLABException("Socket error");
            }

            // Check if writable
            if (FD_ISSET(socket_fd, &write_set)) {
                // Optionally verify connection is still good
                int error = 0;
                int error_len = sizeof(error);
                if (getsockopt(socket_fd, SOL_SOCKET, SO_ERROR,
                              reinterpret_cast<char*>(&error), &error_len) == SOCKET_ERROR) {
                    throw matlab::engine::MATLABException("Write socket");
                }
                
                if (error == 0) {
                    return true;
                }
            }
            throw matlab::engine::MATLABException("Socket error");
        }


        bool is_connected() const {
            if (socket_fd == INVALID_SOCKET) {
                return false;
            }

            fd_set write_set, error_set;
            FD_ZERO(&write_set);
            FD_ZERO(&error_set);

            FD_SET(socket_fd, &write_set);
            FD_SET(socket_fd, &error_set);

            // Zero timeout = immediate return (non-blocking check)
            timeval timeout = {0, 0};

            int result = select(0, nullptr, &write_set, &error_set, &timeout);

            if (result == SOCKET_ERROR || result == 0) {
                return false;
            }

            // Check for errors
            if (FD_ISSET(socket_fd, &error_set)) {
                return false;
            }

            // Check if writable (connected sockets are usually writable)
            if (FD_ISSET(socket_fd, &write_set)) {
                // Verify no pending error
                int error = 0;
                int error_len = sizeof(error);
                if (getsockopt(socket_fd, SOL_SOCKET, SO_ERROR,
                              reinterpret_cast<char*>(&error), &error_len) == SOCKET_ERROR) {
                    return false;
                              }
                return error == 0;
            }

            return false;
        }

        static std::shared_ptr<BufferedUnixDomainSocket> connect_socket(const std::string host, const int port, const std::shared_ptr<MATFrostServer> server, std::shared_ptr<matlab::engine::MATLABEngine> matlab, const long timeout_ms) {

            if (!wsa_initialized) {
                int rc = WSAStartup(MAKEWORD(2, 2), &wsa_data);
                if (rc != 0) {
                    throw(matlab::engine::MATLABException("WSAStartup failed: " + std::to_string(rc)));
                }
                wsa_initialized = true;
            }

            matlab::data::ArrayFactory factory;

            // Resolve hostname to IP address
            struct addrinfo hints = {0};
            struct addrinfo *result = nullptr;
            hints.ai_family = AF_INET;        // IPv4
            hints.ai_socktype = SOCK_STREAM;  // TCP
            
            int getaddrinfo_result = getaddrinfo(host.c_str(), nullptr, &hints, &result);
            if (getaddrinfo_result != 0) {
                throw(matlab::engine::MATLABException("Failed to resolve hostname '" + host + "': " + 
                                                     std::to_string(WSAGetLastError())));
            }
            
            // Get the IP address from the first result
            SOCKADDR_IN socket_addr = {0};
            socket_addr.sin_family = AF_INET;
            socket_addr.sin_addr = reinterpret_cast<struct sockaddr_in*>(result->ai_addr)->sin_addr;
            socket_addr.sin_port = htons(static_cast<u_short>(port));
            
            freeaddrinfo(result);


            size_t connection_timeout_s = 3600;
            size_t attempts = connection_timeout_s * 10;

            for (int attempt = 0; attempt < attempts; attempt++) {

                if (!server->is_alive()) {
                    server->dump_logging(matlab);
                    throw(matlab::engine::MATLABException("MATFrost server not running"));
                }

                SOCKET socket_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

                if (socket_fd == INVALID_SOCKET) {
                    throw(matlab::engine::MATLABException("Failed to create socket: " +
                                                         std::to_string(WSAGetLastError())));
                }

                // Attempt connection
                int rc = connect(socket_fd, reinterpret_cast<struct sockaddr *>(&socket_addr),
                                sizeof(socket_addr));

                if (rc == 0) {

                    // Connection succeeded immediately
                    timeval timeout;
                    timeout.tv_sec = timeout_ms / 1000;
                    timeout.tv_usec = (timeout_ms % 1000) * 1000;

                    server->dump_logging(matlab);
                    return std::make_shared<BufferedUnixDomainSocket>(host, port, socket_fd, timeout, timeout_ms);
                }
                
                closesocket(socket_fd);

                server->dump_logging(matlab);
                matlab->feval(u"pause", 0, std::vector<matlab::data::Array>
                    ({ factory.createScalar(0.0)})); // No-operation added to be able interrupt.

                Sleep(100);
            }
            throw(matlab::engine::MATLABException("Connection timeout after " +
                                     std::to_string(connection_timeout_s) +
                                     " seconds: " + host + ":" + std::to_string(port)));

        }

    };
}


#endif //MATFROST_JL_SOCKET_HPP