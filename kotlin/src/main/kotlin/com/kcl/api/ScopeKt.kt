// Generated by the protocol buffer compiler. DO NOT EDIT!
// NO CHECKED-IN PROTOBUF GENCODE
// source: spec.proto

// Generated files should ignore deprecation warnings
@file:Suppress("DEPRECATION")
package com.kcl.api;

@kotlin.jvm.JvmName("-initializescope")
public inline fun scope(block: com.kcl.api.ScopeKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.Scope =
  com.kcl.api.ScopeKt.Dsl._create(com.kcl.api.Spec.Scope.newBuilder()).apply { block() }._build()
/**
 * ```
 * Message representing a scope in KCL.
 * ```
 *
 * Protobuf type `com.kcl.api.Scope`
 */
public object ScopeKt {
  @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
  @com.google.protobuf.kotlin.ProtoDslMarker
  public class Dsl private constructor(
    private val _builder: com.kcl.api.Spec.Scope.Builder
  ) {
    public companion object {
      @kotlin.jvm.JvmSynthetic
      @kotlin.PublishedApi
      internal fun _create(builder: com.kcl.api.Spec.Scope.Builder): Dsl = Dsl(builder)
    }

    @kotlin.jvm.JvmSynthetic
    @kotlin.PublishedApi
    internal fun _build(): com.kcl.api.Spec.Scope = _builder.build()

    /**
     * ```
     * Type of the scope.
     * ```
     *
     * `string kind = 1;`
     */
    public var kind: kotlin.String
      @JvmName("getKind")
      get() = _builder.getKind()
      @JvmName("setKind")
      set(value) {
        _builder.setKind(value)
      }
    /**
     * ```
     * Type of the scope.
     * ```
     *
     * `string kind = 1;`
     */
    public fun clearKind() {
      _builder.clearKind()
    }

    /**
     * ```
     * Parent scope.
     * ```
     *
     * `.com.kcl.api.ScopeIndex parent = 2;`
     */
    public var parent: com.kcl.api.Spec.ScopeIndex
      @JvmName("getParent")
      get() = _builder.getParent()
      @JvmName("setParent")
      set(value) {
        _builder.setParent(value)
      }
    /**
     * ```
     * Parent scope.
     * ```
     *
     * `.com.kcl.api.ScopeIndex parent = 2;`
     */
    public fun clearParent() {
      _builder.clearParent()
    }
    /**
     * ```
     * Parent scope.
     * ```
     *
     * `.com.kcl.api.ScopeIndex parent = 2;`
     * @return Whether the parent field is set.
     */
    public fun hasParent(): kotlin.Boolean {
      return _builder.hasParent()
    }
    public val ScopeKt.Dsl.parentOrNull: com.kcl.api.Spec.ScopeIndex?
      get() = _builder.parentOrNull

    /**
     * ```
     * Owner of the scope.
     * ```
     *
     * `.com.kcl.api.SymbolIndex owner = 3;`
     */
    public var owner: com.kcl.api.Spec.SymbolIndex
      @JvmName("getOwner")
      get() = _builder.getOwner()
      @JvmName("setOwner")
      set(value) {
        _builder.setOwner(value)
      }
    /**
     * ```
     * Owner of the scope.
     * ```
     *
     * `.com.kcl.api.SymbolIndex owner = 3;`
     */
    public fun clearOwner() {
      _builder.clearOwner()
    }
    /**
     * ```
     * Owner of the scope.
     * ```
     *
     * `.com.kcl.api.SymbolIndex owner = 3;`
     * @return Whether the owner field is set.
     */
    public fun hasOwner(): kotlin.Boolean {
      return _builder.hasOwner()
    }
    public val ScopeKt.Dsl.ownerOrNull: com.kcl.api.Spec.SymbolIndex?
      get() = _builder.ownerOrNull

    /**
     * An uninstantiable, behaviorless type to represent the field in
     * generics.
     */
    @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
    public class ChildrenProxy private constructor() : com.google.protobuf.kotlin.DslProxy()
    /**
     * ```
     * Children of the scope.
     * ```
     *
     * `repeated .com.kcl.api.ScopeIndex children = 4;`
     */
     public val children: com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ScopeIndex, ChildrenProxy>
      @kotlin.jvm.JvmSynthetic
      get() = com.google.protobuf.kotlin.DslList(
        _builder.getChildrenList()
      )
    /**
     * ```
     * Children of the scope.
     * ```
     *
     * `repeated .com.kcl.api.ScopeIndex children = 4;`
     * @param value The children to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addChildren")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ScopeIndex, ChildrenProxy>.add(value: com.kcl.api.Spec.ScopeIndex) {
      _builder.addChildren(value)
    }
    /**
     * ```
     * Children of the scope.
     * ```
     *
     * `repeated .com.kcl.api.ScopeIndex children = 4;`
     * @param value The children to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignChildren")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ScopeIndex, ChildrenProxy>.plusAssign(value: com.kcl.api.Spec.ScopeIndex) {
      add(value)
    }
    /**
     * ```
     * Children of the scope.
     * ```
     *
     * `repeated .com.kcl.api.ScopeIndex children = 4;`
     * @param values The children to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addAllChildren")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ScopeIndex, ChildrenProxy>.addAll(values: kotlin.collections.Iterable<com.kcl.api.Spec.ScopeIndex>) {
      _builder.addAllChildren(values)
    }
    /**
     * ```
     * Children of the scope.
     * ```
     *
     * `repeated .com.kcl.api.ScopeIndex children = 4;`
     * @param values The children to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignAllChildren")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ScopeIndex, ChildrenProxy>.plusAssign(values: kotlin.collections.Iterable<com.kcl.api.Spec.ScopeIndex>) {
      addAll(values)
    }
    /**
     * ```
     * Children of the scope.
     * ```
     *
     * `repeated .com.kcl.api.ScopeIndex children = 4;`
     * @param index The index to set the value at.
     * @param value The children to set.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("setChildren")
    public operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ScopeIndex, ChildrenProxy>.set(index: kotlin.Int, value: com.kcl.api.Spec.ScopeIndex) {
      _builder.setChildren(index, value)
    }
    /**
     * ```
     * Children of the scope.
     * ```
     *
     * `repeated .com.kcl.api.ScopeIndex children = 4;`
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("clearChildren")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.ScopeIndex, ChildrenProxy>.clear() {
      _builder.clearChildren()
    }


    /**
     * An uninstantiable, behaviorless type to represent the field in
     * generics.
     */
    @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
    public class DefsProxy private constructor() : com.google.protobuf.kotlin.DslProxy()
    /**
     * ```
     * Definitions in the scope.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex defs = 5;`
     */
     public val defs: com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, DefsProxy>
      @kotlin.jvm.JvmSynthetic
      get() = com.google.protobuf.kotlin.DslList(
        _builder.getDefsList()
      )
    /**
     * ```
     * Definitions in the scope.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex defs = 5;`
     * @param value The defs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addDefs")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, DefsProxy>.add(value: com.kcl.api.Spec.SymbolIndex) {
      _builder.addDefs(value)
    }
    /**
     * ```
     * Definitions in the scope.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex defs = 5;`
     * @param value The defs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignDefs")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, DefsProxy>.plusAssign(value: com.kcl.api.Spec.SymbolIndex) {
      add(value)
    }
    /**
     * ```
     * Definitions in the scope.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex defs = 5;`
     * @param values The defs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addAllDefs")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, DefsProxy>.addAll(values: kotlin.collections.Iterable<com.kcl.api.Spec.SymbolIndex>) {
      _builder.addAllDefs(values)
    }
    /**
     * ```
     * Definitions in the scope.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex defs = 5;`
     * @param values The defs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignAllDefs")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, DefsProxy>.plusAssign(values: kotlin.collections.Iterable<com.kcl.api.Spec.SymbolIndex>) {
      addAll(values)
    }
    /**
     * ```
     * Definitions in the scope.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex defs = 5;`
     * @param index The index to set the value at.
     * @param value The defs to set.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("setDefs")
    public operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, DefsProxy>.set(index: kotlin.Int, value: com.kcl.api.Spec.SymbolIndex) {
      _builder.setDefs(index, value)
    }
    /**
     * ```
     * Definitions in the scope.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex defs = 5;`
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("clearDefs")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, DefsProxy>.clear() {
      _builder.clearDefs()
    }

  }
}
@kotlin.jvm.JvmSynthetic
public inline fun com.kcl.api.Spec.Scope.copy(block: `com.kcl.api`.ScopeKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.Scope =
  `com.kcl.api`.ScopeKt.Dsl._create(this.toBuilder()).apply { block() }._build()

public val com.kcl.api.Spec.ScopeOrBuilder.parentOrNull: com.kcl.api.Spec.ScopeIndex?
  get() = if (hasParent()) getParent() else null

public val com.kcl.api.Spec.ScopeOrBuilder.ownerOrNull: com.kcl.api.Spec.SymbolIndex?
  get() = if (hasOwner()) getOwner() else null
