#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ListVariablesArgs {
        .files = rust::Vec({ rust::String("../test_data/schema.k") }),
    };
    auto result = kcl_lib::list_variables(args);
    std::cout << result.variables[0].value[0].value.c_str() << std::endl;
    return 0;
}
