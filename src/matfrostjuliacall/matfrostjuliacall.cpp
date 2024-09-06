#include "mex.hpp"
#include "mexAdapter.hpp"

#include <tuple>
// stdc++ lib
#include <string>

// External dependencies
// using namespace matlab::data;
using matlab::mex::ArgumentList;
#include <thread>
#include <condition_variable>
#include <mutex>

#include <complex>

#include <chrono>
#include "converttojulia.hpp"
#include "converttomatlab.hpp"

extern "C" {
    #include "matfrost.h"
}



class MexFunction : public matlab::mex::Function {
private:
    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr;
    ArgumentList* outputs_p;
    ArgumentList* inputs_p;
    std::thread juliaworkerthread;
    
    std::mutex mtx_mex;

    std::mutex mtx_jl;
    std::condition_variable cv_jl;

    
    bool                          exception_triggered = false;
    matlab::engine::MATLABException exception_matlab;

    MATFrostArray (*juliacall)(MATFrostArray) = nullptr;
    void (*freematfrostmemory)(MATFrostArray) = nullptr;
    // std::string julia_environment_path;


public:
    MexFunction() {
        matlabPtr = getEngine(); 

        std::unique_lock<std::mutex> lk(mtx_jl);

        // Start Julia worker and initialize Julia.
        juliaworkerthread = std::thread(&MexFunction::juliaworker, this);
        
        // wait for Julia init to finish.
        cv_jl.wait(lk);

    }

    virtual ~MexFunction(){
        
        matlab::data::ArrayFactory factory;

        matlabPtr->feval(u"fprintf", 0, std::vector<matlab::data::Array>
            ({ factory.createScalar("Closing MEX function")}));
    }

    void operator()(ArgumentList outputs, ArgumentList inputs) {
        
        // lk_mex will sequentialize Julia jobs in case of concurrent MEX-calls.
        std::lock_guard<std::mutex> lk_mex(mtx_mex);
        {
            std::unique_lock<std::mutex> lk(mtx_jl);
            inputs_p = &inputs;
            outputs_p = &outputs;

            // Start Julia worker Job
            cv_jl.notify_one();
            cv_jl.wait(lk);


            if (exception_triggered){ 
                exception_triggered = false;
                throw exception_matlab;
            } 
        }
        
    }

    int juliaworker(){
        std::unique_lock<std::mutex> lk(mtx_jl);
        jl_init();

        void* matf                 = jl_eval_string("using MATFrost: MATFrost");
        void* juliacall_c          = jl_eval_string("MATFrost.MEX.juliacall_c()");
        void* freematfrostmemory_c = jl_eval_string("MATFrost.MEX.freematfrostmemory_c()");

        if (matf != nullptr && juliacall_c != nullptr && freematfrostmemory_c != nullptr) {
            juliacall          = (MATFrostArray (*)(MATFrostArray))  jl_unbox_voidpointer(juliacall_c);
            freematfrostmemory = (void (*)(MATFrostArray))           jl_unbox_voidpointer(freematfrostmemory_c);
        }

        while(true){
            cv_jl.notify_one();
            cv_jl.wait(lk);

            juliaworkerjob();
        }
        
        return 0;
    }


    int juliaworkerjob() {
        if (juliacall == nullptr || freematfrostmemory == nullptr) {
            exception_triggered = true;
            exception_matlab = matlab::engine::MATLABException(
                "matfrostjulia:MATFrostPackageMissingInEnvironment",
                u"Configurd Julia environment cannot load required MATFrost package. Either Julia environment is missing MATFrost dependency or environment has not been properly instantiated.");
            return 0;
        }
        try
        {
            ArgumentList& outputs = *outputs_p;
            ArgumentList& inputs = *inputs_p;
            matlab::data::ArrayFactory factory;

            const matlab::data::StructArray sarr = inputs[0];
            const matlab::data::StringArray parr  = sarr[0]["package"];
            std::string pack = matlab::engine::convertUTF16StringToUTF8String(parr[0]);
            jl_eval_string(("import " + pack).c_str());

            // During testing it occurred that function pointers became dangling. This issue occurred on Julia 1.8.
            // Likely this is happening due to package import statement one line above. For safety we retrieve the
            // pointer for every call.
            juliacall          = (MATFrostArray (*)(MATFrostArray)) jl_unbox_voidpointer(jl_eval_string("MATFrost.MEX.juliacall_c()"));
            freematfrostmemory = (void (*)(MATFrostArray))          jl_unbox_voidpointer(jl_eval_string("MATFrost.MEX.freematfrostmemory_c()"));

            auto mfa = MATFrost::ConvertToJulia::convert(inputs[0]);

            MATFrostArray   jlo = juliacall(mfa->matfrostarray);

            const matlab::data::StructArray mato = MATFrost::ConvertToMATLAB::convert(jlo);

            freematfrostmemory(jlo);

            const matlab::data::TypedArray<bool> exception_b = mato[0]["exception"];
            if (exception_b[0]) {
                const matlab::data::StructArray matso = mato[0]["value"];
                const matlab::data::StringArray exception_id = matso[0]["id"];
                const matlab::data::StringArray exception_message = matso[0]["message"];
                throw matlab::engine::MATLABException(exception_id[0], exception_message[0]);
            }

            outputs[0] = mato[0]["value"];

        }
        catch(const matlab::engine::MATLABException& ex)
        {
            exception_matlab = ex;
            exception_triggered = true;
        }
        catch(std::exception& ex)
        {
            matlab::data::ArrayFactory factory;
            matlabPtr->feval(u"disp", 0, std::vector<matlab::data::Array>
                ({ factory.createScalar("###################################\nMATFrost error: " + std::string(ex.what()) + "\n###################################\n")}));
        }
        return 0; 
    }


    


};

// class