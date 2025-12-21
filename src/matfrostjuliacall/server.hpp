/**
 * This file is responsible of managing the Julia process and offer a communication interface over pipes with the Julia
 * process. This class is free of MATLAB dependencies
 */
#include <cstdint>
#include <windows.h>
#include <tchar.h>
#include <cstdio>
#include <strsafe.h>



#include <memory>

#include <string>
#include <iostream>
#include <array>

namespace MATFrost {

    class MATFrostServer {

    public:

        PROCESS_INFORMATION process_information;
        HANDLE h_stdouterr;

        MATFrostServer(PROCESS_INFORMATION process_information, HANDLE h_stdouterr) :
            process_information(process_information), h_stdouterr(h_stdouterr)
        {

        }


        ~MATFrostServer() {
            // Close handles to the child process and its primary thread.
            // Some applications might keep these handles to monitor the status
            // of the child process, for example.
            TerminateProcess(process_information.hProcess, 0);

            WaitForSingleObject(process_information.hProcess, 500);

            CloseHandle(process_information.hProcess);
            CloseHandle(process_information.hThread);
            CloseHandle(h_stdouterr);

            // Close handles to the stdin and stdout pipes no longer needed by the child process.
            // If they are not explicitly closed, there is no way to recognize that the child process has ended.
            //

        }

        bool is_alive() {
            DWORD exit_code;
            GetExitCodeProcess(process_information.hProcess, &exit_code);
            return exit_code == STILL_ACTIVE;
        }


        static DWORD bytes_available(HANDLE handle) {
            DWORD bytes_available = 0;
            BOOL result = PeekNamedPipe(handle, nullptr, 0, nullptr, &bytes_available, nullptr);
            if (result != 0) {
                return bytes_available;
            } else {
                return -1;
            }
        }

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



        void dump_logging(std::shared_ptr<matlab::engine::MATLABEngine> matlab) {

            if (bytes_available(h_stdouterr) > 0) {

                matlab::data::ArrayFactory factory;
                std::u16string logging = matlab::engine::convertUTF8StringToUTF16String(read_string(h_stdouterr));
                if (logging.size() == 0) {
                    return;
                }
                matlab->feval(u"disp", 0, std::vector<matlab::data::Array>
                  ({factory.createScalar(logging)}));
                // return read_string(h_stdouterr);
            }

        }

        static std::shared_ptr<MATFrostServer> spawn(const std::string cmdline) {

            SECURITY_ATTRIBUTES saAttr;

            saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
            saAttr.bInheritHandle = TRUE;
            saAttr.lpSecurityDescriptor = NULL;

            std::string cmdline_pipes = cmdline;

            PROCESS_INFORMATION piProcInfo;
            STARTUPINFO siStartInfo;
            ZeroMemory( &piProcInfo, sizeof(PROCESS_INFORMATION) );
            ZeroMemory( &siStartInfo, sizeof(STARTUPINFO) );

            // Set up members of the PROCESS_INFORMATION structure.

            // HANDLE h_stdin[2];
            HANDLE h_stdouterr[2];
            if (!CreatePipe(&h_stdouterr[0], &h_stdouterr[1], &saAttr, 0)) {
                throw matlab::engine::MATLABException("CreatePipe failed");
            }
            SetHandleInformation(h_stdouterr[0], HANDLE_FLAG_INHERIT, 0);




            siStartInfo.cb = sizeof(STARTUPINFO);
            // siStartInfo.hStdInput = h_stdin[0];
            siStartInfo.hStdOutput = h_stdouterr[1];
            siStartInfo.hStdError  = h_stdouterr[1];
            siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

            // Create the child process.

            if (!CreateProcessA(
              nullptr,
              &cmdline_pipes[0],   // command line
              nullptr,       // process security attributes
              nullptr,       // primary thread security attributes
              TRUE,          // handles are inherited
              CREATE_NO_WINDOW,             // creation flags
              nullptr,       // use parent's environment
              nullptr,       // use parent's current directory
              &siStartInfo,  // STARTUPINFO pointer
              &piProcInfo)  // receives PROCESS_INFORMATION
            ) {
                throw matlab::engine::MATLABException("Julia process could not be started. With cmdline: " + cmdline);
            }

            CloseHandle(h_stdouterr[1]);

            return std::make_shared<MATFrostServer>(piProcInfo, h_stdouterr[0]);


        }

    };
}





