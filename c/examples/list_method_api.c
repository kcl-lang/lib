#include <kcl_lib.h>

int main()
{
    static char methods[BUFFER_SIZE] = { 0 };
    if (!kcl_list_method(methods, sizeof(methods))) {
        printf("ListMethod failed: %s\n", methods);
        return 1;
    }

    int count = 0;
    const char* cursor = methods;
    printf("Available methods:\n");
    while (*cursor != '\0') {
        const char* newline = strchr(cursor, '\n');
        size_t len = newline != NULL ? (size_t)(newline - cursor) : strlen(cursor);
        printf("  %.*s\n", (int)len, cursor);
        count++;
        if (newline == NULL)
            break;
        cursor = newline + 1;
    }
    printf("Total: %d methods\n", count);
    return 0;
}
