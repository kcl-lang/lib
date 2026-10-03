"""Generate the cross-language consistency manifest (cases.json).

Defines hermetic test cases (args + which result fields to pin), executes
them against the KCL core through the python binding, and writes the golden
expectations to ``tests/consistency/cases.json``.

Regenerate deterministically with:

    source python/venv/bin/activate && python tests/consistency/generate_cases.py

Do not hand-edit cases.json; change the case definitions here instead.
"""

import json
from pathlib import Path

import kcl_lib.api as api

MANIFEST = Path(__file__).resolve().parent / "cases.json"

PERSON_SCHEMA = "schema Person:\n    name: str\n    check:\n        len(name) > 0"


def build_cases():
    """Return the ordered case definitions.

    Each case is a dict:

        name    unique case name
        rpc     fully-qualified RPC name, e.g. "KclService.ExecProgram"
        new_core  True if the RPC only exists on cores that also expose the
                  Generate*/FormatTestReport RPCs; runners skip these when
                  the loaded core does not list the RPC.
        build_args(api_module) -> protobuf args message
        extract(result) -> dict of expect-field -> golden value (JSON-able)
    """
    cases = []

    def case(name, rpc, new_core, build_args, extract):
        cases.append(
            {
                "name": name,
                "rpc": rpc,
                "new_core": new_core,
                "build_args": build_args,
                "extract": extract,
            }
        )

    # 1. ping
    case(
        "ping",
        "KclService.Ping",
        False,
        lambda a: a.PingArgs(value="consistency"),
        lambda r: {"value": r.value},
    )

    # 2. exec_program_basic
    case(
        "exec_program_basic",
        "KclService.ExecProgram",
        False,
        lambda a: a.ExecProgramArgs(k_code_list=["alice = {age = 18}"]),
        lambda r: {"yaml_result": r.yaml_result, "json_result": r.json_result},
    )

    # 3. exec_program_overrides
    case(
        "exec_program_overrides",
        "KclService.ExecProgram",
        False,
        lambda a: a.ExecProgramArgs(
            k_code_list=["alice = {age = 1}"], overrides=["alice.age=18"]
        ),
        lambda r: {"yaml_result": r.yaml_result},
    )

    # 4. format_code
    case(
        "format_code",
        "KclService.FormatCode",
        False,
        lambda a: a.FormatCodeArgs(source="a=1\n"),
        lambda r: {"formatted": bytes(r.formatted).decode("utf-8")},
    )

    # 5. validate_code_ok
    case(
        "validate_code_ok",
        "KclService.ValidateCode",
        False,
        lambda a: a.ValidateCodeArgs(
            code=PERSON_SCHEMA, data='{"name": "Alice"}'
        ),
        lambda r: {"success": r.success, "err_message": r.err_message},
    )

    # 6. validate_code_invalid — only the success flag is pinned; the exact
    #    diagnostic text is not part of the cross-language contract.
    case(
        "validate_code_invalid",
        "KclService.ValidateCode",
        False,
        lambda a: a.ValidateCodeArgs(code=PERSON_SCHEMA, data='{"name": ""}'),
        lambda r: {"success": r.success},
    )

    # 7. generate_kcl_json — key quoting, null->None, float rendering,
    #    empty-format inference from the filename extension.
    case(
        "generate_kcl_json",
        "KclService.GenerateKcl",
        True,
        lambda a: a.GenerateKclArgs(
            source='{"a": {"b": 1}, "c": [1, 2.5, true, null], "d-e": "x"}',
            filename="data.json",
            format="",
        ),
        lambda r: {"kcl": r.kcl},
    )

    # 8. generate_kcl_yaml
    case(
        "generate_kcl_yaml",
        "KclService.GenerateKcl",
        True,
        lambda a: a.GenerateKclArgs(
            source="a: 1\nb:\n  - x\n  - y\n",
            filename="data.yaml",
            format="",
        ),
        lambda r: {"kcl": r.kcl},
    )

    # 9. generate_toml
    case(
        "generate_toml",
        "KclService.GenerateToml",
        True,
        lambda a: a.GenerateTomlArgs(
            exec_args=a.ExecProgramArgs(
                k_code_list=[
                    'app = {name = "demo", ports = [80, 443], tls = {enabled = True}}'
                ]
            )
        ),
        lambda r: {"toml": r.toml},
    )

    # 10. format_test_report — µs->ms truncation, separator line and tallies.
    def build_format_test_report_args(a):
        def info(name, error, duration, log_message):
            return a.TestCaseInfo(
                name=name, error=error, duration=duration, log_message=log_message
            )

        return a.FormatTestReportArgs(
            result=a.TestResult(
                info=[
                    info("test_pass", "", 1500, ""),
                    info("test_log", "", 2500, "hello log"),
                    info("test_fail", "Error: assert failed", 1000, ""),
                ]
            )
        )

    case(
        "format_test_report",
        "KclService.FormatTestReport",
        True,
        build_format_test_report_args,
        lambda r: {"report": r.report},
    )

    return cases


def main():
    cases = build_cases()
    instance = api.API()
    manifest_cases = []
    for c in cases:
        args = c["build_args"](api)
        result = _call(instance, c["rpc"], args)
        expect = c["extract"](result)
        manifest_cases.append(
            {
                "name": c["name"],
                "rpc": c["rpc"],
                "new_core": c["new_core"],
                "args": _args_to_json(args),
                "expect": expect,
            }
        )
    manifest = {
        "version": 1,
        "generated_by": "tests/consistency/generate_cases.py",
        "cases": manifest_cases,
    }
    MANIFEST.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"wrote {MANIFEST} with {len(manifest_cases)} cases")


_METHOD_ATTR = {
    "KclService.Ping": "ping",
    "KclService.ExecProgram": "exec_program",
    "KclService.FormatCode": "format_code",
    "KclService.ValidateCode": "validate_code",
    "KclService.GenerateKcl": "generate_kcl",
    "KclService.GenerateToml": "generate_toml",
    "KclService.FormatTestReport": "format_test_report",
}


def _call(instance, rpc, args):
    return getattr(instance, _METHOD_ATTR[rpc])(args)


def _args_to_json(args):
    from google.protobuf.json_format import MessageToDict

    return MessageToDict(
        args,
        preserving_proto_field_name=True,
        always_print_fields_with_no_presence=True,
    )


if __name__ == "__main__":
    main()
