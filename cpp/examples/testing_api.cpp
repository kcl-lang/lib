#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::TestArgs {
        .pkg_list = { "../test_data/testing/..." },
    };
    auto result = kcl_lib::test(args);
    std::cout << result.info[0].name.c_str() << std::endl;
    return 0;
}