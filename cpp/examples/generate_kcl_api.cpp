#include "kcl_lib.hpp"
#include <iostream>
#include <string>

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

    // A JSON null becomes `None`, a nested object becomes a dict literal, and
    // the key order follows the document rather than being sorted.
    const std::string expected = "a = {\n"
                                 "    b = 1\n"
                                 "}\n"
                                 "c = [1, 2.5, true, None]\n";
    const std::string kcl(result.kcl.data(), result.kcl.size());
    if (kcl != expected) {
        std::cout << "Expected:\n" << expected << "got:\n" << kcl << std::endl;
        return 1;
    }
    return 0;
}