#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    // The local kcl.mod declares both deps as `path = "../_mocks/..."`, but
    // `update_dependencies` always returns `pkg_path = <manifest>/<dep_name>`
    // (it ignores the `path` directive), so we hand-build `external_pkgs`
    // pointing at the actual mock locations.
    auto exec_args = kcl_lib::ExecProgramArgs {
        .k_filename_list = { "../test_data/update_dependencies/main.k" },
        .external_pkgs = {
            kcl_lib::ExternalPkg {
                .pkg_name = "helloworld",
                .pkg_path = "../test_data/_mocks/helloworld",
            },
            kcl_lib::ExternalPkg {
                .pkg_name = "flask",
                .pkg_path = "../test_data/_mocks/flask",
            },
        },
    };
    auto exec_result = kcl_lib::exec_program(exec_args);
    std::cout << exec_result.yaml_result.c_str() << std::endl;
    return 0;
}
