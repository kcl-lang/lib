#include "kcl_lib.hpp"
#include <iostream>

// The linked KCL runtime has to implement KclService.GenerateToml for the
// document below to be non-empty; the kcl-api revision pinned in Cargo.lock
// does not yet, so this currently prints nothing.
int main()
{
    auto args = kcl_lib::GenerateTomlArgs {};
    args.exec_args.has_value = true;
    args.exec_args.value.k_code_list = { "app = {name = \"demo\", ports = [80, 443]}" };
    // Serialize in source order rather than sorting keys alphabetically.
    args.sort_keys = false;
    auto result = kcl_lib::generate_toml(args);
    std::cout << result.toml.c_str() << std::endl;
    return 0;
}
