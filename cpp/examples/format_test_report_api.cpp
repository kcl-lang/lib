// The linked KCL runtime has to implement KclService.FormatTestReport for the
// report below to be non-empty; the kcl-api revision pinned in Cargo.lock does
// not yet, so this currently prints nothing.
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::FormatTestReportArgs {};
    args.result.has_value = true;
    args.result.value.info = { {
        .name = "test_case_1",
        .duration = 1500,
    }, {
        .name = "test_case_2",
        .error = "Error: assert failed",
        .duration = 2500,
    } };
    auto result = kcl_lib::format_test_report(args);
    std::cout << result.report.c_str();
    return 0;
}
