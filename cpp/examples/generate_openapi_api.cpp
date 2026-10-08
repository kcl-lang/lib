#include "kcl_lib.hpp"
#include <iostream>
#include <string>

int main()
{
    auto args = kcl_lib::GenerateOpenAPIArgs {};
    args.parse_args.has_value = true;
    args.parse_args.value.paths = { "../test_data/schema.k" };
    // "v3" is the default; "v2" emits a Swagger 2.0 document instead.
    args.version = "v3";
    auto result = kcl_lib::generate_openapi(args);
    std::cout << result.spec.c_str() << std::endl;

    const std::string spec(result.spec.data(), result.spec.size());
    if (spec.find("\"openapi\"") == std::string::npos) {
        std::cout << "Expected an OpenAPI document with an `openapi` version field" << std::endl;
        return 1;
    }
    // This fixture's schema comes back as `AppConfig___main__`: the core
    // qualifies a schema name with the module it was declared in. Match the
    // name without its closing quote so the check holds whether or not the
    // qualification is present.
    if (spec.find("\"AppConfig") == std::string::npos) {
        std::cout << "Expected an OpenAPI 3 document carrying the AppConfig schema" << std::endl;
        return 1;
    }
    return 0;
}