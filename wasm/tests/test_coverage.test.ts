import { describe, expect, test } from "@jest/globals";

import { decodeTestResult } from "../src";
import {
  boolField,
  bytesField,
  concatBytes,
  encodeVarint,
  int64Field,
  stringField,
} from "../src/protobuf";

// Field 1 (fixed64 / double) tag for CoverageSummary.percent.
function doubleField(field: number, value: number): Uint8Array {
  const buf = new Uint8Array(9);
  buf[0] = (field << 3) | 1;
  new DataView(buf.buffer).setFloat64(1, value, true);
  return buf;
}

// map<uint64, uint64> entry for FileCoverage.line_hits: both key and value
// are varint-coded (wire type 0).
function uint64MapEntry(field: number, key: number, value: number): Uint8Array {
  return bytesField(
    field,
    concatBytes(int64Field(1, key), int64Field(2, value))
  );
}

describe("TestResult coverage decoding", () => {
  test("decodeTestResult reads TestCaseInfo.line_hits (field 5)", () => {
    const caseInfo = concatBytes(
      stringField(1, "test_a"),
      int64Field(3, 42),
      bytesField(5, concatBytes(stringField(1, "main.k:1"), int64Field(2, 3)))
    );
    const out = decodeTestResult(bytesField(2, caseInfo));
    expect(out.info).toHaveLength(1);
    expect(out.info[0].name).toBe("test_a");
    expect(out.info[0].duration).toBe(42);
    expect(out.info[0].lineHits).toEqual({ "main.k:1": 3 });
  });

  test("decodeTestResult reads TestResult.coverage (field 3)", () => {
    const fileCoverage = concatBytes(
      stringField(1, "main.k"),
      int64Field(2, 1),
      int64Field(2, 2),
      int64Field(3, 1),
      int64Field(3, 2),
      int64Field(3, 3),
      uint64MapEntry(4, 1, 2),
      uint64MapEntry(4, 2, 1)
    );
    const summary = concatBytes(
      int64Field(1, 2),
      int64Field(2, 3),
      doubleField(3, 66.66666666666667)
    );
    const report = concatBytes(
      bytesField(
        1,
        concatBytes(stringField(1, "main.k"), bytesField(2, fileCoverage))
      ),
      bytesField(2, summary)
    );
    const out = decodeTestResult(bytesField(3, report));

    expect(out.coverage).toBeDefined();
    const file = out.coverage?.files["main.k"];
    expect(file?.filename).toBe("main.k");
    expect(file?.coveredLines).toEqual([1, 2]);
    expect(file?.executableLines).toEqual([1, 2, 3]);
    expect(file?.lineHits).toEqual({ 1: 2, 2: 1 });
    expect(out.coverage?.summary?.covered).toBe(2);
    expect(out.coverage?.summary?.executable).toBe(3);
    expect(out.coverage?.summary?.percent).toBeCloseTo(66.67, 1);
  });

  test("encodeVarint sanity check for the map fixture", () => {
    expect(encodeVarint(300n)).toEqual(new Uint8Array([0xac, 0x02]));
  });

  test("boolField encodes TestArgs.coverage (5) with wire tag 0x28", () => {
    const bytes = boolField(5, true);
    expect(bytes.length).toBe(2);
    // Tag = (5 << 3) | 0 = 40 → 0x28, value 1.
    expect(bytes[0]).toBe(0x28);
    expect(bytes[1]).toBe(1);
    expect(boolField(5, false).length).toBe(0);
  });
});
