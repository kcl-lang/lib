#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ParseFileArgs {
        .path = "../test_data/schema.k",
    };
    auto result = kcl_lib::parse_file(args);
    std::cout << result.deps.size() << std::endl;
    std::cout << result.errors.size() << std::endl;
    std::cout << result.ast_json.c_str() << std::endl;
    return 0;
}
