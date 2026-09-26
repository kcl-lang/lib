#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::PingArgs{.value = "hello-kcl"};
    auto result = kcl_lib::ping(args);
    std::cout << result.value.c_str() << std::endl;
    return 0;
}
