#include <kcl_lib.h>

int main()
{
    static char program[BUFFER_SIZE] = { 0 };
    static char paths[4096] = { 0 };
    static char parse_errors[4096] = { 0 };
    static char type_errors[4096] = { 0 };
    static char scopes[BUFFER_SIZE] = { 0 };
    static char symbols[BUFFER_SIZE] = { 0 };
    static char node_symbol_map[BUFFER_SIZE] = { 0 };
    static char symbol_node_map[BUFFER_SIZE] = { 0 };
    static char fqn_map[BUFFER_SIZE] = { 0 };
    static char pkg_scope_map[BUFFER_SIZE] = { 0 };
    static char err[BUFFER_SIZE] = { 0 };

    struct KclLoadPackageResult result = {
        .program = program,
        .program_size = sizeof(program),
        .paths = paths,
        .paths_size = sizeof(paths),
        .parse_errors = parse_errors,
        .parse_errors_size = sizeof(parse_errors),
        .type_errors = type_errors,
        .type_errors_size = sizeof(type_errors),
        .scopes = scopes,
        .scopes_size = sizeof(scopes),
        .symbols = symbols,
        .symbols_size = sizeof(symbols),
        .node_symbol_map = node_symbol_map,
        .node_symbol_map_size = sizeof(node_symbol_map),
        .symbol_node_map = symbol_node_map,
        .symbol_node_map_size = sizeof(symbol_node_map),
        .fully_qualified_name_map = fqn_map,
        .fully_qualified_name_map_size = sizeof(fqn_map),
        .pkg_scope_map = pkg_scope_map,
        .pkg_scope_map_size = sizeof(pkg_scope_map),
    };

    const char* files[] = { "./test_data/schema.k" };
    if (!kcl_load_package(files, 1, false, false, false, &result, err, sizeof(err))) {
        printf("LoadPackage failed: %s\n", err);
        return 1;
    }

    printf("Program AST (first 200 bytes): %.200s\n", program);
    printf("Paths: %s\n", paths);
    printf("Parse errors: %s\n", parse_errors);
    printf("Type errors: %s\n", type_errors);
    printf("Scopes (first 300 bytes): %.300s\n", scopes);
    printf("Symbols (first 300 bytes): %.300s\n", symbols);
    printf("Node symbol map (first 200 bytes): %.200s\n", node_symbol_map);
    printf("Symbol node map (first 200 bytes): %.200s\n", symbol_node_map);
    printf("Fully qualified name map (first 200 bytes): %.200s\n", fqn_map);
    printf("Package scope map (first 200 bytes): %.200s\n", pkg_scope_map);
    return 0;
}
