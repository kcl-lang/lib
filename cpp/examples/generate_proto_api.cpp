#include "kcl_lib.hpp"
#include <iostream>

// The linked KCL runtime has to implement KclService.GenerateProto for the
// definitions below to be non-empty; the kcl-api revision pinned in Cargo.lock
// does not yet, so this currently prints nothing.
int main()
{
    auto args = kcl_lib::GenerateProtoArgs {};
    args.parse_args.has_value = true;
    args.parse_args.value.paths = { "../test_data/schema.k" };
    // An empty package omits the `package` clause entirely.
    args.package = "example.v1";
    auto result = kcl_lib::generate_proto(args);
    std::cout << result.proto.c_str() << std::endl;
    return 0;
}
