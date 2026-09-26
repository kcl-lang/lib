package com.kcl

import com.kcl.api.Spec
import com.kcl.api.Spec.ExecProgramArgs

/**
 * Functional option accepted by the [Kcl] facade entry points, mirroring
 * kcl-go's `Option`. Each option contributes a slice of state that is merged
 * into a shared [KclOptionBag] before the [ExecProgramArgs] proto is
 * materialised. Build options with the `with*` factories on [Kcl], or pass a
 * trailing configuration lambda: `Kcl.run(code) { overrides += "a=1" }`.
 */
fun interface KclOption {
    fun apply(bag: KclOptionBag)
}

/**
 * Mutable bag of merged option state, mirroring the union of fields the
 * kcl-go `Option` struct can populate. Constructor is internal; users
 * configure it through option factories or the entry-point DSL lambdas.
 */
class KclOptionBag internal constructor() {
    var workDir: String? = null
    val kFilenames: MutableList<String> = mutableListOf()
    val kCodes: MutableList<String> = mutableListOf()
    val args: MutableList<Spec.Argument> = mutableListOf()
    val overrides: MutableList<String> = mutableListOf()
    val selectors: MutableList<String> = mutableListOf()
    val externalPkgs: MutableList<Spec.ExternalPkg> = mutableListOf()
    var settingsPath: String? = null
    var disableNone: Boolean? = null
    var sortKeys: Boolean? = null
    var showHidden: Boolean? = null
    var includeSchemaTypePath: Boolean? = null
    var strictRangeCheck: Boolean? = null
    var verbose: Int? = null
    var debug: Int? = null

    /**
     * Materialise the bag into an [ExecProgramArgs] proto. When a settings
     * file was recorded it is parsed first and provides the base set of
     * fields; explicitly populated fields are merged on top with kcl-go's
     * `Merge` semantics: repeated fields append, non-empty scalars overwrite
     * (last wins), and plain boolean fields only propagate when `true`.
     */
    internal fun toExecProgramArgs(): ExecProgramArgs {
        val builder = ExecProgramArgs.newBuilder()
        val baseWorkDir = workDir?.takeUnless { it.isEmpty() } ?: "."
        settingsPath?.takeUnless { it.isEmpty() }?.let { path ->
            KclSettingsFile.load(path).applyTo(builder, baseWorkDir)
        }
        workDir?.takeUnless { it.isEmpty() }?.let { builder.workDir = it }
        builder.addAllKFilenameList(kFilenames)
        builder.addAllKCodeList(kCodes)
        builder.addAllArgs(args)
        builder.addAllOverrides(overrides)
        builder.addAllPathSelector(selectors)
        builder.addAllExternalPkgs(externalPkgs)
        if (disableNone == true) builder.disableNone = true
        if (sortKeys == true) builder.sortKeys = true
        if (showHidden == true) builder.showHidden = true
        if (includeSchemaTypePath == true) builder.includeSchemaTypePath = true
        if (strictRangeCheck == true) builder.strictRangeCheck = true
        verbose?.takeIf { it > 0 }?.let { builder.verbose = it }
        debug?.takeIf { it != 0 }?.let { builder.debug = it }
        return builder.build()
    }
}
