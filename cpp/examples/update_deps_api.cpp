#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::UpdateDependenciesArgs {
        .manifest_path = rust::String("../test_data/update_dependencies"),
    };
    auto result = kcl_lib::update_dependencies(args);
    std::cout << result.external_pkgs[0].pkg_name.c_str() << std::endl;
    std::cout << result.external_pkgs[1].pkg_name.c_str() << std::endl;
    return 0;
}
