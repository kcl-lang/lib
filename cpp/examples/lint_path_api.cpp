#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::LintPathArgs {
        .paths = { "../test_data/lint_path/test-lint.k" }
    };
    auto result = kcl_lib::lint_path(args);
    std::cout << result.results[0].c_str() << std::endl;
    return 0;
}
