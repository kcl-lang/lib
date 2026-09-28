#include <kcl_lib.h>

int main()
{
    static struct KclTestCaseInfo info[32] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };
    size_t count = 0;

    const char* pkgs[] = { "./test_data/testing/..." };
    if (!kcl_test("./test_data/testing", NULL, 0, pkgs, 1, NULL, false,
            info, 32, &count, err, sizeof(err))) {
        printf("Test failed: %s\n", err);
        return 1;
    }

    printf("Test cases (%zu):\n", count);
    for (size_t i = 0; i < count; ++i) {
        printf("  name=%s duration=%llu error=%s log=%s\n",
            info[i].name, (unsigned long long)info[i].duration,
            info[i].error, info[i].log_message);
    }
    return 0;
}
