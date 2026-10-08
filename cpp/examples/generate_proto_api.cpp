#include "kcl_lib.hpp"
#include <iostream>
#include <string>

int main()
{
    auto args = kcl_lib::GenerateProtoArgs {};
    args.parse_args.has_value = true;
    args.parse_args.value.paths = { "../test_data/schema.k" };
    // An empty package omits the `package` clause entirely.
    args.package = "example.v1";
    auto result = kcl_lib::generate_proto(args);
    std::cout << result.proto.c_str() << std::endl;

    const std::string proto(result.proto.data(), result.proto.size());
    if (proto.find("syntax = \"proto3\";") == std::string::npos || proto.find("package example.v1;") == std::string::npos) {
        std::cout << "Expected a proto3 document with the example.v1 package" << std::endl;
        return 1;
    }
    // As in the OpenAPI document, the schema name carries its module.
    if (proto.find("message AppConfig") == std::string::npos) {
        std::cout << "Expected the AppConfig message in the proto output" << std::endl;
        return 1;
    }
    return 0;
}