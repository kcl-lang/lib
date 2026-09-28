#include <kcl_lib.h>

int main()
{
    static char changed[BUFFER_SIZE] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };

    const struct KclStringPair sources[] = {
        { "/mock/path/main.k", "a = 1\nb = a\n" },
    };
    if (!kcl_rename_code("/mock/path", "a", sources, 1, "a2",
            changed, sizeof(changed), err, sizeof(err))) {
        printf("RenameCode failed: %s\n", err);
        return 1;
    }

    printf("Changed codes: %s\n", changed);
    return 0;
}
