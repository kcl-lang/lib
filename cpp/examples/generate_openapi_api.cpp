#include "kcl_lib.hpp"
#include <iostream>

// The linked KCL runtime has to implement KclService.GenerateOpenAPI for the
// spec below to be non-empty; the kcl-api revision pinned in Cargo.lock does
// not yet, so this currently prints nothing.
int main()
{
    auto args = kcl_lib::GenerateOpenAPIArgs {};
    args.parse_args.has_value = true;
    args.parse_args.value.paths = { "../test_data/schema.k" };
    // "v3" is the default; "v2" emits a Swagger 2.0 document instead.
    args.version = "v3";
    auto result = kcl_lib::generate_openapi(args);
    std::cout << result.spec.c_str() << std::endl;
    return 0;
}
