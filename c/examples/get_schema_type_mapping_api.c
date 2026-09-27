#include <kcl_lib.h>

int main()
{
    static char mapping[BUFFER_SIZE] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };

    const char* files[] = { "main.k" };
    if (!kcl_get_schema_type_mapping("./test_data/schema_ty", files, 1, "Person",
            mapping, sizeof(mapping), err, sizeof(err))) {
        printf("GetSchemaTypeMapping failed: %s\n", err);
        return 1;
    }

    printf("Schema type mapping: %s\n", mapping);
    return 0;
}
