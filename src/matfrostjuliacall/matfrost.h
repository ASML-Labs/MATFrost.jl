//
// Created by jbelier on 24/08/2024.
//

#ifndef MATFROST_H
#define MATFROST_H


#include <cstdint>

/**
 * MATFrostArray is a type used to represent MATLAB style nested objects and arrays consisting of :
 * 1. Primitive type arrays: f64, cf64, i32, ...
 * 2. String arrays
 * 3. Cell arrays
 * 4. Struct Arrays
 *
 * This type is used as the communication primitive between MATLAB and Julia.
 */
struct MATFrostArray {
    int32_t        type;
    size_t         ndims;
    size_t*        dims;
    const void*    data;
    size_t         nfields;
    const char**   fieldnames;
};

struct MATFrostOutputUnwrap {
    uint8_t       exception;
    MATFrostArray value;
};

__declspec(dllimport) void jl_init();
__declspec(dllimport) void* jl_eval_string(const char *str);
__declspec(dllimport) void* jl_unbox_voidpointer(void* v) ;



#endif //MATFROST_H
