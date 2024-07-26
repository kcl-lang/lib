#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::OverrideFileArgs {
        .file = { "../test_data/override_file/main.k" },
        .specs = { "b.a=2" },
    };
    auto result = kcl_lib::override_file(args);
    std::cout << result.result << std::endl;
    std::cout << result.parse_errors.size() << std::endl;
    return 0;
}
