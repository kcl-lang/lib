#include <kcl_lib.h>

int main()
{
    static char content[BUFFER_SIZE] = { 0 };
    const char* paths[] = { "./test_data/schema.k" };
    struct KclParseProgramArgs request = {
        .paths = paths,
        .path_count = 1,
    };

    if (!kcl_generate_doc(&request, "md", content, sizeof(content))) {
        printf("GenerateDoc failed: %s\n", content);
        return 1;
    }

    printf("%s", content);
    if (strstr(content, "### AppConfig") == NULL) {
        printf("Expected a Markdown document with an AppConfig section\n");
        return 1;
    }
    return 0;
}
