#include "kcl_lib.hpp"
#include <iostream>
#include <string>

int main()
{
    auto args = kcl_lib::GenerateTomlArgs {};
    args.exec_args.has_value = true;
    args.exec_args.value.k_code_list = { "app = {name = \"demo\", ports = [80, 443]}" };
    // Serialize in source order rather than sorting keys alphabetically.
    args.sort_keys = false;
    auto result = kcl_lib::generate_toml(args);
    std::cout << result.toml.c_str() << std::endl;

    const std::string toml(result.toml.data(), result.toml.size());
    // An empty `package` omits the `package` clause, so a bare `[app]` table
    // heading is the only marker of where the document starts.
    if (toml.find("[app]") == std::string::npos) {
        std::cout << "Expected an [app] table in the TOML output: " << toml << std::endl;
        return 1;
    }
    if (toml.find("name = \"demo\"") == std::string::npos) {
        std::cout << "Expected the app name in the TOML output: " << toml << std::endl;
        return 1;
    }
    return 0;
}