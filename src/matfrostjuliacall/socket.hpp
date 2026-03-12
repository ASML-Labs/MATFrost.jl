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
        const int port;
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

        // Getter methods for host and port
        std::string get_host() const {
            return host;
        }

        int get_port() const {
            return port;
        }

    private:
        // Common initialization for server socket
        static SOCKET create_and_bind_server_socket(const std::string &bind_host, int bind_port, int &actual_port) {
            if (!wsa_initialized) {
                int rc = WSAStartup(MAKEWORD(2, 2), &wsa_data);
                if (rc != 0) {
                    throw(matlab::engine::MATLABException("WSAStartup failed: " + std::to_string(rc)));
                }
                wsa_initialized = true;
            }

            SOCKET listen_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
            if (listen_socket == INVALID_SOCKET) {
                throw(matlab::engine::MATLABException("Failed to create server socket: " +
                                                     std::to_string(WSAGetLastError())));
            }

            // Enable SO_REUSEADDR (except when port is 0)
            if (bind_port != 0) {
                int reuse = 1;
                if (setsockopt(listen_socket, SOL_SOCKET, SO_REUSEADDR, 
                              reinterpret_cast<char*>(&reuse), sizeof(reuse)) == SOCKET_ERROR) {
                    int error = WSAGetLastError();
                    closesocket(listen_socket);
                    throw(matlab::engine::MATLABException("Failed to set SO_REUSEADDR: " + std::to_string(error)));
                }
            }

            SOCKADDR_IN server_addr = {0};
            server_addr.sin_family = AF_INET;
            server_addr.sin_port = htons(static_cast<u_short>(bind_port));

            // Resolve bind address
            if (bind_host.empty() || bind_host == "0.0.0.0") {
                server_addr.sin_addr.s_addr = INADDR_ANY;
            } else {
                struct addrinfo hints = {0};
                struct addrinfo *result = nullptr;
                hints.ai_family = AF_INET;
                hints.ai_socktype = SOCK_STREAM;
                
                int getaddrinfo_result = getaddrinfo(bind_host.c_str(), nullptr, &hints, &result);
                if (getaddrinfo_result != 0) {
                    closesocket(listen_socket);
                    throw(matlab::engine::MATLABException("Failed to resolve bind hostname '" + bind_host + "': " + 
                                                         std::to_string(WSAGetLastError())));
                }
                
                server_addr.sin_addr = reinterpret_cast<struct sockaddr_in*>(result->ai_addr)->sin_addr;
                freeaddrinfo(result);
            }

            if (bind(listen_socket, reinterpret_cast<struct sockaddr*>(&server_addr), sizeof(server_addr)) == SOCKET_ERROR) {
                int error = WSAGetLastError();
                closesocket(listen_socket);
                std::string addr_str = bind_host.empty() ? "0.0.0.0" : bind_host;
                if (bind_port == 0) {
                    throw(matlab::engine::MATLABException("Failed to bind server socket to " + addr_str + ": " + std::to_string(error)));
                } else {
                    throw(matlab::engine::MATLABException("Failed to bind server socket to " + addr_str + 
                                                         ":" + std::to_string(bind_port) + ": " + std::to_string(error)));
                }
            }

            // Get the actual port if it was auto-assigned
            int addr_len = sizeof(server_addr);
            if (getsockname(listen_socket, reinterpret_cast<struct sockaddr*>(&server_addr), &addr_len) == SOCKET_ERROR) {
                int error = WSAGetLastError();
                closesocket(listen_socket);
                throw(matlab::engine::MATLABException("Failed to get socket name: " + std::to_string(error)));
            }
            actual_port = ntohs(server_addr.sin_port);

            if (listen(listen_socket, 1) == SOCKET_ERROR) {
                int error = WSAGetLastError();
                closesocket(listen_socket);
                throw(matlab::engine::MATLABException("Failed to listen on server socket: " + std::to_string(error)));
            }

            return listen_socket;
        }

    public:
        // Start server - automatically choose port, accept any connection
        static std::shared_ptr<BufferedUnixDomainSocket> start_server() {
            int actual_port = 0;
            SOCKET listen_socket = create_and_bind_server_socket("0.0.0.0", 0, actual_port);
            
            timeval timeout = {24*60*60, 0};  // 24 hours
            return std::make_shared<BufferedUnixDomainSocket>("0.0.0.0", actual_port, listen_socket, timeout, 24*60*60*1000);
        }

        // Start server on given port, accept any host
        static std::shared_ptr<BufferedUnixDomainSocket> start_server(int port) {
            int actual_port = 0;
            SOCKET listen_socket = create_and_bind_server_socket("0.0.0.0", port, actual_port);
            
            timeval timeout = {24*60*60, 0};  // 24 hours
            return std::make_shared<BufferedUnixDomainSocket>("0.0.0.0", actual_port, listen_socket, timeout, 24*60*60*1000);
        }

        // Start server on given port, accept only from specified host
        static std::shared_ptr<BufferedUnixDomainSocket> start_server(const std::string &bind_host, int port) {
            int actual_port = 0;
            SOCKET listen_socket = create_and_bind_server_socket(bind_host, port, actual_port);
            
            timeval timeout = {24*60*60, 0};  // 24 hours
            return std::make_shared<BufferedUnixDomainSocket>(bind_host, actual_port, listen_socket, timeout, 24*60*60*1000);
        }

        // Accept connection - waits until client connects, closes server socket after accepting
        void accept_connection(
            const std::shared_ptr<MATFrostServer> server,
            std::shared_ptr<matlab::engine::MATLABEngine> matlab,
            uint64_t timeout_ms = 24*60*60*1000) {
            
            if (socket_fd == INVALID_SOCKET) {
                throw(matlab::engine::MATLABException("Invalid server socket"));
            }

            matlab::data::ArrayFactory factory;
            
            size_t connection_timeout_s = timeout_ms / 1000;
            size_t attempts = connection_timeout_s * 10;

            for (int attempt = 0; attempt < attempts; attempt++) {

                if (!server->is_alive()) {
                    server->dump_logging(matlab);
                    throw(matlab::engine::MATLABException("MATFrost server not running"));
                }

                // Wait for connection with select (short timeout for periodic checks)
                fd_set read_set;
                FD_ZERO(&read_set);
                FD_SET(socket_fd, &read_set);

                timeval timeout = {0, 100000};  // 100ms timeout for each attempt

                int select_result = select(0, &read_set, nullptr, nullptr, &timeout);
                
                if (select_result == SOCKET_ERROR) {
                    throw(matlab::engine::MATLABException("Select failed on server socket: " + 
                                                         std::to_string(WSAGetLastError())));
                }
                
                if (select_result > 0) {
                    // Connection is ready to accept
                    SOCKADDR_IN client_addr = {0};
                    int client_addr_len = sizeof(client_addr);
                    SOCKET client_socket = accept(socket_fd, 
                                                 reinterpret_cast<struct sockaddr*>(&client_addr), 
                                                 &client_addr_len);

                    if (client_socket == INVALID_SOCKET) {
                        throw(matlab::engine::MATLABException("Failed to accept connection: " + 
                                                             std::to_string(WSAGetLastError())));
                    }

                    // Close the old server socket (no more connections allowed)
                    closesocket(socket_fd);

                    // Update this socket to be the client connection socket
                    socket_fd = client_socket;

                    // Update timeout structure for the client socket
                    timeout.tv_sec = timeout_ms / 1000;
                    timeout.tv_usec = (timeout_ms % 1000) * 1000;

                    server->dump_logging(matlab);
                    return;
                }

                // No connection yet, continue waiting
                server->dump_logging(matlab);
                matlab->feval(u"pause", 0, std::vector<matlab::data::Array>
                    ({ factory.createScalar(0.0)})); // No-operation added to be able to interrupt

                Sleep(100);
            }

            throw(matlab::engine::MATLABException("Accept timeout after " + 
                                                 std::to_string(timeout_ms) + " ms"));
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