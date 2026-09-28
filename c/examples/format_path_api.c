#include <kcl_lib.h>

int main()
{
    static char changed[4096] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };
    static char content[4096] = { 0 };
    const char* path = "./test_data/format_api_tmp.k";
    const char* source = "schema Person:\n    name:str\n    age:int=18\n";

    FILE* fp = fopen(path, "w");
    if (fp == NULL) {
        printf("Cannot create %s\n", path);
        return 1;
    }
    fputs(source, fp);
    fclose(fp);

    if (!kcl_format_path(path, false, changed, sizeof(changed), err, sizeof(err))) {
        printf("FormatPath failed: %s\n", err);
        remove(path);
        return 1;
    }

    fp = fopen(path, "r");
    if (fp != NULL) {
        size_t n = fread(content, 1, sizeof(content) - 1, fp);
        content[n] = '\0';
        fclose(fp);
    }

    printf("Changed paths: %s\n", changed);
    printf("File content after formatting:\n%s", content);
    remove(path);
    return 0;
}
