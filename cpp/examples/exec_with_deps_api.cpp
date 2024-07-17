#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::UpdateDependenciesArgs {
        .manifest_path = rust::String("../test_data/update_dependencies"),
    };
    auto result = kcl_lib::update_dependencies(args);
    auto exec_args = kcl_lib::ExecProgramArgs {
        .k_filename_list = rust::Vec({ rust::String("../test_data/update_dependencies/main.k") }),
        .external_pkgs = result.external_pkgs,
    };
    auto exec_result = kcl_lib::exec_program(exec_args);
    std::cout << exec_result.yaml_result.c_str() << std::endl;
    return 0;
}
