#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto result = kcl_lib::list_method();
    for (auto &name : result.method_name_list)
    {
        std::cout << name.c_str() << std::endl;
    }
    return 0;
}
