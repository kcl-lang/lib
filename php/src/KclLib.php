<?php

declare(strict_types=1);

namespace KclLib;

use Closure;
use FFI;
use FFI\CData;
use RuntimeException;
use Throwable;

/**
 * Thin FFI wrapper over the prebuilt `libkcl` shared library.
 *
 * The C ABI is a single universal dispatcher (see ffi/kcl_ffi.h, a verbatim
 * copy of c/include/kcl_ffi.h):
 *
 *     uintptr_t call_native(const uint8_t *name_ptr, uintptr_t name_len,
 *                           const uint8_t *args_ptr, uintptr_t args_len,
 *                           uint8_t *result_ptr);
 *
 * `name` is the fully-qualified RPC name (e.g. "KclService.ExecProgram"),
 * `args` is the protobuf-encoded request, and the response is copied into the
 * caller-supplied scratch buffer; the return value is the byte length
 * written. The response is *not* NUL-terminated. Every failure is reported
 * in-band as a payload starting with the literal "ERROR:" prefix
 * (docs/abi.md §4) — {@see KclLib::callNative()} returns the raw bytes,
 * prefix included, and the decoding layer turns it into a KclException.
 *
 * Locating `libkcl`:
 *   1. If the `KCL_PHP_LIB` environment variable is set, it wins. It may name
 *      the shared library file itself or a directory laid out like
 *      go/lib/<platform>/ (the platform file is picked from it).
 *   2. Otherwise the loader walks up from this file looking for
 *      go/lib/<platform>/libkcl.{so,dylib,dll} in the kcl-lang/lib checkout.
 *
 * This binding never builds Rust and never copies a binary into your project;
 * you point at the library the way Dart's `KCL_DART_LIB` does.
 *
 * The plugin-agent entry point (docs/abi.md §7) is exposed through the
 * service-handle API the prebuilt library ships (kcl_service_new and friends,
 * §6): a PHP callable is registered as the native plugin callback and every
 * call routes through the handle while an agent is bound. PHP's FFI creates
 * the C trampoline from the Closure at the call boundary; two consequences
 * are handled here — the trampoline's `const char *` return must be a real
 * C buffer (the reply buffer held by this instance), and a callback must
 * never throw, so agent exceptions are converted into a JSON error object.
 */
final class KclLib
{
    /**
     * Matches C/C++/Dart/.NET. The Rust side copies the response
     * unconditionally and its length can exceed the request size
     * unpredictably (e.g. ExecProgram JSON/YAML results for non-trivial
     * schemas). See docs/abi.md §5.
     */
    public const BUFFER_SIZE = 4 * 1024 * 1024;

    /**
     * The FFI definition, derived from ffi/kcl_ffi.h. PHP's FFI parser has
     * no C preprocessor, so the `#include`s, `extern "C"` block and the
     * weak-symbol attribute the header carries are spelled out here as the
     * resolved declarations they stand for; ffi/kcl_ffi.h remains the
     * verbatim reference this table mirrors.
     */
    private const CDEF = <<<'CDEF'
        typedef unsigned long uintptr_t;
        typedef unsigned long long uint64_t;
        typedef unsigned long size_t;
        typedef unsigned char uint8_t;

        uintptr_t call_native(const uint8_t *name_ptr,
                              uintptr_t name_len,
                              const uint8_t *args_ptr,
                              uintptr_t args_len,
                              uint8_t *result_ptr);

        typedef uintptr_t KclServiceHandle;
        typedef const char *(*plugin_agent_fn)(const char *method,
                                               const char *args_json,
                                               const char *kwargs_json);

        KclServiceHandle kcl_service_new(plugin_agent_fn plugin_agent);
        void kcl_service_delete(KclServiceHandle svc);
        const uint8_t* kcl_service_call_with_length(KclServiceHandle svc,
                                                    const char* method,
                                                    const uint8_t* args,
                                                    size_t args_len,
                                                    size_t* out_len);
        void kcl_service_free_string(const uint8_t* ptr);
        CDEF;

    /**
     * Room for one plugin reply. A KCL plugin result is a single JSON
     * document; results larger than this raise rather than truncate.
     */
    private const PLUGIN_REPLY_CAPACITY = 65536;

    private static ?KclLib $default = null;

    private FFI $ffi;
    private CData $scratch;

    /** @var array<int, CData> buffers handed to the native side, keyed to stay referenced */
    private array $keepAlive = [];

