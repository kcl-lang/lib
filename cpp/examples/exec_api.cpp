#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ExecProgramArgs();
    auto files = rust::Vec<rust::String>();
    files.push_back(rust::String("../test_data/schema.k"));
    args.k_filename_list = files;
    auto result = kcl_lib::exec_program(args);
    std::cout << result.yaml_result.c_str() << std::endl;
    return 0;
}
