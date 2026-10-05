import { expect, test } from "@jest/globals";

import {
  formatTestReport,
  generateDoc,
  generateKcl,
  generateOpenAPI,
  generateProto,
  generateToml,
} from "../src";
import { stringField } from "../src/protobuf";

/**
 * Wire-format tests for the `Generate*` and `FormatTestReport` wrappers.
 *
 * The prebuilt `kcl.wasm` shipped in this package predates all six RPCs —
 * `BuiltinService.ListMethod` reports 24 methods, none of them these — and
 * the module is built with `panic=abort`, so calling an unknown method name
 * aborts the instance instead of returning an error. The consistency runner
 * therefore skips those cases, which leaves the hand-written protobuf
 * encoders untested against the real core.
 *
 * These tests close that gap from the other side. A stub instance records
 * the exact request bytes and answers with a canned result, and every
 * expected hex below was produced by a real protobuf implementation
 * (`python`'s generated `spec_pb2.py`) and then re-parsed with it to confirm
 * the hand-rolled bytes decode to the intended message.
 *
 * Two deliberate, semantically neutral deviations from that reference
 * encoding:
 *
 * - `covered_lines` / `executable_lines` go out unpacked (one tag + varint
 *   per element) rather than packed into a single length-delimited field.
 *   Both are valid for a repeated scalar; this is the pre-existing
 *   `encodeUint64List` helper, which every other wrapper shares.
 * - Map entries keep insertion order instead of protobuf's unspecified
 *   map order. A map decodes to the same entries either way.
 */
function stubInstance(response: Uint8Array): {
  instance: WebAssembly.Instance;
  calls: { methodName: string; args: Uint8Array }[];
} {
  const memory = new WebAssembly.Memory({ initial: 1 });
  const calls: { methodName: string; args: Uint8Array }[] = [];
  let next = 0x1000;
  const malloc = (length: number): number => {
    const ptr = next;
    next += length + 8;
    return ptr;
  };
  const instance = {
    exports: {
      memory,
      kcl_malloc: malloc,
      kcl_free: () => undefined,
      call_native: (
        namePtr: number,
        nameLen: number,
        argsPtr: number,
        argsLen: number,
        resultBufPtr: number
      ): number => {
        const mem = new Uint8Array(memory.buffer);
        calls.push({
          methodName: new TextDecoder().decode(
            mem.slice(namePtr, namePtr + nameLen)
          ),
          args: mem.slice(argsPtr, argsPtr + argsLen).slice(),
        });
        new Uint8Array(memory.buffer, resultBufPtr, response.length).set(
          response
        );
        return response.length;
      },
    },
  } as unknown as WebAssembly.Instance;
  return { instance, calls };
}

function hex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

const PARSE_ARGS = {
  paths: ["/abs/tests/consistency/testdata/gen_openapi/main.k"],
  sources: [],
};
/** `Generate*Args{parse_args}` with one path and an empty trailing string. */
const PARSE_ARGS_HEX =
  "0a340a322f6162732f74657374732f636f6e73697374656e63792f74657374" +
  "646174612f67656e5f6f70656e6170692f6d61696e2e6b";

test("generateKcl encodes the three string fields and decodes the result", () => {
  const { instance, calls } = stubInstance(stringField(1, "a = 1\n"));

  const result = generateKcl(instance, {
    source: '{"a": {"b": 1}}',
    filename: "data.json",
    format: "",
  });

  expect(calls).toHaveLength(1);
  expect(calls[0].methodName).toBe("KclService.GenerateKcl");
  // source (1), filename (2); an empty `format` (3) is elided, matching
  // proto3 default-value omission.
  expect(hex(calls[0].args)).toBe(
    "0a0f7b2261223a207b2262223a20317d7d1209646174612e6a736f6e"
  );
  expect(result.kcl).toBe("a = 1\n");
});

test("generateKcl encodes a non-empty format", () => {
  const { instance, calls } = stubInstance(new Uint8Array(0));

  generateKcl(instance, {
    source: "a: 1\n",
    filename: "data.yaml",
    format: "yaml",
  });

  expect(hex(calls[0].args)).toBe(
    "0a05613a20310a1209646174612e79616d6c1a0479616d6c"
  );
});

