#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::FormatPathArgs {
        .path = "../test_data/format_path/test.k",
    };
    auto result = kcl_lib::format_path(args);
    std::cout << result.changed_paths.size() << std::endl;
    return 0;
}
