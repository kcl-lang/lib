package com.kcl

import com.fasterxml.jackson.databind.MappingIterator
import com.kcl.api.API
import com.kcl.api.Spec.Argument
import com.kcl.api.Spec.ExecProgramArgs
import com.kcl.api.Spec.ExecProgramResult
import com.kcl.api.Spec.ExternalPkg
import java.io.IOException

/**
 * High-level entry points for evaluating KCL, modelled on the capabilities
 * of kcl-go's `pkg/kcl` with a Kotlin-first shape: [run] evaluates in-memory
 * source, [runFiles] evaluates files, every entry point takes either
 * [KclOption] factories or a trailing configuration lambda, and failures
 * always raise [KclException] rather than returning error values.
 *
 * ```kotlin
 * val result = Kcl.run("a = 1\nb = {c = \"x\"}") {
 *     overrides += "a=2"
 * }
 * val doc = Kcl.runFiles(listOf("main.k"), Kcl.withWorkDir("."))
 * ```
 */
object Kcl {

    // ------------------------------------------------------------------
    // Entry points
    // ------------------------------------------------------------------

    /**
     * Evaluate the in-memory KCL source [code] with optional [options].
     * Mirrors kcl-go's `Run` combined with `WithCode`.
     *
     * @throws KclException when no input is given, the settings file is
     *     invalid, or the run fails (transport error or non-empty
     *     `err_message`)
     */
    @JvmStatic
    fun run(code: String, vararg options: KclOption): KCLResultList =
        exec(options.asList(), kCodes = listOf(code))

    /** DSL variant of [run] with a trailing configuration lambda. */
    fun run(code: String, configure: KclOptionBag.() -> Unit): KCLResultList =
        run(code, KclOption { bag -> bag.apply(configure) })

    /** Evaluate the KCL file at [path]. Single-file variant of [runFiles]. */
    @JvmStatic
    fun runFiles(path: String, vararg options: KclOption): KCLResultList =
        runFiles(listOf(path), *options)

    /**
     * Evaluate the KCL files in [paths] with optional [options]. Mirrors
     * kcl-go's `RunFiles`.
     */
    @JvmStatic
    fun runFiles(paths: List<String>, vararg options: KclOption): KCLResultList =
        exec(options.asList(), kFilenames = paths)

    /** DSL variant of [runFiles] with a trailing configuration lambda. */
    fun runFiles(paths: List<String>, configure: KclOptionBag.() -> Unit): KCLResultList =
        runFiles(paths, KclOption { bag -> bag.apply(configure) })

    /**
     * Evaluate with only [options] (no seeded input); specify files or code
     * through [withKFilenames]/[withCode] or a settings file. Equivalent to
     * kcl-go's `RunWithOpts`.
     *
     * @throws KclException when no input is given, the settings file is
     *     invalid, or the run fails
     */
    @JvmStatic
    fun runWithOpts(vararg options: KclOption): KCLResultList = exec(options.asList())

    // ------------------------------------------------------------------
    // Option factories
    // ------------------------------------------------------------------

    /** Append in-memory KCL source codes to the program (kcl-go `WithCode`). */
    fun withCode(vararg codes: String): KclOption = KclOption { it.kCodes += codes }

    /** Append KCL file paths to the program (kcl-go `WithKFilenames`). */
    fun withKFilenames(vararg paths: String): KclOption = KclOption { it.kFilenames += paths }

    /** Set the working directory for the evaluation (kcl-go `WithWorkDir`). */
    fun withWorkDir(workDir: String): KclOption = KclOption { it.workDir = workDir }

    /** Set override specs (the `-O` flag). */
    fun withOverrides(vararg specs: String): KclOption = KclOption { it.overrides += specs }

    /** Set override specs (the `-O` flag). */
    fun withOverrides(specs: List<String>): KclOption = KclOption { it.overrides += specs }

    /** Set path selectors (the `-S` flag). */
    fun withSelectors(vararg selectors: String): KclOption = KclOption { it.selectors += selectors }

    /** Set path selectors (the `-S` flag). */
    fun withSelectors(selectors: List<String>): KclOption = KclOption { it.selectors += selectors }

    /**
     * Record a `kcl.yaml` settings file whose fields provide the base program
     * arguments (kcl-go `WithSettings`). Explicit `with*` options override
     * the file. An unreadable or invalid file fails the run.
     */
    fun withSettings(path: String): KclOption = KclOption { it.settingsPath = path }

    /**
     * Toggle `disable_none` (the `-n` flag). Like kcl-go's `Merge`, only
     * `true` takes effect; `false` leaves the current value untouched.
     */
    fun withDisableNone(disableNone: Boolean): KclOption = KclOption { it.disableNone = disableNone }

    /** Toggle `sort_keys` (the `-k` flag); only `true` takes effect. */
    fun withSortKeys(sortKeys: Boolean): KclOption = KclOption { it.sortKeys = sortKeys }

    /** Toggle `show_hidden` (the `-H` flag); only `true` takes effect. */
    fun withShowHidden(showHidden: Boolean): KclOption = KclOption { it.showHidden = showHidden }

