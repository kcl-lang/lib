#include "kcl_facade.hpp"
#include <iostream>

// High-level facade example (kcl-go style): run(code), run_files with
// overrides, dotted-path get(), the `_type` rewriting hook, validate and
// error handling. Non-zero exit code fails the CI example run.

static int check(bool cond, const char* msg)
{
    if (!cond) {
        std::cerr << "FAIL: " << msg << "\n";
        return 1;
    }
    return 0;
}

int main()
{
    int rc = 0;

    // 1. run(code) + dotted-path get().
    {
        auto result = kcl_lib::Kcl::run(
            "name = \"kcl\"\n"
            "server = {host = \"localhost\", port = 8080}\n");
        rc |= check(result.get("server.port").as_int() == 8080,
            "run(code): get(\"server.port\") == 8080");
        std::cout << "run(code) name=" << result.get("name").as_string()
                  << " server.port=" << result.get("server.port").as_int() << "\n";
        std::cout << "yaml_result:\n"
                  << result.yaml_result() << "\n";
    }

    // 2. run_files(paths, opts) + overrides (-O).
    {
        auto result = kcl_lib::Kcl::run_files({ "../test_data/schema.k" },
            kcl_lib::Options {
                .overrides = { "app.replicas=5" },
            });
        rc |= check(result.get("app.replicas").as_int() == 5,
            "run_files + overrides: app.replicas == 5");
        std::cout << "overridden app.replicas=" << result.get("app.replicas").as_int() << "\n";
    }

    // 3. include_schema_type_path: `_type` is rewritten to the short schema
    //    name by default (kcl-go's typeAttributeHook). aaa/main.k imports
    //    schema B from the external "bbb" package, so the full path is
    //    "bbb.B" (external packages resolve through Options::external_pkgs).
    {
        auto result = kcl_lib::Kcl::run_files({ "../test_data/get_schema_ty/aaa/main.k" },
            kcl_lib::Options {
                .external_pkgs = { { "bbb", "../test_data/get_schema_ty/bbb" },
                    { "ccc", "../test_data/get_schema_ty/ccc" } },
                .include_schema_type_path = true,
            });
        std::cout << "short _type=" << result.get("a._type").as_string() << "\n";
        rc |= check(result.get("a._type").as_string() == "B",
            "include_schema_type_path: _type rewritten to B");
        // The hook rewrites yaml_result as well, not just json_result.
        rc |= check(result.yaml_result().find("_type: B") != std::string::npos,
            "include_schema_type_path: yaml_result carries the short _type");
        std::cout << "short yaml_result:\n"
                  << result.yaml_result() << "\n";
    }

    // 4. ...unless full_type_path is set, which keeps the full pkg path.
    {
        auto result = kcl_lib::Kcl::run_files({ "../test_data/get_schema_ty/aaa/main.k" },
            kcl_lib::Options {
                .external_pkgs = { { "bbb", "../test_data/get_schema_ty/bbb" },
                    { "ccc", "../test_data/get_schema_ty/ccc" } },
                .full_type_path = true,
            });
        std::cout << "full _type=" << result.get("a._type").as_string() << "\n";
        rc |= check(result.get("a._type").as_string() == "bbb.B",
            "full_type_path: _type keeps the full path");
    }

    // 5. validate(code, data, format).
    {
        const std::string schema = "schema Person:\n"
                                   "    name: str\n"
                                   "    age: int\n"
                                   "    check:\n"
                                   "        0 < age < 120\n";
        bool good_ok = kcl_lib::Kcl::validate(schema, "{\"name\": \"Alice\", \"age\": 10}", "json");
        rc |= check(good_ok, "validate: valid data passes");
        bool bad_ok = true;
        try {
            bad_ok = kcl_lib::Kcl::validate(schema, "{\"name\": \"Alice\", \"age\": 1110}", "json");
        } catch (const kcl_lib::KclError&) {
            bad_ok = false;
        }
        rc |= check(!bad_ok, "validate: invalid data rejected");
        std::cout << "validate good_ok=" << good_ok << " bad_ok=" << bad_ok << "\n";
    }

    // 6. Compile errors surface as KclError (bridge errors are wrapped).
    {
        bool threw = false;
        try {
            kcl_lib::Kcl::run("a = = 1");
        } catch (const kcl_lib::KclError& err) {
            threw = true;
            std::cout << "caught KclError: " << err.what() << "\n";
        }
        rc |= check(threw, "compile error raises KclError");
    }

    if (rc == 0) {
        std::cout << "OK: C++ facade example passed\n";
    }
    return rc;
}
