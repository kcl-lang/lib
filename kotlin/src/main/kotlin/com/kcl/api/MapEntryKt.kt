// Generated by the protocol buffer compiler. DO NOT EDIT!
// NO CHECKED-IN PROTOBUF GENCODE
// source: spec.proto

// Generated files should ignore deprecation warnings
@file:Suppress("DEPRECATION")
package com.kcl.api;

@kotlin.jvm.JvmName("-initializemapEntry")
public inline fun mapEntry(block: com.kcl.api.MapEntryKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.MapEntry =
  com.kcl.api.MapEntryKt.Dsl._create(com.kcl.api.Spec.MapEntry.newBuilder()).apply { block() }._build()
/**
 * ```
 * Message representing a map entry.
 * ```
 *
 * Protobuf type `com.kcl.api.MapEntry`
 */
public object MapEntryKt {
  @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
  @com.google.protobuf.kotlin.ProtoDslMarker
  public class Dsl private constructor(
    private val _builder: com.kcl.api.Spec.MapEntry.Builder
  ) {
    public companion object {
      @kotlin.jvm.JvmSynthetic
      @kotlin.PublishedApi
      internal fun _create(builder: com.kcl.api.Spec.MapEntry.Builder): Dsl = Dsl(builder)
    }

    @kotlin.jvm.JvmSynthetic
    @kotlin.PublishedApi
    internal fun _build(): com.kcl.api.Spec.MapEntry = _builder.build()

    /**
     * ```
     * Key of the map entry.
     * ```
     *
     * `string key = 1;`
     */
    public var key: kotlin.String
      @JvmName("getKey")
      get() = _builder.getKey()
      @JvmName("setKey")
      set(value) {
        _builder.setKey(value)
      }
    /**
     * ```
     * Key of the map entry.
     * ```
     *
     * `string key = 1;`
     */
    public fun clearKey() {
      _builder.clearKey()
    }

    /**
     * ```
     * Value of the map entry.
     * ```
     *
     * `.com.kcl.api.Variable value = 2;`
     */
    public var value: com.kcl.api.Spec.Variable
      @JvmName("getValue")
      get() = _builder.getValue()
      @JvmName("setValue")
      set(value) {
        _builder.setValue(value)
      }
    /**
     * ```
     * Value of the map entry.
     * ```
     *
     * `.com.kcl.api.Variable value = 2;`
     */
    public fun clearValue() {
      _builder.clearValue()
    }
    /**
     * ```
     * Value of the map entry.
     * ```
     *
     * `.com.kcl.api.Variable value = 2;`
     * @return Whether the value field is set.
     */
    public fun hasValue(): kotlin.Boolean {
      return _builder.hasValue()
    }
    public val MapEntryKt.Dsl.valueOrNull: com.kcl.api.Spec.Variable?
      get() = _builder.valueOrNull
  }
}
@kotlin.jvm.JvmSynthetic
public inline fun com.kcl.api.Spec.MapEntry.copy(block: `com.kcl.api`.MapEntryKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.MapEntry =
  `com.kcl.api`.MapEntryKt.Dsl._create(this.toBuilder()).apply { block() }._build()

public val com.kcl.api.Spec.MapEntryOrBuilder.valueOrNull: com.kcl.api.Spec.Variable?
  get() = if (hasValue()) getValue() else null
