#include <kcl_lib.h>

int main()
{
    static char errors[4096] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };
    static char content[4096] = { 0 };
    bool overridden = false;
    const char* path = "./test_data/override_api_tmp.k";
    const char* source = "alice = {\n    age = 18\n    name = \"Alice\"\n}\n";

    FILE* fp = fopen(path, "w");
    if (fp == NULL) {
        printf("Cannot create %s\n", path);
        return 1;
    }
    fputs(source, fp);
    fclose(fp);

    const char* specs[] = { "alice.age=42" };
    if (!kcl_override_file(path, specs, 1, NULL, 0,
            &overridden, errors, sizeof(errors), err, sizeof(err))) {
        printf("OverrideFile failed: %s\n", err);
        remove(path);
        return 1;
    }

    fp = fopen(path, "r");
    if (fp != NULL) {
        size_t n = fread(content, 1, sizeof(content) - 1, fp);
        content[n] = '\0';
        fclose(fp);
    }

    printf("Overridden: %d\n", overridden);
    printf("Parse errors: %s\n", errors);
    printf("File content after override:\n%s", content);
    remove(path);
    return 0;
}
