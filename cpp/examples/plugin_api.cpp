#include "kcl_facade.hpp"
#include "kcl_plugin.hpp"

#include <iostream>

// Plugin example: host C++ functions reached from KCL source as
// `kcl_plugin.<plugin>.<method>(...)`. Covers the round trip, the JSON
// argument encoding, an unknown method surfacing as a KCL-level diagnostic,
// and the registry being rebindable. Non-zero exit code fails the CI example
// run.

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

    // 1. A method that ignores its arguments needs no JSON parser at all.
    kcl_lib::register_plugin("strings", "join",
        [](const std::string&, const std::string&) { return std::string("\"KCL.KCL.123\""); });

    rc |= check(kcl_lib::has_plugins(), "register_plugin binds the runtime");
    rc |= check(kcl_lib::plugin_registered("strings", "join"), "plugin_registered sees the method");

    {
        auto result = kcl_lib::Kcl::run(
            "import kcl_plugin.strings\n"
            "result = strings.join(\"KCL\", \"KCL\", 123)\n");
        rc |= check(result.getString("result") == "KCL.KCL.123",
            "plugin result reaches the KCL program");
        std::cout << "join -> result=" << result.getString("result") << "\n";
    }

    // 2. Arguments arrive as raw JSON: a JSON array of the positional
    //    arguments and a JSON object of the keyword arguments. Re-emitting
    //    them verbatim is enough — no parser needed.
    {
        std::string seen_args, seen_kwargs;
        kcl_lib::register_plugin("strings", "args",
            [&seen_args, &seen_kwargs](const std::string& args, const std::string& kwargs) {
                seen_args = args;
                seen_kwargs = kwargs;
                return "{\"args\":" + args + ",\"kwargs\":" + kwargs + "}";
            });

        auto result = kcl_lib::Kcl::run(
            "import kcl_plugin.strings\n"
            "result = strings.args(\"a\", b = 2)\n");
        // The runtime decodes the reply, so the KCL side sees real types:
        // `result.args` is a list and `result.kwargs` a dict.
        rc |= check(result.getString("result.args.0") == "a",
            "positional args arrive as a JSON array");
        rc |= check(result.getInt("result.kwargs.b") == 2,
            "keyword args arrive as a JSON object");
        rc |= check(seen_args == "[\"a\"]", "the plugin sees the raw positional JSON");
        rc |= check(seen_kwargs == "{\"b\": 2}", "the plugin sees the raw keyword JSON");
        std::cout << "args -> " << result.yaml_result() << "\n";
    }

    // 3. Errors are data: an unknown method becomes a `__kcl_PanicInfo__`
    //    object, which the runtime turns into a normal KCL diagnostic instead
    //    of crashing the process.
    {
        bool threw = false;
        std::string message;
        try {
            kcl_lib::Kcl::run(
                "import kcl_plugin.strings\n"
                "result = strings.nope()\n");
        } catch (const std::exception& err) {
            threw = true;
            message = err.what();
        }
        rc |= check(threw, "an unknown plugin method raises");
        rc |= check(message.find("nope") != std::string::npos,
            "the diagnostic names the missing method");
        std::cout << "unknown method -> " << message << "\n";
    }

    // 4. A throwing method is reported the same way, and never unwinds into
    //    the Rust frames underneath.
    {
        kcl_lib::register_plugin("strings", "boom", [](const std::string&, const std::string&) -> std::string {
            throw std::runtime_error("boom went off");
        });
        bool threw = false;
        std::string message;
        try {
            kcl_lib::Kcl::run(
                "import kcl_plugin.strings\n"
                "result = strings.boom()\n");
        } catch (const std::exception& err) {
            threw = true;
            message = err.what();
        }
        rc |= check(threw && message.find("boom went off") != std::string::npos,
            "a throwing plugin method surfaces as a KCL diagnostic");
        std::cout << "throwing method -> " << message << "\n";
    }

    // 5. Dropping the registry unbinds the runtime, and ordinary programs
    //    keep working.
    kcl_lib::disable_plugins();
    rc |= check(!kcl_lib::has_plugins(), "disable_plugins empties the registry");
    rc |= check(!kcl_lib::plugin_registered("strings", "join"), "the method is gone");
    {
        auto result = kcl_lib::Kcl::run("a = 1\n");
        rc |= check(result.getInt("a") == 1, "the stateless path still works");
    }

    if (rc == 0) {
        std::cout << "OK: C++ plugin example passed\n";
    }
    return rc;
}
