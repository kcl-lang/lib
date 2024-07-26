#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ExecProgramArgs {
        .k_filename_list = { "../test_data/schema.k" },
    };
    auto result = kcl_lib::exec_program(args);
    std::cout << result.yaml_result.c_str() << std::endl;
    return 0;
}
