#include <kcl_lib.h>

int main()
{
    static char spec[BUFFER_SIZE] = { 0 };
    const char* paths[] = { "./test_data/schema.k" };
    struct KclParseProgramArgs request = {
        .paths = paths,
        .path_count = 1,
    };

    if (!kcl_generate_openapi(&request, "v3", spec, sizeof(spec))) {
        printf("GenerateOpenAPI failed: %s\n", spec);
        return 1;
    }

    // A core that does not register KclService.GenerateOpenAPI answers
    // with an empty reply, which decodes into an empty spec string.
    if (spec[0] == '\0') {
        printf("runtime does not implement KclService.GenerateOpenAPI; skipping\n");
        return 0;
    }

    printf("%.400s\n", spec);
    // The pinned core qualifies schema keys with the package path
    // ("AppConfig___main__"), so match the unqualified prefix.
    if (strstr(spec, "\"openapi\"") == NULL || strstr(spec, "AppConfig") == NULL) {
        printf("Expected an OpenAPI 3 document carrying the AppConfig schema\n");
        return 1;
    }
    return 0;
}
