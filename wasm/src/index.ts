import { init, WASI, MemFS } from "@wasmer/wasi";
const RUN_FUNCTION_NAME = "kcl_run";
const RUN_WITH_LOG_MESSAGE_FUNCTION_NAME = "kcl_run_with_log_message";
const FMT_FUNCTION_NAME = "kcl_fmt";
const VERSION_FUNCTION_NAME = "kcl_version";
const CALL_FUNCTION_NAME = "kcl_call";
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
  data?: BufferSource;

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

export interface RunWithLogMessageOptions {
  /**
   * KCL code source
   */
  filename: string;
  /**
   * KCL code source
   */
  source: string;
}

export interface CallOptions {
  /**
   * Fully-qualified RPC name, e.g. `"KclService.ExecProgram"`.
   * Must match one of the services declared in `spec/spec.proto`.
   */
  methodName: string;
  /**
   * Protobuf-encoded argument bytes for the RPC. The bytes are
   * transported through WASM memory as UTF-8; protobuf wire format is
   * typically UTF-8 safe so this round-trips for any KCL service
   * argument type.
   */
  args: string;
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
    bytes = options.data as BufferSource;
  } else {
    if (typeof window !== "undefined") {
      const response = await fetch("../kcl.wasm");
      bytes = await response.arrayBuffer();
    } else if (typeof process !== "undefined") {
      const fs = require("fs");
      const path = require("path");
      const wasmPath = path.resolve(__dirname, "../kcl.wasm");
      bytes = fs.readFileSync(wasmPath) as unknown as BufferSource;
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
        return 0;
      },
    },
    ...(options.imports ?? {}),
  } as const;

  const module = await WebAssembly.compile(bytes);
  return w.instantiate(module, imports);
}

/**
 * Exported function to invoke the KCL run operation.
 */
