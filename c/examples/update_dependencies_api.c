#include <errno.h>
#include <kcl_lib.h>
#include <sys/stat.h>

int main()
{
    static struct KclExternalPkgInfo pkgs[16] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };
    size_t count = 0;
    const char* dir = "./test_data/update_dep_tmp";

    if (mkdir(dir, 0755) != 0 && errno != EEXIST) {
        printf("Cannot create %s\n", dir);
        return 1;
    }
    FILE* fp = fopen("./test_data/update_dep_tmp/kcl.mod", "w");
    if (fp == NULL) {
        printf("Cannot create kcl.mod\n");
        return 1;
    }
    fputs("[package]\nname = \"tmp\"\nversion = \"0.0.1\"\n", fp);
    fclose(fp);

    if (!kcl_update_dependencies(dir, false, pkgs, 16, &count, err, sizeof(err))) {
        printf("UpdateDependencies failed: %s\n", err);
        remove("./test_data/update_dep_tmp/kcl.mod");
        remove(dir);
        return 1;
    }

    printf("External packages (%zu):\n", count);
    for (size_t i = 0; i < count; ++i) {
        printf("  %s = %s\n", pkgs[i].pkg_name, pkgs[i].pkg_path);
    }

    remove("./test_data/update_dep_tmp/kcl.mod");
    remove(dir);
    return 0;
}
