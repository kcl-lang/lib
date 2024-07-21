#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto exec_args = kcl_lib::ExecProgramArgs {
        .k_filename_list = rust::Vec({ rust::String("../test_data/schema.k") }),
    };
    auto args = kcl_lib::GetSchemaTypeMappingArgs();
    args.exec_args = kcl_lib::OptionalExecProgramArgs {
        .has_value = true,
        .value = exec_args,
    };
    auto result = kcl_lib::get_schema_type_mapping(args);
    std::cout << result.schema_type_mapping[0].key.c_str() << std::endl;
    std::cout << result.schema_type_mapping[0].value.properties[0].key.c_str() << std::endl;
    std::cout << result.schema_type_mapping[0].value.properties[0].value.ty.c_str() << std::endl;
    return 0;
}