export function invokeKCLRun(
  instance: WebAssembly.Instance,
  opts: RunOptions
): string {
  const exports = instance.exports as Record<string, any>;
  const [filenamePtr, filenamePtrLength] = copyStringToWasmMemory(
    instance,
    opts.filename
  );
  const [sourcePtr, sourcePtrLength] = copyStringToWasmMemory(
    instance,
    opts.source
  );
  let result = "";

  try {
    const resultPtr = exports[RUN_FUNCTION_NAME](filenamePtr, sourcePtr);
    const [resultStr, resultPtrLength] = copyCStrFromWasmMemory(
      instance,
      resultPtr
    );
    exports.kcl_free(resultPtr, resultPtrLength);
    result = resultStr;
  } catch (error) {
    const runtimeErrPtrLength = 1024;
    const runtimeErrPtr = exports.kcl_malloc(runtimeErrPtrLength);
    exports[RUNTIME_ERR_FUNCTION_NAME](runtimeErrPtr, runtimeErrPtrLength);
    const [runtimeErrStr] = copyCStrFromWasmMemory(instance, runtimeErrPtr);
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
  const exports = instance.exports as Record<string, any>;
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

/**
 * Exported function to invoke the KCL run operation and receive the
 * log message prepended to the YAML result. Returns a single string
 * combining the runtime log message (if any) followed by the YAML
 * result, or an "ERROR:<message>" string on failure.
 */
export function invokeKCLRunWithLogMessage(
  instance: WebAssembly.Instance,
  opts: RunWithLogMessageOptions
): string {
  const exports = instance.exports as Record<string, any>;
  const [filenamePtr, filenamePtrLength] = copyStringToWasmMemory(
    instance,
    opts.filename
  );
  const [sourcePtr, sourcePtrLength] = copyStringToWasmMemory(
    instance,
    opts.source
  );
  let result = "";

  try {
    const resultPtr = exports[RUN_WITH_LOG_MESSAGE_FUNCTION_NAME](
      filenamePtr,
      sourcePtr
    );
    const [resultStr, resultPtrLength] = copyCStrFromWasmMemory(
      instance,
      resultPtr
    );
    exports.kcl_free(resultPtr, resultPtrLength);
    result = resultStr;
  } catch (error) {
    const runtimeErrPtrLength = 1024;
    const runtimeErrPtr = exports.kcl_malloc(runtimeErrPtrLength);
    exports[RUNTIME_ERR_FUNCTION_NAME](runtimeErrPtr, runtimeErrPtrLength);
    const [runtimeErrStr] = copyCStrFromWasmMemory(instance, runtimeErrPtr);
    exports.kcl_free(runtimeErrPtr, runtimeErrPtrLength);
    result = "ERROR:" + runtimeErrStr;
  } finally {
    exports.kcl_free(filenamePtr, filenamePtrLength);
    exports.kcl_free(sourcePtr, sourcePtrLength);
  }

  return result;
}

/**
 * Exported function to query the KCL runtime version baked into the
 * WASM artifact. Returns a string such as "0.13.0".
 */
export function invokeKCLVersion(instance: WebAssembly.Instance): string {
  const exports = instance.exports as Record<string, any>;
  const resultPtr = exports[VERSION_FUNCTION_NAME]();
  if (resultPtr === 0 || resultPtr === null) {
    return "";
  }
  const [resultStr] = copyCStrFromWasmMemory(instance, resultPtr);
  return resultStr;
}

/**
 * Exported function to invoke any KCL service method by name through
 * the universal dispatcher. Returns the protobuf-encoded result bytes
 * as a UTF-8 string (suitable for `protobufjs` or similar decoders),
 * or an "ERROR:<message>" string on failure.
 *
 * The caller is responsible for encoding the `args` field according to
 * the corresponding `<Method>Args` message defined in `spec.proto`,
 * and for decoding the returned string as the corresponding
 * `<Method>Result` message.
 */
export function invokeKCLCall(
  instance: WebAssembly.Instance,
  opts: CallOptions
): string {
  const exports = instance.exports as Record<string, any>;
  // Name is read by `CStr::from_ptr` on the Rust side, so it does need
  // a NUL terminator — but we still pass the length so the Rust side
  // can construct a precise slice without scanning.
  const [namePtr, namePtrLength] = copyStringToWasmMemory(
    instance,
    opts.methodName
  );
  // Args are read as `&[u8]` of exactly the supplied length on the
  // Rust side, so the trailing NUL we wrote into wasm memory must not
  // be included in the length or the protobuf decoder will treat it
  // as an unknown field and panic (wasm is built with panic=abort).
  const [argsPtr, argsContentLength, argsAllocLength] = copyBytesToWasmMemory(
    instance,
    opts.args
  );
  let result = "";

  try {
    const resultPtr = exports[CALL_FUNCTION_NAME](
      namePtr,
      namePtrLength,
      argsPtr,
      argsContentLength
    );
    if (resultPtr === 0 || resultPtr === null) {
      result = "ERROR:kcl_call returned a null pointer";
    } else {
      const [resultStr, resultPtrLength] = copyCStrFromWasmMemory(
        instance,
        resultPtr
      );
      exports.kcl_free(resultPtr, resultPtrLength);
      result = resultStr;
    }
  } catch (error) {
    const runtimeErrPtrLength = 1024;
    const runtimeErrPtr = exports.kcl_malloc(runtimeErrPtrLength);
    exports[RUNTIME_ERR_FUNCTION_NAME](runtimeErrPtr, runtimeErrPtrLength);
    const [runtimeErrStr] = copyCStrFromWasmMemory(instance, runtimeErrPtr);
    exports.kcl_free(runtimeErrPtr, runtimeErrPtrLength);
    result = "ERROR:" + runtimeErrStr;
  } finally {
    exports.kcl_free(namePtr, namePtrLength);
    exports.kcl_free(argsPtr, argsAllocLength);
  }

  return result;
}

function copyStringToWasmMemory(
  instance: WebAssembly.Instance,
  str: string
): [number, number] {
  const exports = instance.exports as Record<string, any>;
  const encodedString = new TextEncoder().encode(str);
  const strLength = encodedString.length + 1;
  const pointer = exports.kcl_malloc(strLength);
  const memoryBuffer = exports.memory.buffer as ArrayBuffer;
  const buffer = new Uint8Array(memoryBuffer, pointer, strLength);

  buffer.set(encodedString);
  buffer[encodedString.length] = 0;
  return [pointer, strLength];
}

/**
 * Copies a UTF-8 string into wasm linear memory with a trailing NUL
 * terminator, returning the pointer, the content length (no NUL) and
 * the allocation length (content length + 1 for the NUL terminator).
 *
 * The caller uses `contentLength` as the logical length passed to
 * wasm functions that take a `*const u8, usize` pair so the trailing
 * NUL we wrote is never seen by the Rust slice, and uses
 * `allocationLength` when freeing with `kcl_free`.
 */
function copyBytesToWasmMemory(
  instance: WebAssembly.Instance,
  str: string
): [number, number, number] {
  const exports = instance.exports as Record<string, any>;
  const encodedString = new TextEncoder().encode(str);
  const allocationLength = encodedString.length + 1;
  const pointer = exports.kcl_malloc(allocationLength);
  const memoryBuffer = exports.memory.buffer as ArrayBuffer;
  const buffer = new Uint8Array(memoryBuffer, pointer, allocationLength);
  buffer.set(encodedString);
  buffer[encodedString.length] = 0;
  return [pointer, encodedString.length, allocationLength];
}

function copyCStrFromWasmMemory(
  instance: WebAssembly.Instance,
  ptr: number
): [string, number] {
  const exports = instance.exports as Record<string, any>;
  const memoryBuffer = exports.memory.buffer as ArrayBuffer;
  const memory = new Uint8Array(memoryBuffer);

  let end = ptr;
  while (memory[end] !== 0) end++;
  const result = new TextDecoder().decode(memory.slice(ptr, end));
  return [result, end - ptr + 1];
}
