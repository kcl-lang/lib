import { init, WASI, MemFS } from "@wasmer/wasi";
export * from "./api";
export * from "./facade";
export * from "./plugin";
import { invokePluginJson, jsonError } from "./plugin";
const RUN_FUNCTION_NAME = "kcl_run";
const RUN_WITH_LOG_MESSAGE_FUNCTION_NAME = "kcl_run_with_log_message";
const FMT_FUNCTION_NAME = "kcl_fmt";
const VERSION_FUNCTION_NAME = "kcl_version";
const CALL_FUNCTION_NAME = "kcl_call";
const CALL_NATIVE_FUNCTION_NAME = "call_native";
const RUNTIME_ERR_FUNCTION_NAME = "kcl_runtime_err";
const DEFAULT_CALL_NATIVE_RESULT_BUFFER_SIZE = 16 * 1024 * 1024;
// Size of the buffer the JS wrapper allocates when the WASM module traps so
// it can ask the wasm guest to write the panic message into it via the
// `kcl_runtime_err` export. The previous value of 1024 silently truncated
// any KCL runtime error whose rendered message exceeded 1 KiB; raised to
// 4 KiB to match every other binding. See
// `/Users/timi/codes/lib/docs/abi.md` §5.
const RUNTIME_ERR_BUFFER_SIZE = 4 * 1024;
const SERVICE_NEW_FUNCTION_NAME = "kcl_service_new";
const SERVICE_CALL_FUNCTION_NAME = "kcl_service_call_with_length";
const SERVICE_DELETE_FUNCTION_NAME = "kcl_service_delete";
const SERVICE_FREE_STRING_FUNCTION_NAME = "kcl_service_free_string";
/**
 * Plugin-agent pointer handed to `kcl_service_new`. Any non-zero value
 * turns on `load_plugins` in the KCL loader, which is what lets
 * `import kcl_plugin.<name>` resolve. On `wasm32` the runtime's
 * `kcl_plugin_invoke_json` never calls this pointer — it always routes
 * plugin callouts through the `env.kcl_plugin_invoke_json_wasm` import
 * (see `crates/runtime/src/stdlib/plugin.rs`), so `1` is never invoked
 * and only its being non-zero matters.
 */
const PLUGIN_AGENT_SENTINEL = 1n;

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
   * Each entry maps a guest path (visible to the WASM instance) to a path
   * in the instance filesystem (`fs`, an in-memory `MemFS` by default), e.g.
   * `{ "/sandbox": "/work" }` exposes the filesystem path `/work` as
   * `/sandbox` inside the instance. Note that with the default in-memory
   * filesystem this does not grant access to the host filesystem.
   * @default - The filesystem root `.` is preopened as `/`
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

export interface InvokeKCLRunOptions {
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
    preopens: options.preopens,
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

  // Backs the `env.kcl_plugin_invoke_json_wasm` import below: the import
  // closure needs the instance to read its arguments out of linear memory,
  // and the instance only exists once `instantiate` resolves.
  const host: PluginHost = { instance: null, replyPtr: 0, replyCapacity: 0 };

  const imports = {
    env: {
      kcl_plugin_invoke_json_wasm: (
        method: number,
        args: number,
        kwargs: number
      ) => {
        return dispatchPluginInvoke(host, method, args, kwargs);
      },
    },
    ...(options.imports ?? {}),
  } as const;

  const module = await WebAssembly.compile(bytes);
  const instance = await w.instantiate(module, imports);
  // The plugin import is created before the instance exists, so publish it
  // now: the wasm module can only call back once instantiation returned.
  host.instance = instance;
  return instance;
}

/**
 * Per-instance state the `env.kcl_plugin_invoke_json_wasm` import needs:
 * the instance itself (to reach its linear memory and `kcl_malloc`) and
 * the reply buffer reused across plugin calls.
 */
interface PluginHost {
  instance: WebAssembly.Instance | null;
  replyPtr: number;
  replyCapacity: number;
}

