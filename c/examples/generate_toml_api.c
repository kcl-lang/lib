#include <kcl_lib.h>

int main()
{
    static char toml[BUFFER_SIZE] = { 0 };

    const char* code_list[] = { "app = {name = \"demo\", ports = [80, 443], tls = {enabled = True}}" };
    struct KclExecProgramArgs request = {
        .k_code_list = code_list,
        .k_code_count = 1,
    };

    if (!kcl_generate_toml(&request, toml, sizeof(toml))) {
        printf("GenerateToml failed: %s\n", toml);
        return 1;
    }

    printf("%s", toml);
    if (strstr(toml, "[app]") == NULL) {
        printf("Expected an [app] table in the TOML output: %s\n", toml);
        return 1;
    }
    if (strstr(toml, "[app.tls]") == NULL) {
        printf("Expected an [app.tls] table in the TOML output: %s\n", toml);
        return 1;
    }
    return 0;
}
