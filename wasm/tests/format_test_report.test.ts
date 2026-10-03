import { expect, test } from "@jest/globals";

import { decodeTestResult, formatTestReport, TestResult } from "../src";
import { ProtoReader, stringField } from "../src/protobuf";

function hex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// A minimal stand-in for the kcl.wasm instance. It records the RPC name and
// the request bytes the wrapper hands to `call_native` and answers with a
// canned FormatTestReportResult, so the wrapper can be exercised without the
// runtime: the prebuilt kcl.wasm predates the RPC and traps (aborts) on the
// unknown method name, which leaves the instance unusable.
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
  const view = (): Uint8Array => new Uint8Array(memory.buffer);
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
        const mem = view();
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

test("formatTestReport dispatches KclService.FormatTestReport", () => {
  const report =
    "test_case_1: PASS (1ms)\ntest_case_2: FAIL (2ms)\nError: assert failed\n" +
    "-".repeat(80) +
    "\nPASS: 1/2\nFAIL: 1/2\n";
  const { instance, calls } = stubInstance(stringField(1, report));

  const result = formatTestReport(instance, {
    result: {
      info: [
        {
          name: "test_case_1",
          error: "",
          duration: 1500,
          logMessage: "",
          lineHits: {},
        },
        {
          name: "test_case_2",
          error: "Error: assert failed",
          duration: 2500,
          logMessage: "",
          lineHits: {},
        },
      ],
    },
  });

  expect(calls).toHaveLength(1);
  expect(calls[0].methodName).toBe("KclService.FormatTestReport");
  expect(result.report).toBe(report);
});

test("formatTestReport encodes the request like the other bindings", () => {
  // Same request the ruby and julia bindings put on the wire for a two-case
  // TestResult: FormatTestReportArgs{result} -> field 1, TestResult{info}
  // -> field 2, TestCaseInfo{name=1, error=2, duration=3, log_message=4}.
  const { instance, calls } = stubInstance(new Uint8Array(0));

  formatTestReport(instance, {
    result: {
      info: [
        {
          name: "test_case_1",
          error: "",
          duration: 1500,
          logMessage: "",
          lineHits: {},
        },
        {
          name: "test_case_2",
          error: "Error: assert failed",
          duration: 2500,
          logMessage: "",
          lineHits: {},
        },
      ],
    },
  });

  expect(hex(calls[0].args)).toBe(
    "0a3a12100a0b746573745f636173655f3118dc0b" +
      "12260a0b746573745f636173655f3212144572726f723a20617373657274206661696c656418c413"
  );
});

test("formatTestReport round-trips a result that carries coverage", () => {
  const { instance, calls } = stubInstance(new Uint8Array(0));

  const result: TestResult = {
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
  };
  formatTestReport(instance, { result });

  // The request is FormatTestReportArgs{result = field 1}; decode it back
  // with the TestResult decoder to check the whole nesting round-trips.
  const r = new ProtoReader(calls[0].args);
  let encodedResult: Uint8Array = new Uint8Array(0);
  while (!r.eof) {
    const tag = r.readTag();
    if (tag >>> 3 === 1) encodedResult = r.readBytes();
    else r.skip(tag & 7);
  }
  expect(decodeTestResult(encodedResult)).toEqual(result);
});