    /** Toggle `include_schema_type_path`; only `true` takes effect. */
    fun withIncludeSchemaTypePath(include: Boolean): KclOption =
        KclOption { it.includeSchemaTypePath = include }

    /** Toggle `strict_range_check`; only `true` takes effect. */
    fun withStrictRangeCheck(strict: Boolean): KclOption = KclOption { it.strictRangeCheck = strict }

    /** Attach external packages (the `-E` flag) as package name to path entries. */
    fun withExternalPkgs(nameToPath: Map<String, String>): KclOption = KclOption { bag ->
        bag.externalPkgs += nameToPath.map { (name, path) ->
            ExternalPkg.newBuilder().setPkgName(name).setPkgPath(path).build()
        }
    }

    /** Set `option(...)` arguments (the `-D` flag). */
    fun withArgs(nameToValue: Map<String, String>): KclOption = KclOption { bag ->
        bag.args += nameToValue.map { (name, value) ->
            Argument.newBuilder().setName(name).setValue(value).build()
        }
    }

    /** Set the verbose level; only positive values take effect. */
    fun withVerbose(verbose: Int): KclOption = KclOption { it.verbose = verbose }

    /** Set the debug level; only non-zero values take effect. */
    fun withDebug(debug: Boolean): KclOption = KclOption { it.debug = if (debug) 1 else 0 }

    // ------------------------------------------------------------------
    // Internal plumbing
    // ------------------------------------------------------------------

    private fun exec(
        options: List<KclOption>,
        kCodes: List<String> = emptyList(),
        kFilenames: List<String> = emptyList(),
    ): KCLResultList {
        val bag = KclOptionBag()
        options.forEach { it.apply(bag) }
        bag.kCodes += kCodes
        bag.kFilenames += kFilenames
        val args = bag.toExecProgramArgs()
        if (args.kFilenameListCount == 0 && args.kCodeListCount == 0) {
            throw KclException("kcl.Run: no kcl file or code")
        }
        val resp = try {
            API().execProgram(args)
        } catch (e: Exception) {
            throw KclException(e.message ?: "kcl exec failed", e)
        }
        return execResultToKCLResult(resp)
    }

    /**
     * Turn an [ExecProgramResult] into a [KCLResultList], mirroring kcl-go's
     * `ExecResultToKCLResult`: a non-empty `err_message` becomes an exception;
     * the document list is built by splitting `yaml_result` on `---`
     * separators while the decoded values come from the runtime JSON stream
     * (with a YAML per-document fallback).
     */
    internal fun execResultToKCLResult(resp: ExecProgramResult): KCLResultList {
        if (resp.errMessage.isNotEmpty()) {
            throw KclException(resp.errMessage)
        }
        val json = resp.jsonResult
        val yaml = resp.yamlResult
        if (json.isBlank()) {
            return KCLResultList(emptyList(), json, yaml)
        }
        val documents = splitDocuments(yaml)
        val values = parseJsonStream(json)
        val count = maxOf(documents.size, values.size)
        val results = (0 until count).mapNotNull { i ->
            val document = documents.getOrNull(i)
            if (document != null && document.isBlank() && i >= values.size) {
                return@mapNotNull null
            }
            val value = values.getOrNull(i) ?: parseYamlDocument(document)
            KCLResult(value, document)
        }
        return KCLResultList(results, json, yaml)
    }

    /**
     * Split a YAML stream into its documents. A separator is any line
     * starting with `---`; only whitespace or comments may follow on the
     * same line. Mirrors kcl-go's `SplitDocuments`.
     */
    internal fun splitDocuments(yaml: String?): List<String> {
        val docs = mutableListOf<String>()
        if (yaml.isNullOrEmpty()) {
            return docs
        }
        val lines = yaml.lines()
        var current = mutableListOf<String>()
        var valid = true
        for (rawLine in lines) {
            val line = rawLine.removeSuffix("\r")
            if (line.startsWith("---")) {
                val rest = line.substring(3).trim()
                if (rest.isNotEmpty() && !rest.startsWith("#")) {
                    valid = false
                    break
                }
                docs.add(current.joinToString("\n"))
                current = mutableListOf()
            } else {
                current.add(rawLine)
            }
        }
        if (!valid) {
            return mutableListOf()
        }
        docs.add(current.joinToString("\n"))
        return docs
    }

    private fun parseJsonStream(json: String): List<Any?> = try {
        val iterator: MappingIterator<Any> =
            KclMappers.json.readerFor(Any::class.java).readValues(json)
        iterator.readAll()
    } catch (e: IOException) {
        throw KclException("failed to parse KCL JSON result: ${e.message}", e)
    }

    private fun parseYamlDocument(document: String?): Any? {
        if (document.isNullOrBlank()) {
            return null
        }
        return try {
            KclSettingsFile.YAML.load<Any>(document)
        } catch (e: RuntimeException) {
            throw KclException("failed to parse KCL YAML document: ${e.message}", e)
        }
    }
}
