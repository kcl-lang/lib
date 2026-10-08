#include "kcl_lib.hpp"
#include <iostream>
#include <string>

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

    const std::string content(result.content.data(), result.content.size());
    if (content.find("### AppConfig") == std::string::npos) {
        std::cout << "Expected a Markdown document with an AppConfig section" << std::endl;
        return 1;
    }
    if (content.find("| replicas | int | yes |") == std::string::npos) {
        std::cout << "Expected a Markdown table row for the required replicas attribute" << std::endl;
        return 1;
    }
    return 0;
}