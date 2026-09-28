#include <kcl_lib.h>

int main()
{
    static char changed[4096] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };
    static char content[4096] = { 0 };
    const char* src = "./test_data/rename/main.k";
    const char* tmp = "./test_data/rename/rename_api_tmp.k";

    FILE* fp = fopen(src, "r");
    if (fp == NULL) {
        printf("Missing fixture %s\n", src);
        return 1;
    }
    size_t n = fread(content, 1, sizeof(content) - 1, fp);
    content[n] = '\0';
    fclose(fp);

    fp = fopen(tmp, "w");
    if (fp == NULL) {
        printf("Cannot create %s\n", tmp);
        return 1;
    }
    fputs(content, fp);
    fclose(fp);

    const char* files[] = { tmp };
    if (!kcl_rename("./test_data/rename", "a", files, 1, "a2", changed, sizeof(changed), err, sizeof(err))) {
        printf("Rename failed: %s\n", err);
        remove(tmp);
        return 1;
    }

    memset(content, 0, sizeof(content));
    fp = fopen(tmp, "r");
    if (fp != NULL) {
        n = fread(content, 1, sizeof(content) - 1, fp);
        content[n] = '\0';
        fclose(fp);
    }

    printf("Changed files: %s\n", changed);
    printf("File content after rename:\n%s", content);
    remove(tmp);
    return 0;
}
