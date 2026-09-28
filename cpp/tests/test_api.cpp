// Minimal assertion-based test suite for the kcl-lib-cpp cxx bridge.
//
// Covers the core RPCs end-to-end (get_version, ping, exec_program,
// parse_file, parse_program, format_code, lint_path, validate_code,
// list_options) plus the Test RPC with line coverage enabled, which
// exercises the TestResult.coverage / TestCaseInfo.line_hits bridge
// fields. Plain <cassert>-style CHECK macro, no external dependencies.

#include "kcl_lib.hpp"

#include <cmath>
#include <exception>
#include <iostream>
#include <string>
#include <utility>
#include <vector>

#ifndef KCL_TEST_DATA_DIR
#define KCL_TEST_DATA_DIR "../test_data"
#endif

#define CHECK(cond) \
    do { \
        if (!(cond)) { \
            std::cerr << "CHECK failed: " << #cond << " at " << __FILE__ << ":" << __LINE__ \
                      << std::endl; \
            return false; \
        } \
    } while (0)

static bool contains(rust::String haystack, const std::string& needle)
{
    return std::string(haystack.c_str()).find(needle) != std::string::npos;
}

static bool test_get_version()
{
    auto result = kcl_lib::get_version();
    CHECK(!result.version.empty());
    CHECK(!result.git_sha.empty());
    return true;
}

static bool test_ping()
{
    auto args = kcl_lib::PingArgs { .value = "hello-cpp" };
    auto result = kcl_lib::ping(args);
    CHECK(result.value == "hello-cpp");
    return true;
}

static bool test_exec_program()
{
    auto args = kcl_lib::ExecProgramArgs {
        .k_filename_list = { KCL_TEST_DATA_DIR "/schema.k" },
    };
    auto result = kcl_lib::exec_program(args);
    CHECK(result.err_message.empty());
    CHECK(contains(result.yaml_result, "replicas"));
    CHECK(contains(result.yaml_result, "2"));
    CHECK(contains(result.json_result, "replicas"));
    return true;
}

static bool test_parse_file()
{
    auto args = kcl_lib::ParseFileArgs {
        .path = KCL_TEST_DATA_DIR "/schema.k",
    };
    auto result = kcl_lib::parse_file(args);
    CHECK(result.errors.empty());
    CHECK(!result.ast_json.empty());
    CHECK(contains(result.ast_json, "AppConfig"));
    return true;
}

static bool test_parse_program()
{
    auto args = kcl_lib::ParseProgramArgs {
        .paths = { KCL_TEST_DATA_DIR "/option/main.k" },
    };
    auto result = kcl_lib::parse_program(args);
    CHECK(result.errors.empty());
    CHECK(!result.ast_json.empty());
    return true;
}

static bool test_format_code()
{
    auto args = kcl_lib::FormatCodeArgs {
        .source = "schema Person:\n"
                  "    name:     str\n"
                  "    age:     int\n"
                  "    check:\n"
                  "        0 <     age <     120\n",
    };
    auto result = kcl_lib::format_code(args);
    CHECK(!result.formatted.empty());
    CHECK(contains(result.formatted, "name: str"));
    return true;
}

static bool test_lint_path()
{
    auto args = kcl_lib::LintPathArgs {
        .paths = { KCL_TEST_DATA_DIR "/lint_path/test-lint.k" },
    };
    auto result = kcl_lib::lint_path(args);
    CHECK(!result.results.empty());
    return true;
}

static bool test_validate_code()
{
    const char* code = "schema Person:\n"
                       "    name: str\n"
                       "    age: int\n"
                       "    check:\n"
                       "        0 < age < 120\n";

    auto ok_args = kcl_lib::ValidateCodeArgs {
        .data = "{\"name\": \"Alice\", \"age\": 10}",
        .code = code,
    };
    auto ok_result = kcl_lib::validate_code(ok_args);
    CHECK(ok_result.success);

    auto bad_args = kcl_lib::ValidateCodeArgs {
        .data = "{\"name\": \"Alice\", \"age\": 1110}",
        .code = code,
    };
    auto bad_result = kcl_lib::validate_code(bad_args);
    CHECK(!bad_result.success);
    CHECK(!bad_result.err_message.empty());
    return true;
}

static bool test_list_options()
{
    auto args = kcl_lib::ParseProgramArgs {
        .paths = { KCL_TEST_DATA_DIR "/option/main.k" },
    };
    auto result = kcl_lib::list_options(args);
    CHECK(result.options.size() == 3);
    CHECK(result.options[0].name == "key1");
    CHECK(result.options[1].name == "key2");
    CHECK(result.options[2].name == "metadata-key");
    return true;
}

static bool test_with_coverage()
{
    auto args = kcl_lib::TestArgs {
        .pkg_list = { KCL_TEST_DATA_DIR "/testing/..." },
        .coverage = true,
    };
    auto result = kcl_lib::test(args);
    CHECK(result.info.size() >= 2);

    // Both func_test.k cases must pass.
    size_t passed = 0;
    bool saw_line_hits = false;
    for (const auto& info : result.info) {
        CHECK(info.error.empty());
        ++passed;
        if (info.line_hits.size() > 0) {
            saw_line_hits = true;
            CHECK(info.line_hits[0].value >= 1);
        }
    }
    CHECK(passed >= 2);
    CHECK(saw_line_hits);

    // Aggregated report populated when coverage = true.
    CHECK(result.coverage.has_value);
    const auto& report = result.coverage.value;
    CHECK(!report.files.empty());
    CHECK(report.summary.has_value);
    CHECK(report.summary.value.executable > 0);
    CHECK(report.summary.value.covered > 0);
    CHECK(report.summary.value.covered <= report.summary.value.executable);
    CHECK(report.summary.value.percent >= 0.0);
    CHECK(report.summary.value.percent <= 100.0);
    const auto& file = report.files[0].value;
    CHECK(!file.filename.empty());
    CHECK(!file.executable_lines.empty());
    CHECK(!file.line_hits.empty());
    return true;
}

int main()
{
    const std::vector<std::pair<const char*, bool (*)()>> tests = {
        { "get_version", test_get_version },
        { "ping", test_ping },
        { "exec_program", test_exec_program },
        { "parse_file", test_parse_file },
        { "parse_program", test_parse_program },
        { "format_code", test_format_code },
        { "lint_path", test_lint_path },
        { "validate_code", test_validate_code },
        { "list_options", test_list_options },
        { "test_with_coverage", test_with_coverage },
    };

    int failed = 0;
    for (const auto& [name, fn] : tests) {
        try {
            if (fn()) {
                std::cout << "[PASS] " << name << std::endl;
            } else {
                std::cout << "[FAIL] " << name << std::endl;
                ++failed;
            }
        } catch (const std::exception& e) {
            std::cerr << "[FAIL] " << name << " threw: " << e.what() << std::endl;
            ++failed;
        }
    }

    if (failed > 0) {
        std::cerr << failed << " test(s) failed" << std::endl;
        return 1;
    }
    std::cout << "All " << tests.size() << " tests passed" << std::endl;
    return 0;
}