/**
 * The plugin agent the wasm module calls for every `kcl_plugin.<name>`
 * invocation. Reads the method name and the JSON-encoded arguments out of
 * wasm linear memory, runs the registered method, and hands the
 * JSON-encoded result back as a NUL-terminated string in wasm memory.
 *
 * Never throws: a failure inside the registry is reported to KCL as the
 * `{"__kcl_PanicInfo__": ...}` envelope so the program fails with a
 * diagnostic rather than tearing down the instance.
 */
function dispatchPluginInvoke(
  host: PluginHost,
  methodPtr: number,
  argsPtr: number,
  kwargsPtr: number
): number {
  const instance = host.instance;
  if (!instance) {
    return 0;
  }
  const exports = instance.exports as Record<string, any>;
  let reply: string;
  try {
    reply = invokePluginJson(
      copyCStrFromWasmMemory(instance, methodPtr)[0],
      copyCStrFromWasmMemory(instance, argsPtr)[0],
      copyCStrFromWasmMemory(instance, kwargsPtr)[0]
    );
  } catch (error) {
    reply = jsonError(
      error instanceof Error ? error.message : String(error)
    );
  }
  return writePluginReply(exports, host, new TextEncoder().encode(reply));
}

/**
 * Write the plugin reply into wasm memory and return its pointer.
 *
 * The KCL runtime reads the string and drops the pointer without freeing
 * it (the C header's contract is "the returned pointer only has to stay
 * alive until the next plugin invocation"), so the buffer is owned by the
 * host and reused across calls — allocating per call would leak.
 */
function writePluginReply(
  exports: Record<string, any>,
  host: PluginHost,
  bytes: Uint8Array
): number {
  const capacity = bytes.length + 1;
  if (host.replyPtr === 0 || host.replyCapacity < capacity) {
    if (host.replyPtr !== 0) {
      exports.kcl_free(host.replyPtr, host.replyCapacity);
    }
    host.replyPtr = exports.kcl_malloc(capacity) as number;
    host.replyCapacity = capacity;
    if (host.replyPtr === 0) {
      // Out of memory. Returning a null pointer makes the runtime fall back
      // to Undefined rather than dereferencing it.
      return 0;
    }
  }
  // The memory may have grown while `kcl_malloc` ran, so take the view now.
  const buffer = new Uint8Array(exports.memory.buffer as ArrayBuffer);
  buffer.set(bytes, host.replyPtr);
  buffer[host.replyPtr + bytes.length] = 0;
  return host.replyPtr;
}

/**
 * Exported function to invoke the KCL run operation.
 */
export function invokeKCLRun(
  instance: WebAssembly.Instance,
  opts: InvokeKCLRunOptions
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
    const runtimeErrPtr = exports.kcl_malloc(RUNTIME_ERR_BUFFER_SIZE);
    exports[RUNTIME_ERR_FUNCTION_NAME](runtimeErrPtr, RUNTIME_ERR_BUFFER_SIZE);
    const [runtimeErrStr] = copyCStrFromWasmMemory(instance, runtimeErrPtr);
    exports.kcl_free(runtimeErrPtr, RUNTIME_ERR_BUFFER_SIZE);
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
    const runtimeErrPtr = exports.kcl_malloc(RUNTIME_ERR_BUFFER_SIZE);
    exports[RUNTIME_ERR_FUNCTION_NAME](runtimeErrPtr, RUNTIME_ERR_BUFFER_SIZE);
    const [runtimeErrStr] = copyCStrFromWasmMemory(instance, runtimeErrPtr);
    exports.kcl_free(runtimeErrPtr, RUNTIME_ERR_BUFFER_SIZE);
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
 * as a UTF-8 string, or an "ERROR:<message>" string on failure.
 *
 * The caller is responsible for encoding the `args` field according to
 * the corresponding `<Method>Args` message defined in `spec.proto`,
 * and for decoding the returned string as the corresponding
 * `<Method>Result` message.
 *
 * Note: `args` and the returned string travel through JS strings, so
 * bytes that are not valid UTF-8 (e.g. multi-byte protobuf length
 * prefixes) are corrupted by the round-trip. For byte-exact transport
 * of arbitrary protobuf messages use `invokeKCLCallNative` instead.
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
    const runtimeErrPtr = exports.kcl_malloc(RUNTIME_ERR_BUFFER_SIZE);
    exports[RUNTIME_ERR_FUNCTION_NAME](runtimeErrPtr, RUNTIME_ERR_BUFFER_SIZE);
    const [runtimeErrStr] = copyCStrFromWasmMemory(instance, runtimeErrPtr);
    exports.kcl_free(runtimeErrPtr, RUNTIME_ERR_BUFFER_SIZE);
    result = "ERROR:" + runtimeErrStr;
  } finally {
    exports.kcl_free(namePtr, namePtrLength);
    exports.kcl_free(argsPtr, argsAllocLength);
  }

  return result;
}

