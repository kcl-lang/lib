#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::RenameCodeArgs {
        .package_root = "/mock/path",
        .symbol_path = "a",
        .source_codes = { {
            .key = "/mock/path/main.k",
            .value = "a = 1\nb = a\nc = a",
        } },
        .new_name = "a2",
    };
    auto result = kcl_lib::rename_code(args);
    std::cout << result.changed_codes[0].value.c_str() << std::endl;
    return 0;
}