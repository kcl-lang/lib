// Generated by the protocol buffer compiler. DO NOT EDIT!
// NO CHECKED-IN PROTOBUF GENCODE
// source: spec.proto

// Generated files should ignore deprecation warnings
@file:Suppress("DEPRECATION")
package com.kcl.api;

@kotlin.jvm.JvmName("-initializerenameCodeResult")
public inline fun renameCodeResult(block: com.kcl.api.RenameCode_ResultKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.RenameCode_Result =
  com.kcl.api.RenameCode_ResultKt.Dsl._create(com.kcl.api.Spec.RenameCode_Result.newBuilder()).apply { block() }._build()
/**
 * ```
 * Message for rename code response.
 * ```
 *
 * Protobuf type `com.kcl.api.RenameCode_Result`
 */
public object RenameCode_ResultKt {
  @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
  @com.google.protobuf.kotlin.ProtoDslMarker
  public class Dsl private constructor(
    private val _builder: com.kcl.api.Spec.RenameCode_Result.Builder
  ) {
    public companion object {
      @kotlin.jvm.JvmSynthetic
      @kotlin.PublishedApi
      internal fun _create(builder: com.kcl.api.Spec.RenameCode_Result.Builder): Dsl = Dsl(builder)
    }

    @kotlin.jvm.JvmSynthetic
    @kotlin.PublishedApi
    internal fun _build(): com.kcl.api.Spec.RenameCode_Result = _builder.build()

    /**
     * An uninstantiable, behaviorless type to represent the field in
     * generics.
     */
    @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
    public class ChangedCodesProxy private constructor() : com.google.protobuf.kotlin.DslProxy()
    /**
     * ```
     * Map of changed code with filename as key and modified code as value.
     * ```
     *
     * `map<string, string> changed_codes = 1;`
     */
     public val changedCodes: com.google.protobuf.kotlin.DslMap<kotlin.String, kotlin.String, ChangedCodesProxy>
      @kotlin.jvm.JvmSynthetic
      @JvmName("getChangedCodesMap")
      get() = com.google.protobuf.kotlin.DslMap(
        _builder.getChangedCodesMap()
      )
    /**
     * ```
     * Map of changed code with filename as key and modified code as value.
     * ```
     *
     * `map<string, string> changed_codes = 1;`
     */
    @JvmName("putChangedCodes")
    public fun com.google.protobuf.kotlin.DslMap<kotlin.String, kotlin.String, ChangedCodesProxy>
      .put(key: kotlin.String, value: kotlin.String) {
         _builder.putChangedCodes(key, value)
       }
    /**
     * ```
     * Map of changed code with filename as key and modified code as value.
     * ```
     *
     * `map<string, string> changed_codes = 1;`
     */
    @kotlin.jvm.JvmSynthetic
    @JvmName("setChangedCodes")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslMap<kotlin.String, kotlin.String, ChangedCodesProxy>
      .set(key: kotlin.String, value: kotlin.String) {
         put(key, value)
       }
    /**
     * ```
     * Map of changed code with filename as key and modified code as value.
     * ```
     *
     * `map<string, string> changed_codes = 1;`
     */
    @kotlin.jvm.JvmSynthetic
    @JvmName("removeChangedCodes")
    public fun com.google.protobuf.kotlin.DslMap<kotlin.String, kotlin.String, ChangedCodesProxy>
      .remove(key: kotlin.String) {
         _builder.removeChangedCodes(key)
       }
    /**
     * ```
     * Map of changed code with filename as key and modified code as value.
     * ```
     *
     * `map<string, string> changed_codes = 1;`
     */
    @kotlin.jvm.JvmSynthetic
    @JvmName("putAllChangedCodes")
    public fun com.google.protobuf.kotlin.DslMap<kotlin.String, kotlin.String, ChangedCodesProxy>
      .putAll(map: kotlin.collections.Map<kotlin.String, kotlin.String>) {
         _builder.putAllChangedCodes(map)
       }
    /**
     * ```
     * Map of changed code with filename as key and modified code as value.
     * ```
     *
     * `map<string, string> changed_codes = 1;`
     */
    @kotlin.jvm.JvmSynthetic
    @JvmName("clearChangedCodes")
    public fun com.google.protobuf.kotlin.DslMap<kotlin.String, kotlin.String, ChangedCodesProxy>
      .clear() {
         _builder.clearChangedCodes()
       }
  }
}
@kotlin.jvm.JvmSynthetic
public inline fun com.kcl.api.Spec.RenameCode_Result.copy(block: `com.kcl.api`.RenameCode_ResultKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.RenameCode_Result =
  `com.kcl.api`.RenameCode_ResultKt.Dsl._create(this.toBuilder()).apply { block() }._build()
