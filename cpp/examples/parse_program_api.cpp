#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ParseProgramArgs {
        .paths = { "../test_data/schema.k" },
    };
    auto result = kcl_lib::parse_program(args);
    std::cout << result.paths[0].c_str() << std::endl;
    std::cout << result.errors.size() << std::endl;
    std::cout << result.ast_json.c_str() << std::endl;
    return 0;
}
