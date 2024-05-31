import WASI from "wasi-js";
import wasiBindings from "wasi-js/dist/bindings/node";
import { resolve } from "path";

const RUN_FUNCTION_NAME = "kcl_run";

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
  fs?: typeof import("fs");
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

/**
 * load a WASM
 * @param options
 * @returns
 */
export async function load(opts?: KCLWasmLoadOptions) {
  const options = opts ?? {};
  const fs: typeof import("fs") = options.fs ?? require("fs");

  let preopens: Record<string, string> = {};

  // preopen everything
  preopens["/"] = "/";
  preopens["."] = resolve(".");

  // add provided preopens
  preopens = {
    ...preopens,
    ...(options.preopens ?? {}),
  };

  // check if running in browser
  const bindings = {
    ...wasiBindings,
    fs,
  };

  const wasi = new WASI({
    bindings,
    env: {
      ...process.env,
      ...(options.env ?? {}),
    },
    preopens,
  });

  const env = {
    kclvm_plugin_invoke_json_wasm: (
      _method: number,
      _args: number,
      _kwargs: number
    ) => {
      // TODO
      return 0;
    },
  };

  const importObject = {
    wasi_snapshot_preview1: wasi.wasiImport,
    env: env,
    ...(options.imports ?? {}),
  } as any;

  const binary =
    options.data ??
    new Uint8Array(
      await fs.promises.readFile(resolve(__dirname, "../kcl.wasm"))
    );
  const mod = new WebAssembly.Module(binary);

  const instance = new WebAssembly.Instance(mod, importObject);
  wasi.start(instance);

  return instance;
}

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
  const resultPtr = exports[RUN_FUNCTION_NAME](filenamePtr, sourcePtr);
  const [resultStr, resultPtrLength] = copyCStrFromWasmMemory(
    instance,
    resultPtr
  );
  exports.kcl_free(filenamePtr, filenamePtrLength);
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
    encodedString.length
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
