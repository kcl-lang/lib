import { init, WASI, MemFS } from "@wasmer/wasi";
const RUN_FUNCTION_NAME = "kcl_run";
const FMT_FUNCTION_NAME = "kcl_fmt";
const RUNTIME_ERR_FUNCTION_NAME = "kcl_runtime_err";

export interface KCLWasmLoadOptions {
  /**
   * Additional imports to pass to the WASI instance. Imports objects/functions that WASM code can invoke.
   *
   * @default `{ wasi_snapshot_preview1: wasi.wasiImport }`
   */
  imports?: Record<string, any>;

  /**
   * Preopen directories for the WASI instance.
   * These are directories that the sandboxed WASI instance can access.
   * The also represent mappings from the WASI instance's filesystem to the host filesystem. (map key -> value)
   * @default - No additional preopens are added other than the above
   */
  preopens?: Record<string, string>;

  /**
   * Environment variables to pass to the WASI instance.
   *
   * @default - No additional envs are added other than the above
   */
  env?: Record<string, string>;

  /**
   * A filesystem for the WASI instance to use.
   *
   * @default - The `fs` module from Node.js
   */
  fs?: MemFS;

  /**
   * The bytes of the `kcl.wasm` data loaded into memory.
   *
   * @default - The kcl.wasm bundled with this package is read from disk.
   */
  data?: Uint8Array;

  readonly log?: (...args: any[]) => void;
}

export interface RunOptions {
  /**
   * KCL code source
   */
  filename: string;
  /**
   * KCL code source
   */
  source: string;
}

export interface FmtOptions {
  /**
   * KCL code source
   */
  source: string;
}

/**
 * load the KCL WASM
 * @param options
 * @returns
 */
export async function load(opts?: KCLWasmLoadOptions) {
  await init();
  const options = opts ?? {};
  const w = new WASI({
    env: options.env ?? {},
    fs: options.fs,
  });

  let bytes: BufferSource;
  if (options.data) {
    bytes = options.data;
  } else {
    if (typeof window !== "undefined") {
      const response = await fetch("../kcl.wasm");
      bytes = await response.arrayBuffer();
    } else if (typeof process !== "undefined") {
      const fs = require("fs");
      const path = require("path");
      const wasmPath = path.resolve(__dirname, "../kcl.wasm");
      bytes = fs.readFileSync(wasmPath);
    } else {
      throw new Error("Unsupported environment");
    }
  }
  const imports = {
    env: {
    kcl_plugin_invoke_json_wasm: (
        _method: number,
        _args: number,
        _kwargs: number
      ) => {
        // TODO: KCL WASM plugin impl
        return 0;
      },
    },
    ...(options.imports ?? {}),
  } as object;

  const module = await WebAssembly.compile(bytes);
  // Instantiate the WASI module
  return w.instantiate(module, imports);
}

/**
 * Exported function to invoke the KCL run operation.
 */
export function invokeKCLRun(
  instance: WebAssembly.Instance,
  opts: RunOptions
): string {
  const exports = instance.exports as any;
  const [filenamePtr, filenamePtrLength] = copyStringToWasmMemory(
    instance,
    opts.filename
  );
  const [sourcePtr, sourcePtrLength] = copyStringToWasmMemory(
    instance,
    opts.source
  );
  let result;
  try {
    const resultPtr = exports[RUN_FUNCTION_NAME](filenamePtr, sourcePtr);
    const [resultStr, resultPtrLength] = copyCStrFromWasmMemory(
      instance,
      resultPtr
    );
    exports.kcl_free(resultPtr, resultPtrLength);
    result = resultStr;
  } catch (error) {
    let runtimeErrPtrLength = 1024;
    let runtimeErrPtr = exports.kcl_malloc(runtimeErrPtrLength);
    exports[RUNTIME_ERR_FUNCTION_NAME](runtimeErrPtr, runtimeErrPtrLength);
    const [runtimeErrStr, _] = copyCStrFromWasmMemory(instance, runtimeErrPtr);
    exports.kcl_free(runtimeErrPtr, runtimeErrPtrLength);
    result = "ERROR:" + runtimeErrStr;
  } finally {
    exports.kcl_free(filenamePtr, filenamePtrLength);
    exports.kcl_free(sourcePtr, sourcePtrLength);
  }
  return result;
}

/**
 * Exported function to invoke the KCL format operation.
 */
export function invokeKCLFmt(
  instance: WebAssembly.Instance,
  opts: FmtOptions
): string {
  const exports = instance.exports as any;
  const [sourcePtr, sourcePtrLength] = copyStringToWasmMemory(
    instance,
    opts.source
  );
  const resultPtr = exports[FMT_FUNCTION_NAME](sourcePtr);
  const [resultStr, resultPtrLength] = copyCStrFromWasmMemory(
    instance,
    resultPtr
  );
  exports.kcl_free(sourcePtr, sourcePtrLength);
  exports.kcl_free(resultPtr, resultPtrLength);
  return resultStr;
}

function copyStringToWasmMemory(
  instance: WebAssembly.Instance,
  str: string
): [number, number] {
  const exports = instance.exports as any;
  const encodedString = new TextEncoder().encode(str);
  const pointer = exports.kcl_malloc(encodedString.length + 1); // Allocate memory and get pointer
  const buffer = new Uint8Array(
    exports.memory.buffer,
    pointer,
    encodedString.length + 1
  );
  buffer.set(encodedString);
  buffer[encodedString.length] = 0; // Null-terminate the string
  return [pointer, encodedString.length + 1];
}

function copyCStrFromWasmMemory(
  instance: WebAssembly.Instance,
  ptr: number
): [string, number] {
  const exports = instance.exports as any;
  const memory = new Uint8Array(exports.memory.buffer);
  let end = ptr;
  while (memory[end] !== 0) {
    end++;
  }
  const result = new TextDecoder().decode(memory.slice(ptr, end));
  return [result, end + 1 - ptr];
}
