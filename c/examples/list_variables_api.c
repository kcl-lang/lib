#include <kcl_lib.h>

int main()
{
    static char variables[BUFFER_SIZE] = { 0 };
    static char unsupported[4096] = { 0 };
    static char parse_errors[4096] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };

    struct KclListVariablesResult result = {
        .variables = variables,
        .variables_size = sizeof(variables),
        .unsupported_codes = unsupported,
        .unsupported_codes_size = sizeof(unsupported),
        .parse_errors = parse_errors,
        .parse_errors_size = sizeof(parse_errors),
    };

    const char* files[] = { "./test_data/variables.k" };
    const char* specs[] = { "a", "c", "d" };
    if (!kcl_list_variables(files, 1, specs, 3, false, &result, err, sizeof(err))) {
        printf("ListVariables failed: %s\n", err);
        return 1;
    }

    printf("Variables: %s\n", variables);
    printf("Unsupported codes: %s\n", unsupported);
    printf("Parse errors: %s\n", parse_errors);
    return 0;
}
