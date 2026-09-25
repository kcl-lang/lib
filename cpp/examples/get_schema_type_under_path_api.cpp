#include "kcl_lib.hpp"
#include <filesystem>
#include <iostream>

int main()
{
    // The runtime resolves package paths against the working directory, so
    // absolute paths are required (see kcl-lang/kcl#1546).
    auto root = std::filesystem::canonical(std::filesystem::current_path() / ".." / "test_data" / "get_schema_ty_under_path");
    auto exec_args = kcl_lib::ExecProgramArgs{
        .k_filename_list = {(root / "aaa").string()},
        .external_pkgs = {kcl_lib::ExternalPkg{
            .pkg_name = "bbb",
            .pkg_path = (root / "bbb").string(),
        }},
    };
    auto args = kcl_lib::GetSchemaTypeMappingArgs{
        .exec_args = kcl_lib::OptionalExecProgramArgs{
            .has_value = true,
            .value = exec_args,
        },
        .schema_name = "",
    };
    auto result = kcl_lib::get_schema_type_mapping_under_path(args);
    for (auto &entry : result.schema_type_mapping)
    {
        std::cout << "package: " << entry.key.c_str() << std::endl;
        for (auto &schema : entry.value.schema_type)
        {
            std::cout << "  schema: " << schema.schema_name.c_str() << std::endl;
        }
    }
    return 0;
}
