#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::GetSchemaTypeMappingArgs{
        .exec_args = kcl_lib::OptionalExecProgramArgs{},
        .schema_name = "",
    };
    auto result = kcl_lib::get_schema_type_mapping_under_path(args);
    for (const auto &entry : result.schema_type_mapping)
    {
        std::cout << "package: " << entry.key.c_str() << std::endl;
        for (const auto &schema : entry.value.schema_type)
        {
            std::cout << "  schema: " << schema.schema_name.c_str() << std::endl;
        }
    }
    return 0;
}
