package com.kcl

/**
 * Exception thrown by the [Kcl] facade when a run fails: transport-level
 * failures (the native call itself threw), runtime-reported failures
 * (`ExecProgramResult.err_message` non-empty), and invalid option
 * combinations such as a missing settings file or no input at all.
 */
class KclException(message: String, cause: Throwable? = null) : RuntimeException(message, cause)
