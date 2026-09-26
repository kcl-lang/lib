#include "kcl_lib.hpp"
#include <iostream>
#include <string>

int main()
{
    auto exec_args = kcl_lib::ExecProgramArgs {
        .k_filename_list = { "../test_data/schema_function_type.k" },
    };
    auto args = kcl_lib::GetSchemaTypeMappingArgs();
    args.exec_args = kcl_lib::OptionalExecProgramArgs {
        .has_value = true,
        .value = exec_args,
    };
    auto result = kcl_lib::get_schema_type_mapping(args);
    for (auto &entry : result.schema_type_mapping)
    {
        if (std::string(entry.key.c_str()) != "AppConfig")
        {
            continue;
        }
        for (auto &prop : entry.value.properties)
        {
            std::cout << prop.key.c_str() << ": " << prop.value.ty.c_str() << std::endl;
            if (prop.value.function.has_value)
            {
                auto &function = prop.value.function.value;
                std::cout << "  params: " << function.params.size() << std::endl;
                for (auto &param : function.params)
                {
                    std::cout << "    " << param.name.c_str() << ": " << param.ty.value.c_str() << std::endl;
                }
                std::cout << "  return: " << function.return_ty.value.c_str() << std::endl;
            }
            if (prop.value.index_signature.has_value)
            {
                auto &index_signature = prop.value.index_signature.value;
                std::cout << "  index signature key: " << index_signature.key.value.c_str() << std::endl;
                std::cout << "  index signature val: " << index_signature.val.value.c_str() << std::endl;
            }
        }
    }
    return 0;
}
