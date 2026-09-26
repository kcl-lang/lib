package com.kcl;

/**
 * Exception thrown by the {@link Kcl} facade when a run fails. Mirrors the
 * error value returned by kcl-go's {@code ExecResultToKCLResult}: it is
 * raised both for transport-level failures (the native call itself threw)
 * and for runtime-reported failures ({@code ExecProgramResult.err_message}
 * is non-empty), as well as for invalid option combinations such as a
 * missing settings file or no input at all.
 *
 * <p>
 * Like the rest of the facade it is unchecked: callers may handle it where
 * recovery is possible (e.g. surfacing a compile error to an end user) and
 * let it propagate where a failed run is unrecoverable.
 */
public class KclException extends RuntimeException {
    private static final long serialVersionUID = 1L;

    public KclException(String message) {
        super(message);
    }

    public KclException(String message, Throwable cause) {
        super(message, cause);
    }
}
