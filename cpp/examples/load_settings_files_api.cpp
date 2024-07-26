#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::LoadSettingsFilesArgs {
        .work_dir = "../test_data/settings",
        .files = { "../test_data/settings/kcl.yaml" },
    };
    auto result = kcl_lib::load_settings_files(args);
    std::cout << result.kcl_cli_configs.value.files.size() << std::endl;
    std::cout << result.kcl_cli_configs.value.strict_range_check << std::endl;
    std::cout << result.kcl_options[0].key.c_str() << std::endl;
    std::cout << result.kcl_options[0].value.c_str() << std::endl;
    return 0;
}
