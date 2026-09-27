#include <kcl_lib.h>

int main()
{
    static struct KclKeyValuePair options[16] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };

    struct KclLoadSettingsFilesResult result = { 0 };
    result.kcl_options = options;
    result.kcl_options_size = 16;

    const char* files[] = { "./test_data/settings/kcl.yaml" };
    if (!kcl_load_settings_files("./test_data/settings", files, 1, &result, err, sizeof(err))) {
        printf("LoadSettingsFiles failed: %s\n", err);
        return 1;
    }

    printf("Files: %s\n", result.kcl_cli_configs.files);
    printf("Output: %s\n", result.kcl_cli_configs.output);
    printf("Strict range check: %d\n", result.kcl_cli_configs.strict_range_check);
    printf("Verbose: %lld\n", (long long)result.kcl_cli_configs.verbose);
    printf("KCL options (%zu):\n", result.kcl_option_count);
    for (size_t i = 0; i < result.kcl_option_count; ++i) {
        printf("  %s = %s\n", options[i].key, options[i].value);
    }
    return 0;
}