export interface CallNativeOptions {
  /**
   * Fully-qualified RPC name, e.g. `"KclService.Ping"`.
   * Must match one of the services declared in `spec/spec.proto`.
   */
  methodName: string;
  /**
   * Protobuf-encoded argument bytes for the RPC, exactly as defined by the
   * corresponding `<Method>Args` message in `spec.proto`.
   */
  args: Uint8Array;
  /**
   * Size in bytes of the result buffer allocated in WASM memory for the
   * call. The buffer must be large enough to hold the protobuf-encoded
   * `<Method>Result`; raise it for methods that return large payloads
   * (e.g. `LoadPackage` with the full AST index).
   *
   * @default 16 MiB
   */
  resultBufferSize?: number;
}

/**
 * Exported function to invoke any KCL service method by name through the
 * byte-oriented `call_native` dispatcher. Unlike `invokeKCLCall`, both the
 * `args` and the returned protobuf bytes are transported as raw
 * `Uint8Array`s, so messages of any size round-trip exactly (the string
 * based `kcl_call` entry point corrupts non-ASCII bytes).
 *
 * On success the returned bytes are the protobuf-encoded `<Method>Result`
 * message. On failure they are the UTF-8 bytes of an `"ERROR:<message>"`
 * string. WASM traps (e.g. a Rust panic, since the module is built with
 * `panic=abort`) are re-thrown as `Error` and render the instance
 * unusable; create a fresh one with `load()`.
 */
export function invokeKCLCallNative(
  instance: WebAssembly.Instance,
  opts: CallNativeOptions
): Uint8Array {
  const exports = instance.exports as Record<string, any>;
  const resultBufferSize =
    opts.resultBufferSize ?? DEFAULT_CALL_NATIVE_RESULT_BUFFER_SIZE;
  const [namePtr, nameContentLength, nameAllocLength] =
    copyRawBytesToWasmMemory(
      instance,
      new TextEncoder().encode(opts.methodName)
    );
  const [argsPtr, argsContentLength, argsAllocLength] =
    copyRawBytesToWasmMemory(instance, opts.args);
  const resultBufPtr = exports.kcl_malloc(resultBufferSize);
  let result = new Uint8Array(0);

  try {
    // `call_native` writes the protobuf-encoded result into the
    // caller-provided buffer and returns its length in bytes. The name
    // length must exclude the trailing NUL we wrote: the Rust side builds
    // a byte slice of exactly this length to dispatch the method.
    const resultLength = exports[CALL_NATIVE_FUNCTION_NAME](
      namePtr,
      nameContentLength,
      argsPtr,
      argsContentLength,
      resultBufPtr
    ) as number;
    if (resultLength > resultBufferSize) {
      throw new Error(
        `call_native result (${resultLength} bytes) exceeds the result buffer (${resultBufferSize} bytes)`
      );
    }
    // The wasm memory may have grown during the call, so this view must be
    // created only after it returns.
    const memoryBuffer = exports.memory.buffer as ArrayBuffer;
    result = new Uint8Array(memoryBuffer, resultBufPtr, resultLength).slice();
  } catch (error) {
    if (error instanceof Error && error.name === "RuntimeError") {
      throw new Error(
        `KCL WASM trap: ${error.message}. The WASM instance is built with panic=abort and is no longer usable after a trap; call load() to create a new one.`
      );
    }
    throw error;
  } finally {
    exports.kcl_free(namePtr, nameAllocLength);
    exports.kcl_free(argsPtr, argsAllocLength);
    exports.kcl_free(resultBufPtr, resultBufferSize);
  }

  return result;
}

