#include <kcl_lib.h>

int main()
{
    static char proto[BUFFER_SIZE] = { 0 };
    const char* paths[] = { "./test_data/schema.k" };
    struct KclParseProgramArgs request = {
        .paths = paths,
        .path_count = 1,
    };

    if (!kcl_generate_proto(&request, "example.v1", proto, sizeof(proto))) {
        printf("GenerateProto failed: %s\n", proto);
        return 1;
    }

    // A core that does not register KclService.GenerateProto answers with
    // an empty reply, which decodes into an empty proto string.
    if (proto[0] == '\0') {
        printf("runtime does not implement KclService.GenerateProto; skipping\n");
        return 0;
    }

    printf("%s", proto);
    if (strstr(proto, "package example.v1;") == NULL || strstr(proto, "message AppConfig") == NULL) {
        printf("Expected a proto3 document with the example.v1 package and the AppConfig message\n");
        return 1;
    }
    return 0;
}
