#include "kcl_lib.hpp"
#include <iostream>

// The linked KCL runtime has to implement KclService.GenerateDoc for the
// documentation below to be non-empty; the kcl-api revision pinned in
// Cargo.lock does not yet, so this currently prints nothing.
int main()
{
    auto args = kcl_lib::GenerateDocArgs {};
    args.parse_args.has_value = true;
    args.parse_args.value.paths = { "../test_data/schema.k" };
    // "md" is the default; "openapi" and "json-schema" are also accepted.
    // "html" is not supported yet.
    args.format = "md";
    auto result = kcl_lib::generate_doc(args);
    std::cout << result.content.c_str() << std::endl;
    return 0;
}
