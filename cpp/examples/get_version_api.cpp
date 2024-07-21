#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto result = kcl_lib::get_version();
    std::cout << result.checksum.c_str() << std::endl;
    std::cout << result.git_sha.c_str() << std::endl;
    std::cout << result.version.c_str() << std::endl;
    std::cout << result.version_info.c_str() << std::endl;
    return 0;
}
