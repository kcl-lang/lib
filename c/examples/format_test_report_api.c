#include <kcl_lib.h>

int main()
{
    static struct KclTestCaseInfo info[32] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };
    static char report[BUFFER_SIZE] = { 0 };
    size_t count = 0;

    const char* pkgs[] = { "./test_data/testing_report/..." };
    if (!kcl_test("./test_data/testing_report", NULL, 0, pkgs, 1, NULL, false,
            info, 32, &count, err, sizeof(err))) {
        printf("Test failed: %s\n", err);
        return 1;
    }
    if (count != 2) {
        printf("Expected 2 test cases, got %zu\n", count);
        return 1;
    }

    if (!kcl_format_test_report(info, count, report, sizeof(report))) {
        printf("FormatTestReport failed: %s\n", report);
        return 1;
    }
    printf("%s", report);

    // Every line of a report ends with "\n", so a real report is never
    // empty. Assert the shape instead of trusting the wrapper's return
    // value: a runtime that does not register KclService.FormatTestReport
    // makes kcl_call return an empty reply, which decodes into an empty
    // report rather than an error.
    size_t len = strlen(report);
    if (len == 0 || report[len - 1] != '\n') {
        printf("FormatTestReport did not return a newline-terminated report: %s\n", report);
        return 1;
    }
    if (strstr(report, "\nPASS: 2/2\n") == NULL) {
        printf("FormatTestReport report is missing the PASS summary: %s\n", report);
        return 1;
    }

    // An empty result (no cases) renders the fixed "no test files" line.
    static char empty_report[BUFFER_SIZE] = { 0 };
    if (!kcl_format_test_report(NULL, 0, empty_report, sizeof(empty_report))) {
        printf("FormatTestReport failed: %s\n", empty_report);
        return 1;
    }
    if (strcmp(empty_report, "no test files\n") != 0) {
        printf("Expected \"no test files\\n\", got: %s\n", empty_report);
        return 1;
    }
    return 0;
}
