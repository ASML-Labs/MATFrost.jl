/**
 * This file is responsible of managing the Julia process and offer a communication interface over pipes with the Julia
 * process. This class is free of MATLAB dependencies
 */

#ifndef MATFROST_JL_SERVER_HPP
#define MATFROST_JL_SERVER_HPP

#include <cstdint>
#include <cstdio>


#ifdef _WIN32
#include <winsock2.h>
#include <windows.h>
#include <tchar.h>
#include <strsafe.h>
#else
#include <unistd.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>
#include <cstring>
#endif

#include <memory>

#include <string>
#include <iostream>
#include <array>

namespace MATFrost {

    class MATFrostServer {

    public:

#ifdef _WIN32
        PROCESS_INFORMATION process_information{};
        HANDLE h_stdouterr{nullptr};

        MATFrostServer(PROCESS_INFORMATION process_information, HANDLE h_stdouterr) :
            process_information(process_information), h_stdouterr(h_stdouterr)
        {
        }
#else
        pid_t process_id{-1};
        int fd_stdouterr{-1};

        MATFrostServer(pid_t process_id, int fd_stdouterr) :
            process_id(process_id), fd_stdouterr(fd_stdouterr)
        {
        }
#endif


        ~MATFrostServer() {
#ifdef _WIN32
            if (process_information.hProcess != nullptr) {
                TerminateProcess(process_information.hProcess, 0);
                WaitForSingleObject(process_information.hProcess, 500);
                CloseHandle(process_information.hProcess);
                process_information.hProcess = nullptr;
            }

            if (process_information.hThread != nullptr) {
                CloseHandle(process_information.hThread);
                process_information.hThread = nullptr;
            }

            if (h_stdouterr != nullptr) {
                CloseHandle(h_stdouterr);
                h_stdouterr = nullptr;
            }
#else
            if (process_id > 0) {
                kill(process_id, SIGTERM);

                for (int i = 0; i < 5; ++i) {
                    int status = 0;
                    pid_t result = waitpid(process_id, &status, WNOHANG);
                    if (result == process_id) {
                        break;
                    }
                    usleep(100000);
                }

                int status = 0;
                if (waitpid(process_id, &status, WNOHANG) == 0) {
                    kill(process_id, SIGKILL);
                    waitpid(process_id, &status, 0);
                }

                process_id = -1;
            }

            if (fd_stdouterr >= 0) {
                close(fd_stdouterr);
                fd_stdouterr = -1;
            }
#endif
        }

        bool is_alive() {
#ifdef _WIN32
            DWORD exit_code = 0;
            if (!GetExitCodeProcess(process_information.hProcess, &exit_code)) {
                return false;
            }
            return exit_code == STILL_ACTIVE;
#else
            if (process_id <= 0) {
                return false;
            }

            int status = 0;
            pid_t result = waitpid(process_id, &status, WNOHANG);
            return result == 0;
#endif
        }

#ifdef _WIN32
        static size_t bytes_available(HANDLE handle) {
            DWORD available = 0;
            BOOL result = PeekNamedPipe(handle, nullptr, 0, nullptr, &available, nullptr);
            if (result != 0) {
                return static_cast<size_t>(available);
            }
            return -1;
        }
#else
        static size_t bytes_available(int fd) {
            int available = 0;
            if (ioctl(fd, FIONREAD, &available) == 0) {
                return static_cast<size_t>(available);
            }
            return -1;
        }
#endif

#ifdef _WIN32
        static std::string read_string(HANDLE handle) {
            DWORD ba = bytes_available(handle);
            if (ba == 0) {
                return "";
            }

            std::string buffer;
            buffer.resize(ba);

            DWORD bytes_read = 0;
            BOOL result = ReadFile(
                handle,
                &buffer[0],
                ba,
                &bytes_read,
                nullptr
            );

            if (!result || bytes_read == 0) {
                return "";
            }

            buffer.resize(bytes_read);
            return buffer;
        }

#else
        static std::string read_string(int fd) {
            size_t ba = bytes_available(fd);
            if (ba <= 0) {
                return "";
            }

            std::string buffer;
            buffer.resize(ba);

            ssize_t bytes_read = read(fd, &buffer[0], ba);
            if (bytes_read <= 0) {
                return "";
            }

            buffer.resize(bytes_read);
            return buffer;
        }
#endif




