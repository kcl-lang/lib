#include <kcl_lib.h>

int main()
{
    static char mapping[BUFFER_SIZE] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };

    const char* files[] = { "main.k" };
    if (!kcl_get_schema_type_mapping_under_path("./test_data/schema_ty", files, 1, "",
            mapping, sizeof(mapping), err, sizeof(err))) {
        printf("GetSchemaTypeMappingUnderPath failed: %s\n", err);
        return 1;
    }

    printf("Schema type mapping under path: %s\n", mapping);
    return 0;
}
