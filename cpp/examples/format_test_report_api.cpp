#include "kcl_lib.hpp"
#include <iostream>
#include <string>

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

    // One line per case, the error text of a failed case on the line after it,
    // an 80-dash separator, then the per-status counts.
    const std::string expected = "test_case_1: PASS (1ms)\n"
                                 "test_case_2: FAIL (2ms)\n"
                                 "Error: assert failed\n"
                                 + std::string(80, '-') + "\n"
                                 "PASS: 1/2\n"
                                 "FAIL: 1/2\n";
    const std::string report(result.report.data(), result.report.size());
    if (report != expected) {
        std::cout << "Expected a report of:\n" << expected << "got:\n" << report << std::endl;
        return 1;
    }
    return 0;
}