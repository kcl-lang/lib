#include <kcl_lib.h>

static int check_format(const char* label, const char* source, const char* filename, const char* format, const char* expected)
{
    static char kcl[BUFFER_SIZE] = { 0 };
    kcl[0] = '\0';

    if (!kcl_generate_kcl(source, filename, format, kcl, sizeof(kcl))) {
        printf("GenerateKcl(%s) failed: %s\n", label, kcl);
        return 1;
    }

    printf("--- %s ---\n%s", label, kcl);
    if (strcmp(kcl, expected) != 0) {
        printf("GenerateKcl(%s) expected:\n%s\ngot:\n%s\n", label, expected, kcl);
        return 1;
    }
    return 0;
}

int main()
{
    int status = 0;
    // Format is left empty so the runtime infers it from the extension.
    status |= check_format("json", "{\"a\": {\"b\": 1}, \"c\": [1, 2.5, true, null], \"d-e\": \"x\"}",
        "data.json", "",
        "a = {\n    b = 1\n}\nc = [1, 2.5, true, None]\n\"d-e\" = \"x\"\n");
    status |= check_format("yaml", "a: 1\nb:\n  - x\n  - y\n",
        "data.yaml", "",
        "a = 1\nb = [\"x\", \"y\"]\n");
    return status;
}