test("generateToml nests ExecProgramArgs in field 1 and sorts on field 2", () => {
  const execArgs = {
    kCodeList: [
      'app = {name = "demo", ports = [80, 443], tls = {enabled = True}}',
    ],
    workDir: "",
  };
  const execArgsHex =
    "1a40" +
    "617070203d207b6e616d65203d202264656d6f222c20706f727473203d205b38302c20343433" +
    "5d2c20746c73203d207b656e61626c6564203d20547275657d7d";
  const expectedUnsorted = `0a42${execArgsHex}`;

  const unsorted = stubInstance(stringField(1, "[app]\n"));
  const result = generateToml(unsorted.instance, {
    execArgs,
    sortKeys: false,
  });
  expect(unsorted.calls[0].methodName).toBe("KclService.GenerateToml");
  expect(hex(unsorted.calls[0].args)).toBe(expectedUnsorted);
  expect(result.toml).toBe("[app]\n");

  // sort_keys = true, i.e. field 2 as a bare varint.
  const sorted = stubInstance(new Uint8Array(0));
  generateToml(sorted.instance, { execArgs, sortKeys: true });
  expect(hex(sorted.calls[0].args)).toBe(`${expectedUnsorted}1001`);
});

test("generateToml omits the exec_args field when there is nothing to send", () => {
  const { instance, calls } = stubInstance(new Uint8Array(0));
  generateToml(instance, {});
  expect(hex(calls[0].args)).toBe("");
});

test("generateOpenAPI nests ParseProgramArgs and appends the version", () => {
  const { instance, calls } = stubInstance(
    stringField(1, '{"openapi":"3.0.0"}')
  );

  const result = generateOpenAPI(instance, {
    parseArgs: PARSE_ARGS,
    version: "v3",
  });

  expect(calls[0].methodName).toBe("KclService.GenerateOpenAPI");
  expect(hex(calls[0].args)).toBe(`${PARSE_ARGS_HEX}12027633`);
  expect(result.spec).toBe('{"openapi":"3.0.0"}');
});

test("generateProto nests ParseProgramArgs and appends the package", () => {
  const { instance, calls } = stubInstance(
    stringField(1, 'syntax = "proto3";\n')
  );

  const result = generateProto(instance, {
    parseArgs: PARSE_ARGS,
    package: "example.v1",
  });

  expect(calls[0].methodName).toBe("KclService.GenerateProto");
  expect(hex(calls[0].args)).toBe(
    `${PARSE_ARGS_HEX}120a6578616d706c652e7631`
  );
  expect(result.proto).toBe('syntax = "proto3";\n');
});

test("generateDoc nests ParseProgramArgs and appends the format", () => {
  const { instance, calls } = stubInstance(stringField(1, "# Schemas\n"));

  const result = generateDoc(instance, { parseArgs: PARSE_ARGS, format: "md" });

  expect(calls[0].methodName).toBe("KclService.GenerateDoc");
  expect(hex(calls[0].args)).toBe(`${PARSE_ARGS_HEX}12026d64`);
  expect(result.content).toBe("# Schemas\n");
});

test("the three parse-args wrappers elide an empty trailing string", () => {
  const calls: [string, (i: WebAssembly.Instance) => unknown][] = [
    [
      "KclService.GenerateOpenAPI",
      (i) => generateOpenAPI(i, { parseArgs: PARSE_ARGS }),
    ],
    [
      "KclService.GenerateProto",
      (i) => generateProto(i, { parseArgs: PARSE_ARGS }),
    ],
    ["KclService.GenerateDoc", (i) => generateDoc(i, { parseArgs: PARSE_ARGS })],
  ];

  for (const [method, call] of calls) {
    const { instance, calls: recorded } = stubInstance(new Uint8Array(0));
    call(instance);
    expect(recorded[0].methodName).toBe(method);
    expect(hex(recorded[0].args)).toBe(PARSE_ARGS_HEX);
  }
});

test("formatTestReport encodes the whole TestResult, including log_message", () => {
  // The three cases of `tests/consistency/cases.json`: durations arrive as
  // decimal strings (uint64) and one case carries a log message.
  const { instance, calls } = stubInstance(stringField(1, "PASS: 2/3\n"));

  const result = formatTestReport(instance, {
    result: {
      info: [
        {
          name: "test_pass",
          error: "",
          duration: 1500,
          logMessage: "",
          lineHits: {},
        },
        {
          name: "test_log",
          error: "",
          duration: 2500,
          logMessage: "hello log",
          lineHits: {},
        },
        {
          name: "test_fail",
          error: "Error: assert failed",
          duration: 1000,
          logMessage: "",
          lineHits: {},
        },
      ],
    },
  });

  expect(calls[0].methodName).toBe("KclService.FormatTestReport");
  expect(hex(calls[0].args)).toBe(
    "0a50" +
      // name (1) + duration (3) only: empty strings and an empty map are elided
      "120e0a09746573745f7061737318dc0b" +
      // name (1) + duration (3) + log_message (4)
      "12180a08746573745f6c6f6718c413220968656c6c6f206c6f67" +
      // name (1) + error (2) + duration (3)
      "12240a09746573745f6661696c12144572726f723a20617373657274206661696c656418e807"
  );
  expect(result.report).toBe("PASS: 2/3\n");
});