    /** @var array<int, array{int, Closure}> service handle + its trampoline, by agent id */
    private array $services = [];

    private function __construct(FFI $ffi)
    {
        $this->ffi = $ffi;
        $this->scratch = $ffi->new('uint8_t[' . self::BUFFER_SIZE . ']');
    }

    public function __destruct()
    {
        foreach ($this->services as [$service]) {
            $this->ffi->kcl_service_delete($service);
        }
        $this->services = [];
    }

    /**
     * The process-wide instance over the default library location.
     */
    public static function default(): self
    {
        return self::$default ??= self::open(self::defaultLibraryPath());
    }

    /**
     * Open `libkcl` from an explicit path: either the shared library file
     * itself or a directory containing the go/lib/<platform>/ layout.
     */
    public static function open(string $path): self
    {
        $lib = $path;
        if (!is_file($lib)) {
            if (is_dir($path)) {
                $candidate = $path . '/go/lib/' . self::platformFile();
                if (is_file($candidate)) {
                    $lib = $candidate;
                }
            }
            if (!is_file($lib)) {
                throw new RuntimeException(
                    "KCL_PHP_LIB does not point to a loadable libkcl: {$path}. " .
                    'Pass the shared library file (e.g. libkcl.dylib) or a directory ' .
                    'that contains the go/lib/<platform>/ subdirectory.'
                );
            }
        }

        return new self(FFI::cdef(self::CDEF, $lib));
    }

    /**
     * Resolve the platform file relative to go/lib/, e.g.
     * "darwin-arm64/libkcl.dylib". The arch suffix follows the Go embed dirs,
     * not the Rust target names, and Windows ships kcl.dll without the lib
     * prefix (docs/abi.md §8).
     */
    private static function platformFile(): string
    {
        $machine = php_uname('m');
        $arch = match (true) {
            $machine === 'arm64', $machine === 'aarch64' => 'arm64',
            $machine === 'x86_64', $machine === 'amd64' => 'amd64',
            default => throw new RuntimeException("unsupported CPU architecture: {$machine}"),
        };

        return match (PHP_OS_FAMILY) {
            'Darwin' => "darwin-{$arch}/libkcl.dylib",
            'Linux' => "linux-{$arch}/libkcl.so",
            'Windows' => "windows-{$arch}/kcl.dll",
            default => throw new RuntimeException('unsupported operating system: ' . PHP_OS_FAMILY),
        };
    }

    /**
     * Resolution order: the KCL_PHP_LIB environment variable, then the
     * enclosing kcl-lang/lib checkout found by walking up from this file.
     */
    private static function defaultLibraryPath(): string
    {
        $env = getenv('KCL_PHP_LIB');
        if (is_string($env) && $env !== '') {
            return $env;
        }

        $file = self::platformFile();
        $dir = __DIR__;
        while (true) {
            $candidate = $dir . '/go/lib/' . $file;
            if (is_file($candidate)) {
                return $candidate;
            }
            $parent = dirname($dir);
            if ($parent === $dir) {
                break;
            }
            $dir = $parent;
        }

        throw new RuntimeException(
            'libkcl was not found. Set KCL_PHP_LIB to the prebuilt shared library ' .
            'shipped under go/lib/<platform>/ in the kcl-lang/lib checkout ' .
            '(for example: KCL_PHP_LIB=/path/to/kcl-lang/lib/go/lib/darwin-arm64/libkcl.dylib).'
        );
    }

    /**
     * Calls `call_native` with the given RPC name and protobuf-encoded
     * request, returning the raw response bytes — including the "ERROR:"
     * prefix on failure, which the caller is responsible for decoding.
     */
    public function callNative(string $rpc, string $request): string
    {
        $nameBuf = $this->newBytes($rpc);
        $argsBuf = $this->newBytes($request);

        $length = $this->ffi->call_native(
            $nameBuf,
            strlen($rpc),
            $argsBuf,
            strlen($request),
            $this->scratch,
        );

        if ($length < 0 || $length > self::BUFFER_SIZE) {
            throw new RuntimeException(
                "libkcl returned an invalid response length: {$length} " .
                "(RPC={$rpc}, scratch=" . self::BUFFER_SIZE . 'B)'
            );
        }

        // Copy out of the scratch buffer before the next call overwrites it.
        return FFI::string($this->scratch, $length);
    }

