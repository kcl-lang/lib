#include <kcl_lib.h>

int run_once()
{
    static char yaml_out[BUFFER_SIZE];
    static char err_out[BUFFER_SIZE];
    const char* code = "name = \"kcl\"\n"
                       "version = \"0.13\"\n";

    if (!kcl_run_code(code, yaml_out, sizeof(yaml_out), err_out, sizeof(err_out))) {
        printf("Run failed: %s\n", err_out);
        return 1;
    }
    printf("%s\n", yaml_out);
    return 0;
}

int validate_once()
{
    static char err_out[BUFFER_SIZE];
    const char* code = "schema Person:\n"
                       "    name: str\n"
                       "    age: int\n"
                       "    check:\n"
                       "        0 < age < 120\n";
    const char* data = "{\"name\": \"Alice\", \"age\": 10}";
    const char* bad_data = "{\"name\": \"Alice\", \"age\": 1110}";

    if (!kcl_validate_code(code, data, err_out, sizeof(err_out))) {
        printf("Validate failed: %s\n", err_out);
        return 1;
    }
    printf("Validate succeeded\n");

    if (kcl_validate_code(code, bad_data, err_out, sizeof(err_out))) {
        printf("Validate unexpectedly accepted out-of-range age\n");
        return 1;
    }
    printf("Validate rejected invalid data as expected: %s\n", err_out);
    return 0;
}

int main()
{
    if (run_once() != 0)
        return 1;
    if (validate_once() != 0)
        return 1;
    return 0;
}
