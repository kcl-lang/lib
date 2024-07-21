#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::RenameArgs {
        .package_root = "../test_data/rename",
        .symbol_path = "a",
        .file_paths = { "../test_data/rename/main.k" },
        .new_name = "a",
    };
    auto result = kcl_lib::rename(args);
    std::cout << result.changed_files[0].c_str() << std::endl;
    return 0;
}