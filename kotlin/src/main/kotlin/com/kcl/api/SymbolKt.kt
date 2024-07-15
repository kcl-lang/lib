// Generated by the protocol buffer compiler. DO NOT EDIT!
// NO CHECKED-IN PROTOBUF GENCODE
// source: spec.proto

// Generated files should ignore deprecation warnings
@file:Suppress("DEPRECATION")
package com.kcl.api;

@kotlin.jvm.JvmName("-initializesymbol")
public inline fun symbol(block: com.kcl.api.SymbolKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.Symbol =
  com.kcl.api.SymbolKt.Dsl._create(com.kcl.api.Spec.Symbol.newBuilder()).apply { block() }._build()
/**
 * ```
 * Message representing a symbol in KCL.
 * ```
 *
 * Protobuf type `com.kcl.api.Symbol`
 */
public object SymbolKt {
  @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
  @com.google.protobuf.kotlin.ProtoDslMarker
  public class Dsl private constructor(
    private val _builder: com.kcl.api.Spec.Symbol.Builder
  ) {
    public companion object {
      @kotlin.jvm.JvmSynthetic
      @kotlin.PublishedApi
      internal fun _create(builder: com.kcl.api.Spec.Symbol.Builder): Dsl = Dsl(builder)
    }

    @kotlin.jvm.JvmSynthetic
    @kotlin.PublishedApi
    internal fun _build(): com.kcl.api.Spec.Symbol = _builder.build()

    /**
     * ```
     * Type of the symbol.
     * ```
     *
     * `.com.kcl.api.KclType ty = 1;`
     */
    public var ty: com.kcl.api.Spec.KclType
      @JvmName("getTy")
      get() = _builder.getTy()
      @JvmName("setTy")
      set(value) {
        _builder.setTy(value)
      }
    /**
     * ```
     * Type of the symbol.
     * ```
     *
     * `.com.kcl.api.KclType ty = 1;`
     */
    public fun clearTy() {
      _builder.clearTy()
    }
    /**
     * ```
     * Type of the symbol.
     * ```
     *
     * `.com.kcl.api.KclType ty = 1;`
     * @return Whether the ty field is set.
     */
    public fun hasTy(): kotlin.Boolean {
      return _builder.hasTy()
    }
    public val SymbolKt.Dsl.tyOrNull: com.kcl.api.Spec.KclType?
      get() = _builder.tyOrNull

    /**
     * ```
     * Name of the symbol.
     * ```
     *
     * `string name = 2;`
     */
    public var name: kotlin.String
      @JvmName("getName")
      get() = _builder.getName()
      @JvmName("setName")
      set(value) {
        _builder.setName(value)
      }
    /**
     * ```
     * Name of the symbol.
     * ```
     *
     * `string name = 2;`
     */
    public fun clearName() {
      _builder.clearName()
    }

    /**
     * ```
     * Owner of the symbol.
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
     * Owner of the symbol.
     * ```
     *
     * `.com.kcl.api.SymbolIndex owner = 3;`
     */
    public fun clearOwner() {
      _builder.clearOwner()
    }
    /**
     * ```
     * Owner of the symbol.
     * ```
     *
     * `.com.kcl.api.SymbolIndex owner = 3;`
     * @return Whether the owner field is set.
     */
    public fun hasOwner(): kotlin.Boolean {
      return _builder.hasOwner()
    }
    public val SymbolKt.Dsl.ownerOrNull: com.kcl.api.Spec.SymbolIndex?
      get() = _builder.ownerOrNull

    /**
     * ```
     * Definition of the symbol.
     * ```
     *
     * `.com.kcl.api.SymbolIndex def = 4;`
     */
    public var def: com.kcl.api.Spec.SymbolIndex
      @JvmName("getDef")
      get() = _builder.getDef()
      @JvmName("setDef")
      set(value) {
        _builder.setDef(value)
      }
    /**
     * ```
     * Definition of the symbol.
     * ```
     *
     * `.com.kcl.api.SymbolIndex def = 4;`
     */
    public fun clearDef() {
      _builder.clearDef()
    }
    /**
     * ```
     * Definition of the symbol.
     * ```
     *
     * `.com.kcl.api.SymbolIndex def = 4;`
     * @return Whether the def field is set.
     */
    public fun hasDef(): kotlin.Boolean {
      return _builder.hasDef()
    }
    public val SymbolKt.Dsl.defOrNull: com.kcl.api.Spec.SymbolIndex?
      get() = _builder.defOrNull

    /**
     * An uninstantiable, behaviorless type to represent the field in
     * generics.
     */
    @kotlin.OptIn(com.google.protobuf.kotlin.OnlyForUseByGeneratedProtoCode::class)
    public class AttrsProxy private constructor() : com.google.protobuf.kotlin.DslProxy()
    /**
     * ```
     * Attributes of the symbol.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex attrs = 5;`
     */
     public val attrs: com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, AttrsProxy>
      @kotlin.jvm.JvmSynthetic
      get() = com.google.protobuf.kotlin.DslList(
        _builder.getAttrsList()
      )
    /**
     * ```
     * Attributes of the symbol.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex attrs = 5;`
     * @param value The attrs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addAttrs")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, AttrsProxy>.add(value: com.kcl.api.Spec.SymbolIndex) {
      _builder.addAttrs(value)
    }
    /**
     * ```
     * Attributes of the symbol.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex attrs = 5;`
     * @param value The attrs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignAttrs")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, AttrsProxy>.plusAssign(value: com.kcl.api.Spec.SymbolIndex) {
      add(value)
    }
    /**
     * ```
     * Attributes of the symbol.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex attrs = 5;`
     * @param values The attrs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("addAllAttrs")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, AttrsProxy>.addAll(values: kotlin.collections.Iterable<com.kcl.api.Spec.SymbolIndex>) {
      _builder.addAllAttrs(values)
    }
    /**
     * ```
     * Attributes of the symbol.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex attrs = 5;`
     * @param values The attrs to add.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("plusAssignAllAttrs")
    @Suppress("NOTHING_TO_INLINE")
    public inline operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, AttrsProxy>.plusAssign(values: kotlin.collections.Iterable<com.kcl.api.Spec.SymbolIndex>) {
      addAll(values)
    }
    /**
     * ```
     * Attributes of the symbol.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex attrs = 5;`
     * @param index The index to set the value at.
     * @param value The attrs to set.
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("setAttrs")
    public operator fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, AttrsProxy>.set(index: kotlin.Int, value: com.kcl.api.Spec.SymbolIndex) {
      _builder.setAttrs(index, value)
    }
    /**
     * ```
     * Attributes of the symbol.
     * ```
     *
     * `repeated .com.kcl.api.SymbolIndex attrs = 5;`
     */
    @kotlin.jvm.JvmSynthetic
    @kotlin.jvm.JvmName("clearAttrs")
    public fun com.google.protobuf.kotlin.DslList<com.kcl.api.Spec.SymbolIndex, AttrsProxy>.clear() {
      _builder.clearAttrs()
    }


    /**
     * ```
     * Flag indicating if the symbol is global.
     * ```
     *
     * `bool is_global = 6;`
     */
    public var isGlobal: kotlin.Boolean
      @JvmName("getIsGlobal")
      get() = _builder.getIsGlobal()
      @JvmName("setIsGlobal")
      set(value) {
        _builder.setIsGlobal(value)
      }
    /**
     * ```
     * Flag indicating if the symbol is global.
     * ```
     *
     * `bool is_global = 6;`
     */
    public fun clearIsGlobal() {
      _builder.clearIsGlobal()
    }
  }
}
@kotlin.jvm.JvmSynthetic
public inline fun com.kcl.api.Spec.Symbol.copy(block: `com.kcl.api`.SymbolKt.Dsl.() -> kotlin.Unit): com.kcl.api.Spec.Symbol =
  `com.kcl.api`.SymbolKt.Dsl._create(this.toBuilder()).apply { block() }._build()

public val com.kcl.api.Spec.SymbolOrBuilder.tyOrNull: com.kcl.api.Spec.KclType?
  get() = if (hasTy()) getTy() else null

public val com.kcl.api.Spec.SymbolOrBuilder.ownerOrNull: com.kcl.api.Spec.SymbolIndex?
  get() = if (hasOwner()) getOwner() else null

public val com.kcl.api.Spec.SymbolOrBuilder.defOrNull: com.kcl.api.Spec.SymbolIndex?
  get() = if (hasDef()) getDef() else null
