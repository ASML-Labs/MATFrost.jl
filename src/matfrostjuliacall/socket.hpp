//
// Created by jbelier on 19/10/2025.
//

#ifndef MATFROST_JL_SOCKET_HPP
#define MATFROST_JL_SOCKET_HPP

#include <cstdint>
#include <cstdio>

#include <memory>

#include <string>
#include <iostream>
#include <array>


#ifdef _WIN32
    #include <tchar.h>
    #include <strsafe.h>
    #include <windows.h>
    #include <winsock2.h>
    #include <ws2tcpip.h>
#else
    #include <sys/types.h>
    #include <sys/socket.h>
    #include <sys/select.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <netdb.h>
    #include <unistd.h>
    #include <cerrno>
#endif





#define BUFSIZE 65536 // 16384

namespace MATFrost::Socket {

    #ifdef _WIN32
        using socket_t_ = SOCKET;
    #else
        using socket_t_ = int;
    #endif

    #ifdef _WIN32
        constexpr socket_t_ INVALID_SOCKET_ = INVALID_SOCKET;
    #else
        constexpr socket_t_ INVALID_SOCKET_ = -1;
    #endif


    #ifdef _WIN32
        inline constexpr auto SOCKET_ERROR_ = SOCKET_ERROR;
    #else
        inline constexpr auto SOCKET_ERROR_ = -1;
    #endif


        inline int socket_last_error_() {
    #ifdef _WIN32
            return WSAGetLastError();
    #else
            return errno;
    #endif
        }


        inline void close_socket_(socket_t_ s) {
    #ifdef _WIN32
            closesocket(s);
    #else
            close(s);
    #endif
        }

        inline int select_(socket_t_ s,
                                 fd_set* read_set,
                                 fd_set* write_set,
                                 fd_set* error_set,
                                 timeval* timeout) {
    #ifdef _WIN32
            return select(0, read_set, write_set, error_set, timeout);
    #else
            return select(s + 1, read_set, write_set, error_set, timeout);
    #endif
        }

    #ifdef _WIN32
        inline int send_(socket_t_ socket_fd, const void* data, size_t nb, int flags) {
            return send(socket_fd, reinterpret_cast<const char*>(data), static_cast<int>(nb), flags);
        }
    #else
        inline ssize_t send_(socket_t_ socket_fd, const void* data, size_t nb, int flags) {
            return send(socket_fd, data, nb, MSG_NOSIGNAL | flags);
        }
    #endif


    #ifdef _WIN32
        inline int recv_(socket_t_ socket_fd, void* data, size_t nb, int flags) {
            return recv(socket_fd, reinterpret_cast<char*>(data), static_cast<int>(nb), flags);
        }
    #else
        inline ssize_t recv_(socket_t_ socket_fd, void* data, size_t nb, int flags) {
            return recv(socket_fd, data, nb, flags);
        }
    #endif


    #ifdef _WIN32
        using socklen_t_ = int;
    #else
        using socklen_t_ = socklen_t;
    #endif

    #ifdef _WIN32
        inline int getsockopt_(socket_t_ s, int level, int optname, void* optval, socklen_t_* optlen) {
            return getsockopt(s, level, optname, reinterpret_cast<char*>(optval), optlen);
        }
    #else
        inline int getsockopt_(socket_t_ s, int level, int optname, void* optval, socklen_t_* optlen) {
            return getsockopt(s, level, optname, optval, optlen);
        }
    #endif

    #ifdef _WIN32
        inline int setsockopt_(socket_t_ s, int level, int optname, const void* optval, socklen_t_ optlen) {
            return setsockopt(s, level, optname, reinterpret_cast<const char*>(optval), optlen);
        }
    #else
        inline int setsockopt_(socket_t_ s, int level, int optname, const void* optval, socklen_t_ optlen) {
            return setsockopt(s, level, optname, optval, optlen);
        }
    #endif

    class SocketPlatform {
        public:
            SocketPlatform() {
                #ifdef _WIN32
                    auto rc = WSAStartup(MAKEWORD(2, 2), &data_);
                    if (rc != 0) {
                        throw(matlab::engine::MATLABException("WSAStartup failed: " + std::to_string(rc)));
                    }
                #endif
            }

            ~SocketPlatform() {
                #ifdef _WIN32
                    WSACleanup();
                #endif
            }

        private:
            #ifdef _WIN32
                WSADATA data_{};
            #endif
    };




