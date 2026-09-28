#include <kcl_lib.h>

int main()
{
    static struct KclOptionHelp options[16] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };
    size_t count = 0;

    const char* files[] = { "./test_data/options.k" };
    if (!kcl_list_options(files, 1, options, 16, &count, err, sizeof(err))) {
        printf("ListOptions failed: %s\n", err);
        return 1;
    }

    printf("Options (%zu):\n", count);
    for (size_t i = 0; i < count; ++i) {
        printf("  name=%s type=%s required=%d default=%s help=%s\n",
            options[i].name, options[i].type, options[i].required,
            options[i].default_value, options[i].help);
    }
    return 0;
}
