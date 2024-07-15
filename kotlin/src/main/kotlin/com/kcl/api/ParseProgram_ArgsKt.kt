// Generated by the protocol buffer compiler. DO NOT EDIT!
// NO CHECKED-IN PROTOBUF GENCODE
// source: spec.proto

// Generated files should ignore deprecation warnings
@file:Suppress("DEPRECATION")
package com.kcl.api;

@kotlin.jvm.JvmName("-initializeparseProgramArgs")
public inline fun parseProgramArgs(block: com.kcl.api.ParseProgram_ArgsKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.ParseProgram_Args =
  com.kcl.api.ParseProgram_ArgsKt.Dsl._create(com.kcl.api.Spec.ParseProgram_Args.newBuilder()).apply { block() }._build()
/**
 * ```
 * Message for parse program request arguments.
 * ```
 *
 * Protobuf type `com.kcl.api.ParseProgram_Args`
 */
public object ParseProgram_ArgsKt {
  @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
  @com.google.protobuf.kotlin.ProtoDslMarker
  public class Dsl private constructor(
    private val _builder: com.kcl.api.Spec.ParseProgram_Args.Builder
  ) {
    public companion object {
      @kotlin.jvm.JvmSynthetic
      @kotlin.PublishedApi
      internal fun _create(builder: com.kcl.api.Spec.ParseProgram_Args.Builder): Dsl = Dsl(builder)
    }

    @kotlin.jvm.JvmSynthetic
    @kotlin.PublishedApi
    internal fun _build(): com.kcl.api.Spec.ParseProgram_Args = _builder.build()

    /**
     * An uninstantiable, behaviorless type to represent the field in
     * generics.
     */
    @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
    public class PathsProxy private constructor() : com.google.protobuf.kotlin.DslProxy()
    /**
     * ```
     * Paths of the program files to be parsed.
     * ```
     *
     * `repeated string paths = 1;`
     * @return A list containing the paths.
     */
    public val paths: com.google.protobuf.kotlin.DslList<kotlin.String, PathsProxy>
      @kotlin.jvm.JvmSynthetic
      get() = com.google.protobuf.kotlin.DslList(
        _builder.getPathsList()
      )
    /**
     * ```
     * Paths of the program files to be parsed.
     * ```
     *
     * `repeated string paths = 1;`
     * @param value The paths to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addPaths")
    public fun com.google.protobuf.kotlin.DslList<kotlin.String, PathsProxy>.add(value: kotlin.String) {
      _builder.addPaths(value)
    }
    /**
     * ```
     * Paths of the program files to be parsed.
     * ```
     *
     * `repeated string paths = 1;`
     * @param value The paths to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignPaths")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<kotlin.String, PathsProxy>.plusAssign(value: kotlin.String) {
      add(value)
    }
    /**
     * ```
     * Paths of the program files to be parsed.
     * ```
     *
     * `repeated string paths = 1;`
     * @param values The paths to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addAllPaths")
    public fun com.google.protobuf.kotlin.DslList<kotlin.String, PathsProxy>.addAll(values: kotlin.collections.Iterable<kotlin.String>) {
      _builder.addAllPaths(values)
    }
    /**
     * ```
     * Paths of the program files to be parsed.
     * ```
     *
     * `repeated string paths = 1;`
     * @param values The paths to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignAllPaths")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<kotlin.String, PathsProxy>.plusAssign(values: kotlin.collections.Iterable<kotlin.String>) {
      addAll(values)
    }
    /**
     * ```
     * Paths of the program files to be parsed.
     * ```
     *
     * `repeated string paths = 1;`
     * @param index The index to set the value at.
     * @param value The paths to set.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("setPaths")
    public operator fun com.google.protobuf.kotlin.DslList<kotlin.String, PathsProxy>.set(index: kotlin.Int, value: kotlin.String) {
      _builder.setPaths(index, value)
    }/**
     * ```
     * Paths of the program files to be parsed.
     * ```
     *
     * `repeated string paths = 1;`
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("clearPaths")
    public fun com.google.protobuf.kotlin.DslList<kotlin.String, PathsProxy>.clear() {
      _builder.clearPaths()
    }
    /**
     * An uninstantiable, behaviorless type to represent the field in
     * generics.
     */
    @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
    public class SourcesProxy private constructor() : com.google.protobuf.kotlin.DslProxy()
    /**
     * ```
     * Source codes to be parsed.
     * ```
     *
     * `repeated string sources = 2;`
     * @return A list containing the sources.
     */
    public val sources: com.google.protobuf.kotlin.DslList<kotlin.String, SourcesProxy>
      @kotlin.jvm.JvmSynthetic
      get() = com.google.protobuf.kotlin.DslList(
        _builder.getSourcesList()
      )
    /**
     * ```
     * Source codes to be parsed.
     * ```
     *
     * `repeated string sources = 2;`
     * @param value The sources to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addSources")
    public fun com.google.protobuf.kotlin.DslList<kotlin.String, SourcesProxy>.add(value: kotlin.String) {
      _builder.addSources(value)
    }
    /**
     * ```
     * Source codes to be parsed.
     * ```
     *
     * `repeated string sources = 2;`
     * @param value The sources to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignSources")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<kotlin.String, SourcesProxy>.plusAssign(value: kotlin.String) {
      add(value)
    }
    /**
     * ```
     * Source codes to be parsed.
     * ```
     *
     * `repeated string sources = 2;`
     * @param values The sources to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addAllSources")
    public fun com.google.protobuf.kotlin.DslList<kotlin.String, SourcesProxy>.addAll(values: kotlin.collections.Iterable<kotlin.String>) {
      _builder.addAllSources(values)
    }
    /**
     * ```
     * Source codes to be parsed.
     * ```
     *
     * `repeated string sources = 2;`
     * @param values The sources to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignAllSources")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<kotlin.String, SourcesProxy>.plusAssign(values: kotlin.collections.Iterable<kotlin.String>) {
      addAll(values)
    }
    /**
     * ```
     * Source codes to be parsed.
     * ```
     *
     * `repeated string sources = 2;`
     * @param index The index to set the value at.
     * @param value The sources to set.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("setSources")
    public operator fun com.google.protobuf.kotlin.DslList<kotlin.String, SourcesProxy>.set(index: kotlin.Int, value: kotlin.String) {
      _builder.setSources(index, value)
    }/**
     * ```
     * Source codes to be parsed.
     * ```
     *
     * `repeated string sources = 2;`
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("clearSources")
    public fun com.google.protobuf.kotlin.DslList<kotlin.String, SourcesProxy>.clear() {
      _builder.clearSources()
    }
    /**
     * An uninstantiable, behaviorless type to represent the field in
     * generics.
     */
    @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
    public class ExternalPkgsProxy private constructor() : com.google.protobuf.kotlin.DslProxy()
    /**
     * ```
     * External packages path.
     * ```
     *
     * `repeated .com.kcl.api.ExternalPkg external_pkgs = 3;`
     */
     public val externalPkgs: com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ExternalPkg, ExternalPkgsProxy>
      @kotlin.jvm.JvmSynthetic
      get() = com.google.protobuf.kotlin.DslList(
        _builder.getExternalPkgsList()
      )
    /**
     * ```
     * External packages path.
     * ```
     *
     * `repeated .com.kcl.api.ExternalPkg external_pkgs = 3;`
     * @param value The externalPkgs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addExternalPkgs")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ExternalPkg, ExternalPkgsProxy>.add(value: com.kcl.api.Spec.ExternalPkg) {
      _builder.addExternalPkgs(value)
    }
    /**
     * ```
     * External packages path.
     * ```
     *
     * `repeated .com.kcl.api.ExternalPkg external_pkgs = 3;`
     * @param value The externalPkgs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignExternalPkgs")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ExternalPkg, ExternalPkgsProxy>.plusAssign(value: com.kcl.api.Spec.ExternalPkg) {
      add(value)
    }
    /**
     * ```
     * External packages path.
     * ```
     *
     * `repeated .com.kcl.api.ExternalPkg external_pkgs = 3;`
     * @param values The externalPkgs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addAllExternalPkgs")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ExternalPkg, ExternalPkgsProxy>.addAll(values: kotlin.collections.Iterable<com.kcl.api.Spec.ExternalPkg>) {
      _builder.addAllExternalPkgs(values)
    }
    /**
     * ```
     * External packages path.
     * ```
     *
     * `repeated .com.kcl.api.ExternalPkg external_pkgs = 3;`
     * @param values The externalPkgs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignAllExternalPkgs")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ExternalPkg, ExternalPkgsProxy>.plusAssign(values: kotlin.collections.Iterable<com.kcl.api.Spec.ExternalPkg>) {
      addAll(values)
    }
    /**
     * ```
     * External packages path.
     * ```
     *
     * `repeated .com.kcl.api.ExternalPkg external_pkgs = 3;`
     * @param index The index to set the value at.
     * @param value The externalPkgs to set.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("setExternalPkgs")
    public operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ExternalPkg, ExternalPkgsProxy>.set(index: kotlin.Int, value: com.kcl.api.Spec.ExternalPkg) {
      _builder.setExternalPkgs(index, value)
    }
    /**
     * ```
     * External packages path.
     * ```
     *
     * `repeated .com.kcl.api.ExternalPkg external_pkgs = 3;`
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("clearExternalPkgs")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ExternalPkg, ExternalPkgsProxy>.clear() {
      _builder.clearExternalPkgs()
    }

  }
}
@kotlin.jvm.JvmSynthetic
public inline fun com.kcl.api.Spec.ParseProgram_Args.copy(block: `com.kcl.api`.ParseProgram_ArgsKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.ParseProgram_Args =
  `com.kcl.api`.ParseProgram_ArgsKt.Dsl._create(this.toBuilder()).apply { block() }._build()