test("formatTestReport encodes the line_hits map of a test case", () => {
  const { instance, calls } = stubInstance(new Uint8Array(0));

  formatTestReport(instance, {
    result: {
      info: [
        {
          name: "t",
          error: "",
          duration: 0,
          logMessage: "",
          lineHits: { "main.k:1": 2, "main.k:7": 5 },
        },
      ],
    },
  });

  // TestCaseInfo.line_hits (5) is map<string, uint64>: one entry per item,
  // each a submessage with the key in field 1 and the hit count in field 2.
  // Entries come out in insertion order; map order is not significant.
  expect(hex(calls[0].args)).toBe(
    "0a21" +
      "121f0a01742a0c0a086d61696e2e6b3a311002" +
      "2a0c0a086d61696e2e6b3a371005"
  );
});

test("formatTestReport encodes a coverage report alongside the case list", () => {
  const { instance, calls } = stubInstance(new Uint8Array(0));

  formatTestReport(instance, {
    result: {
      info: [
        {
          name: "test_a",
          error: "Error: assert failed",
          duration: 2500,
          logMessage: "log line",
          lineHits: { "main.k:1": 2 },
        },
      ],
      coverage: {
        files: {
          "main.k": {
            filename: "main.k",
            coveredLines: [1, 2],
            executableLines: [1, 2, 3],
            lineHits: { 1: 2, 2: 1 },
          },
        },
        summary: { covered: 2, executable: 3, percent: 66.7 },
      },
    },
  });

  expect(hex(calls[0].args)).toBe(
    "0a76" +
      // TestResult.info (2)
      "12390a06746573745f6112144572726f723a20617373657274206661696c656418c41322086c6f67206c696e652a0c0a086d61696e2e6b3a311002" +
      // TestResult.coverage (3) -> TestCoverageReport
      "1a39" +
      //   files (1) map<string, FileCoverage> -> FileCoverage
      "0a280a066d61696e2e6b121e" +
      "0a066d61696e2e6b" + //   filename (1)
      "10011002" + //         covered_lines (2), unpacked: 1, 2
      "180118021803" + //     executable_lines (3), unpacked: 1, 2, 3
      "220408011002" + //     line_hits (4): {1: 2}
      "220408021001" + //     line_hits (4): {2: 1}
      //   summary (2) -> CoverageSummary: covered, executable, percent
      "120d0802100319cdccccccccac5040"
  );
});

test("a reply whose single field is absent decodes to the empty string", () => {
  // One stub per call: `invokeKCLCallNative` asks for a 16 MiB result
  // buffer, so reusing a 1-page memory would run out of room.
  const results = [
    generateKcl(stubInstance(new Uint8Array(0)).instance, { source: "a" }).kcl,
    generateToml(stubInstance(new Uint8Array(0)).instance, {}).toml,
    generateOpenAPI(stubInstance(new Uint8Array(0)).instance, {}).spec,
    generateProto(stubInstance(new Uint8Array(0)).instance, {}).proto,
    generateDoc(stubInstance(new Uint8Array(0)).instance, {}).content,
    formatTestReport(stubInstance(new Uint8Array(0)).instance, {}).report,
  ];
  expect(results).toEqual(["", "", "", "", "", ""]);
});

test("an unknown field in a reply is skipped, not misread", () => {
  // field 2, varint 42, then the field 1 the wrapper cares about.
  const response = new Uint8Array([0x10, 0x2a, 0x0a, 0x03, 0x61, 0x62, 0x63]);
  const { instance } = stubInstance(response);
  expect(generateKcl(instance, { source: "a" }).kcl).toBe("abc");
});

test("a truncated reply raises an error instead of returning junk", () => {
  // field 1 claiming 5 bytes but only carrying 1.
  const { instance } = stubInstance(new Uint8Array([0x0a, 0x05, 0x61]));
  expect(() => generateKcl(instance, { source: "a" })).toThrow(
    /truncated protobuf field/
  );
});
