#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ListDepFilesArgs{
        .work_dir = "../test_data",
        .use_abs_path = false,
        .include_all = true,
        .use_fast_parser = false,
    };
    auto result = kcl_lib::list_dep_files(args);
    std::cout << "pkgroot: " << result.pkgroot.c_str() << std::endl;
    std::cout << "pkgpath: " << result.pkgpath.c_str() << std::endl;
    for (const auto &f : result.files)
    {
        std::cout << f.c_str() << std::endl;
    }
    return 0;
}