/**
 * Exported function to invoke any KCL service method by name through the
 * service-handle dispatcher, which is the only wasm entry point that can
 * carry the plugin agent. The handle is created per call and destroyed
 * again, mirroring `call_with_plugin_agent` on the Rust side, so nothing
 * is left alive when the call returns.
 *
 * The agent pointer is never invoked: on `wasm32` the runtime routes every
 * plugin callout through the `env.kcl_plugin_invoke_json_wasm` import that
 * `load()` installs. All the non-zero value does is turn on
 * `load_plugins` in the KCL loader, so that `import kcl_plugin.<name>`
 * resolves instead of failing with "plugin mode is not enabled".
 *
 * Like {@link invokeKCLCallNative}, the returned bytes are the
 * protobuf-encoded `<Method>Result`, or the UTF-8 bytes of an
 * `"ERROR:<message>"` string on failure. Unlike it, the result is
 * allocated by the wasm side and therefore has no size limit — the
 * `resultBufferSize` option is ignored.
 */
export function invokeKCLCallNativeWithPluginAgent(
  instance: WebAssembly.Instance,
  opts: CallNativeOptions
): Uint8Array {
  const exports = instance.exports as Record<string, any>;
  const [namePtr, , nameAllocLength] = copyRawBytesToWasmMemory(
    instance,
    new TextEncoder().encode(opts.methodName)
  );
  const [argsPtr, argsContentLength, argsAllocLength] =
    copyRawBytesToWasmMemory(instance, opts.args);
  const outLenPtr = exports.kcl_malloc(4);
  // `kcl_service_call_with_length` reports the payload length through this
  // out-parameter rather than as its return value.
  const handle = exports[SERVICE_NEW_FUNCTION_NAME](
    PLUGIN_AGENT_SENTINEL
  ) as number;
  let result = new Uint8Array(0);

  try {
    const resultPtr = exports[SERVICE_CALL_FUNCTION_NAME](
      handle,
      namePtr,
      argsPtr,
      argsContentLength,
      outLenPtr
    ) as number;
    if (resultPtr === 0 || resultPtr === null) {
      result = new TextEncoder().encode(
        "ERROR:kcl_service_call_with_length returned a null pointer"
      );
    } else {
      const outLength = new DataView(
        exports.memory.buffer as ArrayBuffer
      ).getUint32(outLenPtr, true);
      // The memory may have grown during the call, so take this view now.
      result = new Uint8Array(
        exports.memory.buffer as ArrayBuffer,
        resultPtr,
        outLength
      ).slice();
      exports[SERVICE_FREE_STRING_FUNCTION_NAME](resultPtr);
    }
  } catch (error) {
    if (error instanceof Error && error.name === "RuntimeError") {
      throw new Error(
        `KCL WASM trap: ${error.message}. The WASM instance is built with panic=abort and is no longer usable after a trap; call load() to create a new one.`
      );
    }
    throw error;
  } finally {
    exports[SERVICE_DELETE_FUNCTION_NAME](handle);
    exports.kcl_free(namePtr, nameAllocLength);
    exports.kcl_free(argsPtr, argsAllocLength);
    exports.kcl_free(outLenPtr, 4);
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

/**
 * Copies raw bytes into wasm linear memory with a trailing NUL terminator,
 * returning the pointer, the content length (no NUL) and the allocation
 * length (content length + 1 for the NUL terminator).
 *
 * The caller uses `contentLength` as the logical length passed to wasm
 * functions that take a `*const u8, usize` pair so any trailing NUL we
 * wrote is never seen by the Rust side, and uses `allocationLength` when
 * freeing with `kcl_free`.
 */
function copyRawBytesToWasmMemory(
  instance: WebAssembly.Instance,
  bytes: Uint8Array
): [number, number, number] {
  const exports = instance.exports as Record<string, any>;
  const allocationLength = bytes.length + 1;
  const pointer = exports.kcl_malloc(allocationLength);
  const memoryBuffer = exports.memory.buffer as ArrayBuffer;
  const buffer = new Uint8Array(memoryBuffer, pointer, allocationLength);
  buffer.set(bytes);
  buffer[bytes.length] = 0;
  return [pointer, bytes.length, allocationLength];
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