        void dump_logging(std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr) {

            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"disp", 0, std::vector<matlab::data::Array>
            ({factory.createScalar("Dump Logging start!")}));
#ifdef _WIN32
            size_t ba = bytes_available(h_stdouterr);
#else
            size_t ba = bytes_available(fd_stdouterr);
#endif

            if (ba> 0) {
                matlabPtr->feval(u"disp", 0, std::vector<matlab::data::Array>
({factory.createScalar("Dump Logging read string!")}));
#ifdef _WIN32
                std::string logged_su8 = read_string(h_stdouterr);
#else
                std::string logged_su8 = read_string(fd_stdouterr);
#endif
                matlabPtr->feval(u"disp", 0, std::vector<matlab::data::Array>
({factory.createScalar("Dump Logging convert string!")}));
                matlab::data::ArrayFactory factory;
                std::u16string logging = matlab::engine::convertUTF8StringToUTF16String(logged_su8);
                if (logging.size() == 0) {
                    return;
                }
                matlabPtr->feval(u"disp", 0, std::vector<matlab::data::Array>
                  ({factory.createScalar(logging)}));
                // return read_string(h_stdouterr);
            }

            matlabPtr->feval(u"disp", 0, std::vector<matlab::data::Array>
        ({factory.createScalar("Dump Logging end!")}));

        }

        static std::shared_ptr<MATFrostServer> spawn(const std::string cmdline) {

           #ifdef _WIN32
            SECURITY_ATTRIBUTES saAttr;
            saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
            saAttr.bInheritHandle = TRUE;
            saAttr.lpSecurityDescriptor = NULL;

            std::string cmdline_pipes = cmdline;

            PROCESS_INFORMATION piProcInfo;
            STARTUPINFOA siStartInfo;
            ZeroMemory(&piProcInfo, sizeof(PROCESS_INFORMATION));
            ZeroMemory(&siStartInfo, sizeof(STARTUPINFOA));

            HANDLE h_stdouterr[2];
            if (!CreatePipe(&h_stdouterr[0], &h_stdouterr[1], &saAttr, 0)) {
                throw matlab::engine::MATLABException("CreatePipe failed");
            }

            SetHandleInformation(h_stdouterr[0], HANDLE_FLAG_INHERIT, 0);

            siStartInfo.cb = sizeof(STARTUPINFOA);
            siStartInfo.hStdOutput = h_stdouterr[1];
            siStartInfo.hStdError  = h_stdouterr[1];
            siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

            if (!CreateProcessA(
                nullptr,
                &cmdline_pipes[0],
                nullptr,
                nullptr,
                TRUE,
                CREATE_NO_WINDOW,
                nullptr,
                nullptr,
                &siStartInfo,
                &piProcInfo
            )) {
                CloseHandle(h_stdouterr[0]);
                CloseHandle(h_stdouterr[1]);
                throw matlab::engine::MATLABException("Julia process could not be started. With cmdline: " + cmdline);
            }

            CloseHandle(h_stdouterr[1]);

            return std::make_shared<MATFrostServer>(piProcInfo, h_stdouterr[0]);
#else
            int pipefd[2];
            if (pipe(pipefd) != 0) {
                throw matlab::engine::MATLABException("pipe() failed");
            }

            pid_t pid = fork();
            if (pid < 0) {
                close(pipefd[0]);
                close(pipefd[1]);
                throw matlab::engine::MATLABException("fork() failed");
            }

            if (pid == 0) {
                close(pipefd[0]);

                dup2(pipefd[1], STDOUT_FILENO);
                dup2(pipefd[1], STDERR_FILENO);
                close(pipefd[1]);

                execl("/bin/sh", "sh", "-c", cmdline.c_str(), static_cast<char*>(nullptr));
            }

            close(pipefd[1]);
            return std::make_shared<MATFrostServer>(pid, pipefd[0]);
#endif

        }

    };
}

#endif //MATFROST_JL_SERVER_HPP




