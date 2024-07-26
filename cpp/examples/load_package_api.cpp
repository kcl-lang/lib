#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto parse_args = kcl_lib::ParseProgramArgs {
        .paths = { "../test_data/schema.k" },
    };
    auto args = kcl_lib::LoadPackageArgs {
        .resolve_ast = true,
    };
    args.parse_args = kcl_lib::OptionalParseProgramArgs {
        .has_value = true,
        .value = parse_args,
    };
    auto result = kcl_lib::load_package(args);
    std::cout << result.symbols[0].value.ty.value.c_str() << std::endl;
    return 0;
}
