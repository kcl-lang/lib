#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ParseProgramArgs {
        .paths = rust::Vec({ rust::String("../test_data/option/main.k") }),
    };
    auto result = kcl_lib::list_options(args);
    std::cout << result.options[0].name.c_str() << std::endl;
    std::cout << result.options[1].name.c_str() << std::endl;
    std::cout << result.options[2].name.c_str() << std::endl;
    return 0;
}