    /**
     * Calls the given RPC through a service handle bound to `agent`, the
     * plugin callback the native side invokes whenever executed KCL code
     * calls `kcl_plugin.<module>.<method>` (docs/abi.md §7). The agent
     * receives the method name and the JSON-encoded arguments and returns
     * the JSON-encoded result. One handle is created per agent callable and
     * released with the instance.
     */
    public function callWithPluginAgent(string $rpc, string $request, callable $agent): string
    {
        $service = $this->serviceFor($agent);
        $argsBuf = $this->newBytes($request);
        $outLen = $this->ffi->new('size_t');

        $reply = $this->ffi->kcl_service_call_with_length(
            $service,
            $rpc,
            $argsBuf,
            strlen($request),
            FFI::addr($outLen),
        );
        if ($reply === null) {
            throw new RuntimeException("libkcl returned a null reply for {$rpc} through the service handle");
        }

        try {
            // The reply is always NUL-terminated, but the runtime only writes
            // `out_len` on the success path — its panic branch returns an
            // "ERROR:..." string without setting it. Recover the length from
            // the terminator in that case so the error still reaches the
            // caller (same recovery as the Dart binding).
            $length = $outLen->cdata;
            return $length > 0 ? FFI::string($reply, (int) $length) : FFI::string($reply);
        } finally {
            $this->ffi->kcl_service_free_string($reply);
        }
    }

    /**
     * Binds `agent` to a fresh service handle, or returns the cached one.
     * The trampoline Closure and its reply buffer are held here for as long
     * as the handle lives: letting them be collected would leave the native
     * side calling freed memory.
     */
    private function serviceFor(callable $agent): int
    {
        $id = is_object($agent) ? spl_object_id($agent) : 0;
        if (isset($this->services[$id])) {
            return $this->services[$id][0];
        }

        if (count($this->services) > 0) {
            throw new RuntimeException(
                'KclLib keeps one plugin agent per instance; open another KclLib for a second agent.'
            );
        }

        $replyBuf = $this->ffi->new('char[' . self::PLUGIN_REPLY_CAPACITY . ']');
        $trampoline = $this->wrapPluginAgent($agent, $replyBuf);
        // kcl_service_new returns the handle as an integer; keep it that way
        // — passing it back as a CData of the typedef would be coerced to a
        // scalar again at the call boundary.
        $service = $this->ffi->kcl_service_new($trampoline);
        if ($service === 0) {
            throw new RuntimeException('kcl_service_new returned a null service handle');
        }
        $this->keepAlive[] = $replyBuf;
        $this->services[$id] = [$service, $trampoline];

        return $service;
    }

    /**
     * Adapts a PHP callable to the C `plugin_agent_fn` shape. The native
     * side expects `const char *` back, so the JSON result is copied into a
     * C buffer whose pointer outlives the callback; the FFI trampoline is
     * not allowed to throw, so an agent exception becomes a JSON error
     * object the KCL runtime surfaces as a normal plugin failure.
     */
    private function wrapPluginAgent(callable $agent, CData $replyBuf): Closure
    {
        return function (string $method, string $args, string $kwargs) use ($agent, $replyBuf): CData {
            try {
                $json = (string) $agent($method, $args, $kwargs);
            } catch (Throwable $e) {
                $json = (string) json_encode(['error' => $e->getMessage()]);
            }

            $length = strlen($json);
            if ($length >= self::PLUGIN_REPLY_CAPACITY) {
                $json = (string) json_encode([
                    'error' => 'plugin result exceeds ' . self::PLUGIN_REPLY_CAPACITY . ' bytes',
                ]);
                $length = strlen($json);
            }

            FFI::memcpy($replyBuf, $json, $length);
            $replyBuf[$length] = "\0";

            return $this->ffi->cast('const char *', FFI::addr($replyBuf));
        };
    }

    /**
     * Copies a PHP string into a fresh native buffer. The buffer is kept
     * referenced by this instance until the call completes; FFI calls copy
     * or consume their inputs synchronously, so keeping them until the
     * instance is collected is always safe and never wrong.
     */
    private function newBytes(string $value): CData
    {
        $buffer = $this->ffi->new('uint8_t[' . max(1, strlen($value)) . ']');
        $length = strlen($value);
        for ($i = 0; $i < $length; $i++) {
            $buffer[$i] = ord($value[$i]);
        }
        $this->keepAlive[] = $buffer;

        return $buffer;
    }
}