    struct Buffer {
        std::array<uint8_t, BUFSIZE> data{};
        size_t position = 0;
        size_t available = 0;
    };


    class BufferedTCPSocket {
        const std::string host;
        const int port;
        socket_t_ socket_fd = INVALID_SOCKET_;

        timeval timeout = {5, 0};


        Buffer input{};
        Buffer output{};

        SocketPlatform socket_platform{};

    public:

        const long timeout_ms = 0;

        BufferedTCPSocket(const std::string &host, int port, socket_t_ socket, timeval timeout, uint64_t timeout_ms) :
            host(host),
            port(port),
            socket_fd(socket),
            timeout(timeout),
            timeout_ms(timeout_ms)
        {  }

        ~BufferedTCPSocket() {
            if (socket_fd != INVALID_SOCKET_) {
                close_socket_(socket_fd);
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

        size_t write_to_socket(const uint8_t *data, const size_t nb) {

            if (!wait_for_writable(timeout)) {
                throw matlab::engine::MATLABException("Write socket timeout: " + std::to_string(timeout.tv_sec) + " seconds");
            }

            const auto sent = send_(socket_fd,
                data,
                nb,
                0);

            if (sent > 0) {
                return sent;
                // Might block here on next iteration if buffer fills
            } else if (sent == 0) {
                throw matlab::engine::MATLABException("Connection closed");
            } else {
                throw matlab::engine::MATLABException("Socket send error: " +
                                       std::to_string(socket_last_error_()));
            }

        }

        size_t read_from_socket(uint8_t *data, const size_t nb) {
            // Use select to wait for data with timeout
            if (!wait_for_readable(timeout)) {
                throw matlab::engine::MATLABException("MATFrost timeout: " + std::to_string(timeout.tv_sec) + " seconds");
            }

            auto brn = recv_(
                        socket_fd,
                        data,
                        nb,
                        0);

            if (brn > 0) {
                return brn;
            } else if (brn == 0) {
                throw matlab::engine::MATLABException("Connection closed by peer during read");
            } else {
                throw matlab::engine::MATLABException("Socket read error: " + std::to_string(socket_last_error_()));
            }
        }

        bool wait_for_readable(timeval time_out) const {
            if (socket_fd == INVALID_SOCKET_) {
                throw matlab::engine::MATLABException("Invalid socket");
            }

            fd_set read_set, error_set;
            FD_ZERO(&read_set);
            FD_ZERO(&error_set);

            FD_SET(socket_fd, &read_set);
            FD_SET(socket_fd, &error_set);


            int result = select_(socket_fd, &read_set, nullptr, &error_set, &time_out);

            if (result == SOCKET_ERROR_) {
                throw matlab::engine::MATLABException("Socket error: " + std::to_string(socket_last_error_()));
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
                int peek_result = recv_(socket_fd, buf, 1, MSG_PEEK);
                if (peek_result == 0) {
                    // EOF - connection closed
                    throw matlab::engine::MATLABException("Socket - EOF connection closed");
                }
                return true;
            }
            throw matlab::engine::MATLABException("Socket error:");
        }

        bool wait_for_writable(timeval time_out) const {
            if (socket_fd == INVALID_SOCKET_) {
                throw matlab::engine::MATLABException("Invalid socket");
            }

            fd_set write_set, error_set;
            FD_ZERO(&write_set);
            FD_ZERO(&error_set);

            FD_SET(socket_fd, &write_set);
            FD_SET(socket_fd, &error_set);



            int result = select_(socket_fd, nullptr, &write_set, &error_set, &time_out);

            if (result == SOCKET_ERROR_) {
                
                throw matlab::engine::MATLABException("Socket error: " + std::to_string(socket_last_error_()));
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
                socklen_t_ error_len = static_cast<socklen_t_>(sizeof(error));
                if (getsockopt_(socket_fd, SOL_SOCKET, SO_ERROR,
                              &error, &error_len) == SOCKET_ERROR_) {
                    throw matlab::engine::MATLABException("Write socket");
                              }
                
                if (error == 0) {
                    return true;
                }
            }
            throw matlab::engine::MATLABException("Socket error");
        }


        bool is_connected() const {
            if (socket_fd == INVALID_SOCKET_) {
                return false;
            }

            fd_set write_set, error_set;
            FD_ZERO(&write_set);
            FD_ZERO(&error_set);

            FD_SET(socket_fd, &write_set);
            FD_SET(socket_fd, &error_set);

            // Zero timeout = immediate return (non-blocking check)
            timeval timeout = {0, 0};

            int result = select_(socket_fd, nullptr, &write_set, &error_set, &timeout);

            if (result == SOCKET_ERROR_ || result == 0) {
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
                if (getsockopt_(socket_fd, SOL_SOCKET, SO_ERROR,
                              &error, &error_len) == SOCKET_ERROR_) {
                    return false;
                              }
                return error == 0;
            }

            return false;
        }
    };
    class TCPServerSocket{
        const std::string host;
        const int port;
        socket_t_ socket_fd = INVALID_SOCKET_;

        SocketPlatform socket_platform{};

    public:


        TCPServerSocket(const std::string &host, int port, socket_t_ socket) :
            host(host),
            port(port),
            socket_fd(socket)
        {  }

        ~TCPServerSocket() {
            if (socket_fd != INVALID_SOCKET_) {
                close_socket_(socket_fd);
            }
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
        static socket_t_ create_and_bind_server_socket(const std::string &bind_host, int bind_port, int &actual_port) {

            socket_t_ listen_socket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
            if (listen_socket == INVALID_SOCKET_) {
                throw(matlab::engine::MATLABException("Failed to create server socket: " +
                                                     std::to_string(socket_last_error_())));
            }

            // Enable SO_REUSEADDR (except when port is 0)
            if (bind_port != 0) {
                int reuse = 1;
                if (setsockopt_(listen_socket, SOL_SOCKET, SO_REUSEADDR,
                              &reuse, sizeof(reuse)) == SOCKET_ERROR_) {
                    int error = socket_last_error_();
                    close_socket_(listen_socket);
                    throw(matlab::engine::MATLABException("Failed to set SO_REUSEADDR: " + std::to_string(error)));
                }
            }

            sockaddr_in server_addr = {0};
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
                    close_socket_(listen_socket);
                    throw(matlab::engine::MATLABException("Failed to resolve bind hostname '" + bind_host + "': " + 
                                                         std::to_string(getaddrinfo_result)));
                }
                
                server_addr.sin_addr = reinterpret_cast<struct sockaddr_in*>(result->ai_addr)->sin_addr;
                freeaddrinfo(result);
            }

            socklen_t_ addr_len = sizeof(server_addr);

            if (bind(listen_socket, reinterpret_cast<struct sockaddr*>(&server_addr), addr_len) == SOCKET_ERROR_) {
                int error = socket_last_error_();
                close_socket_(listen_socket);
                std::string addr_str = bind_host.empty() ? "0.0.0.0" : bind_host;
                if (bind_port == 0) {
                    throw(matlab::engine::MATLABException("Failed to bind server socket to " + addr_str + ": " + std::to_string(error)));
                } else {
                    throw(matlab::engine::MATLABException("Failed to bind server socket to " + addr_str + 
                                                         ":" + std::to_string(bind_port) + ": " + std::to_string(error)));
                }
            }

            // Get the actual port if it was auto-assigned
            if (getsockname(listen_socket, reinterpret_cast<struct sockaddr*>(&server_addr), &addr_len) == SOCKET_ERROR_) {
                int error = socket_last_error_();
                close_socket_(listen_socket);
                throw(matlab::engine::MATLABException("Failed to get socket name: " + std::to_string(error)));
            }
            actual_port = ntohs(server_addr.sin_port);

            if (listen(listen_socket, 1) == SOCKET_ERROR_) {
                int error = socket_last_error_();
                close_socket_(listen_socket);
                throw(matlab::engine::MATLABException("Failed to listen on server socket: " + std::to_string(error)));
            }

            return listen_socket;
        }

    public:
        // Start server - automatically choose port, accept any connection
        static std::shared_ptr<TCPServerSocket> start_server() {
            SocketPlatform socket_platform{};
            int actual_port = 0;
            socket_t_ listen_socket = create_and_bind_server_socket("0.0.0.0", 0, actual_port);

            return std::make_shared<TCPServerSocket>("0.0.0.0", actual_port, listen_socket);
        }

        // Start server on given port, accept any host
        static std::shared_ptr<TCPServerSocket> start_server(int port) {
            SocketPlatform socket_platform{};
            int actual_port = 0;
            socket_t_ listen_socket = create_and_bind_server_socket("0.0.0.0", port, actual_port);

            return std::make_shared<TCPServerSocket>("0.0.0.0", actual_port, listen_socket);
        }

        // Start server on given port, accept only from specified host
        static std::shared_ptr<TCPServerSocket> start_server(const std::string &bind_host, int port) {
            SocketPlatform socket_platform{};
            int actual_port = 0;
            socket_t_ listen_socket = create_and_bind_server_socket(bind_host, port, actual_port);

            return std::make_shared<TCPServerSocket>(bind_host, actual_port, listen_socket);
        }

        // Accept connection - waits until client connects, closes server socket after accepting
        std::shared_ptr<BufferedTCPSocket> accept_connection(
            const std::shared_ptr<MATFrostServer> server,
            std::shared_ptr<matlab::engine::MATLABEngine> matlab,
            uint64_t timeout_ms = 24*60*60*1000) {
            
            if (socket_fd == INVALID_SOCKET_) {
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

                timeval timeout_accept = {0, 100000};  // 100ms timeout for each attempt

                int select_result = select_(socket_fd, &read_set, nullptr, nullptr, &timeout_accept);
                
                if (select_result == SOCKET_ERROR_) {
                    throw(matlab::engine::MATLABException("Select failed on server socket: " + 
                                                         std::to_string(socket_last_error_())));
                }
                
                if (select_result > 0) {
                    // Connection is ready to accept
                    sockaddr_in client_addr = {0};
                    socklen_t client_addr_len = static_cast<socklen_t>(sizeof(client_addr));
                    socket_t_ client_socket = accept(socket_fd,
                                                 reinterpret_cast<struct sockaddr*>(&client_addr), 
                                                 &client_addr_len);

                    if (client_socket == INVALID_SOCKET_) {
                        throw(matlab::engine::MATLABException("Failed to accept connection: " + 
                                                             std::to_string(socket_last_error_())));
                    }

                    timeval timeout;
                    timeout.tv_sec = timeout_ms / 1000;
                    timeout.tv_usec = (timeout_ms % 1000) * 1000;

                    server->dump_logging(matlab);

                    return std::make_shared<BufferedTCPSocket>(host, port, client_socket, timeout, timeout_ms);
                }

                // No connection yet, continue waiting
                server->dump_logging(matlab);
                matlab->feval(u"pause", 0, std::vector<matlab::data::Array>
                    ({ factory.createScalar(0.0)})); // No-operation added to be able to interrupt

                std::this_thread::sleep_for(std::chrono::milliseconds(100));
            }

            throw(matlab::engine::MATLABException("Accept timeout after " + 
                                                 std::to_string(timeout_ms) + " ms"));
        }

        static std::shared_ptr<BufferedTCPSocket> connect_socket(const std::string host, const int port, const std::shared_ptr<MATFrostServer> server, std::shared_ptr<matlab::engine::MATLABEngine> matlab, const long timeout_ms) {

            SocketPlatform socket_platform{};

            matlab::data::ArrayFactory factory;

            // Resolve hostname to IP address
            struct addrinfo hints = {0};
            struct addrinfo *result = nullptr;
            hints.ai_family = AF_INET;        // IPv4
            hints.ai_socktype = SOCK_STREAM;  // TCP
            
            int getaddrinfo_result = getaddrinfo(host.c_str(), nullptr, &hints, &result);
            if (getaddrinfo_result != 0) {
                throw(matlab::engine::MATLABException("Failed to resolve hostname '" + host + "': " + 
                                                     std::to_string(getaddrinfo_result)));
            }
            
            // Get the IP address from the first result
            sockaddr_in socket_addr = {0};
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

                socket_t_ socket_fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

                if (socket_fd == INVALID_SOCKET_) {
                    throw(matlab::engine::MATLABException("Failed to create socket: " +
                                                         std::to_string(socket_last_error_())));
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
                    return std::make_shared<BufferedTCPSocket>(host, port, socket_fd, timeout, timeout_ms);
                }
                
                close_socket_(socket_fd);

                server->dump_logging(matlab);
                matlab->feval(u"pause", 0, std::vector<matlab::data::Array>
                    ({ factory.createScalar(0.0)})); // No-operation added to be able interrupt.

                std::this_thread::sleep_for(std::chrono::milliseconds(100));
            }
            throw(matlab::engine::MATLABException("Connection timeout after " +
                                     std::to_string(connection_timeout_s) +
                                     " seconds: " + host + ":" + std::to_string(port)));

        }

    };
}


#endif //MATFROST_JL_SOCKET_HPP