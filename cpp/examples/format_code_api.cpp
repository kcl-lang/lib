#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::FormatCodeArgs {
        .source = "schema Person:\n"
                  "    name:     str\n"
                  "    age:     int\n"
                  "    check:\n"
                  "        0 <     age <     120\n",
    };
    auto result = kcl_lib::format_code(args);
    std::cout << result.formatted.c_str() << std::endl;
    return 0;
}
