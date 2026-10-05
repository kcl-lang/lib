#include "kcl_lib.hpp"
#include <iostream>

// The linked KCL runtime has to implement KclService.GenerateKcl for the
// source below to be non-empty; the kcl-api revision pinned in Cargo.lock does
// not yet, so this currently prints nothing.
int main()
{
    auto args = kcl_lib::GenerateKclArgs {
        .source = R"({"a": {"b": 1}, "c": [1, 2.5, true, null]})",
        .filename = "data.json",
        // Empty means "infer from the filename extension", which is "json"
        // here. Pass "yaml" or "toml" to be explicit.
        .format = "",
    };
    auto result = kcl_lib::generate_kcl(args);
    std::cout << result.kcl.c_str() << std::endl;
    return 0;
}
