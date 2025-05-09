// Generated by the protocol buffer compiler. DO NOT EDIT!
// NO CHECKED-IN PROTOBUF GENCODE
// source: spec.proto

// Generated files should ignore deprecation warnings
@file:Suppress("DEPRECATION")
package com.kcl.api;

@kotlin.jvm.JvmName("-initializetestCaseInfo")
public inline fun testCaseInfo(block: com.kcl.api.TestCaseInfoKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.TestCaseInfo =
  com.kcl.api.TestCaseInfoKt.Dsl._create(com.kcl.api.Spec.TestCaseInfo.newBuilder()).apply { block() }._build()
/**
 * ```
 * Message representing information about a single test case.
 * ```
 *
 * Protobuf type `com.kcl.api.TestCaseInfo`
 */
public object TestCaseInfoKt {
  @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
  @com.google.protobuf.kotlin.ProtoDslMarker
  public class Dsl private constructor(
    private val _builder: com.kcl.api.Spec.TestCaseInfo.Builder
  ) {
    public companion object {
      @kotlin.jvm.JvmSynthetic
    @kotlin.PublishedApi
      internal fun _create(builder: com.kcl.api.Spec.TestCaseInfo.Builder): Dsl = Dsl(builder)
    }

    @kotlin.jvm.JvmSynthetic
  @kotlin.PublishedApi
    internal fun _build(): com.kcl.api.Spec.TestCaseInfo = _builder.build()

    /**
     * ```
     * Name of the test case.
     * ```
     *
     * `string name = 1;`
     */
    public var name: kotlin.String
      @JvmName("getName")
      get() = _builder.name
      @JvmName("setName")
      set(value) {
        _builder.name = value
      }
    /**
     * ```
     * Name of the test case.
     * ```
     *
     * `string name = 1;`
     */
    public fun clearName() {
      _builder.clearName()
    }

    /**
     * ```
     * Error message if any.
     * ```
     *
     * `string error = 2;`
     */
    public var error: kotlin.String
      @JvmName("getError")
      get() = _builder.error
      @JvmName("setError")
      set(value) {
        _builder.error = value
      }
    /**
     * ```
     * Error message if any.
     * ```
     *
     * `string error = 2;`
     */
    public fun clearError() {
      _builder.clearError()
    }

    /**
     * ```
     * Duration of the test case in microseconds.
     * ```
     *
     * `uint64 duration = 3;`
     */
    public var duration: kotlin.Long
      @JvmName("getDuration")
      get() = _builder.duration
      @JvmName("setDuration")
      set(value) {
        _builder.duration = value
      }
    /**
     * ```
     * Duration of the test case in microseconds.
     * ```
     *
     * `uint64 duration = 3;`
     */
    public fun clearDuration() {
      _builder.clearDuration()
    }

    /**
     * ```
     * Log message from the test case.
     * ```
     *
     * `string log_message = 4;`
     */
    public var logMessage: kotlin.String
      @JvmName("getLogMessage")
      get() = _builder.logMessage
      @JvmName("setLogMessage")
      set(value) {
        _builder.logMessage = value
      }
    /**
     * ```
     * Log message from the test case.
     * ```
     *
     * `string log_message = 4;`
     */
    public fun clearLogMessage() {
      _builder.clearLogMessage()
    }
  }
}
@kotlin.jvm.JvmSynthetic
public inline fun com.kcl.api.Spec.TestCaseInfo.copy(block: `com.kcl.api`.TestCaseInfoKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.TestCaseInfo =
  `com.kcl.api`.TestCaseInfoKt.Dsl._create(this.toBuilder()).apply { block() }._build()

