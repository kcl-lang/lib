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

    printf("%.400s\n", spec);
    // This fixture's schema comes back as `AppConfig___main__`: the core
    // qualifies a schema name with the module it was declared in. Match the
    // name without its closing quote so the check holds whether or not the
    // qualification is present.
    if (strstr(spec, "\"openapi\"") == NULL || strstr(spec, "\"AppConfig") == NULL) {
        printf("Expected an OpenAPI 3 document carrying the AppConfig schema\n");
        return 1;
    }
    return 0;
}
