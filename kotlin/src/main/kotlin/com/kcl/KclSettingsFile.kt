package com.kcl

import com.kcl.api.Spec
import com.kcl.api.Spec.ExecProgramArgs
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.constructor.SafeConstructor
import java.io.IOException
import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Paths

/**
 * Parsed `kcl.yaml` settings file, mirroring kcl-go's
 * `settings.SettingsFile`: a `kcl_cli_configs` mapping plus a `kcl_options`
 * list of `{key, value}` entries. YAML parsing uses SnakeYAML (mappings come
 * out as order-preserving LinkedHashMaps) and complex `kcl_options` values
 * are re-encoded to JSON with the module's existing Jackson databind
 * dependency, so key order round-trips like kcl-go's order-aware encoding.
 *
 * Supported `kcl_cli_configs` fields: `file`/`files`, `overrides`,
 * `path_selector`, `strict_range_check`, `disable_none`, `verbose`, `debug`,
 * `package_maps`, `sort_keys`, `show_hidden` and `include_schema_type_path`.
 * The `output` field is not supported because the underlying
 * `ExecProgramArgs` proto has no output format field.
 */
internal class KclSettingsFile private constructor(
    private val config: Map<*, *>?,
    private val options: List<Spec.Argument>,
) {
    companion object {
        internal val YAML = Yaml(SafeConstructor())

        /**
         * Load and parse a settings file. Missing or unparsable files raise
         * [KclException], mirroring kcl-go's `WithSettings` error propagation;
         * empty files yield an empty config.
         */
        fun load(filename: String): KclSettingsFile {
            val text = try {
                String(Files.readAllBytes(Paths.get(filename)), StandardCharsets.UTF_8)
            } catch (e: IOException) {
                throw KclException("kcl.WithSettings($filename): ${e.message}", e)
            }
            if (text.isBlank()) {
                return KclSettingsFile(null, emptyList())
            }
            val root = try {
                YAML.load<Any>(text)
            } catch (e: RuntimeException) {
                throw KclException("kcl.WithSettings($filename): ${e.message}", e)
            }
            if (root !is Map<*, *>) {
                return KclSettingsFile(null, emptyList())
            }
            val config = root["kcl_cli_configs"] as? Map<*, *>
            val entries = root["kcl_options"] as? List<*>
            val options = entries.orEmpty().mapNotNull { entry ->
                val map = entry as? Map<*, *> ?: return@mapNotNull null
                val key = map["key"] as? String ?: return@mapNotNull null
                Spec.Argument.newBuilder()
                    .setName(key)
                    .setValue(stringifyValue(map["value"]))
                    .build()
            }
            return KclSettingsFile(config, options)
        }

        /**
         * Serialise a `kcl_options` value like kcl-go: map/list values become
         * JSON (preserving document order), scalars their plain string form,
         * and `null` the empty string.
         */
        private fun stringifyValue(value: Any?): String = when (value) {
            null -> ""
            is Map<*, *>, is List<*> -> try {
                KclMappers.json.writeValueAsString(value)
            } catch (e: IOException) {
                value.toString()
            }
            else -> value.toString()
        }
    }

    /**
     * Populate a proto builder from this file, mirroring kcl-go's
     * `SettingsFile.To_ExecProgramArgs`. Relative input files are resolved
     * against [workDir] with `${PWD}` and `${KCL_MOD}` expansion.
     */
    fun applyTo(builder: ExecProgramArgs.Builder, workDir: String) {
        val config = config ?: return
        addStrings(builder, "file", config, workDir)
        addStrings(builder, "files", config, workDir)
        (config["overrides"] as? List<*>)?.forEach { item ->
            (item as? String)?.takeUnless { it.isEmpty() }?.let { builder.addOverrides(it) }
        }
        (config["path_selector"] as? List<*>)?.forEach { item ->
            (item as? String)?.takeUnless { it.isEmpty() }?.let { builder.addPathSelector(it) }
        }
        if (config["strict_range_check"] == true) builder.strictRangeCheck = true
        if (config["disable_none"] == true) builder.disableNone = true
        (config["verbose"] as? Number)?.toInt()?.takeIf { it > 0 }?.let { builder.verbose = it }
        if (config["debug"] == true) builder.debug = 1
        if (config["sort_keys"] == true) builder.sortKeys = true
        if (config["show_hidden"] == true) builder.showHidden = true
        if (config["include_schema_type_path"] == true) builder.includeSchemaTypePath = true
        (config["package_maps"] as? Map<*, *>)?.forEach { (name, path) ->
            if (name is String && path is String) {
                builder.addExternalPkgs(
                    Spec.ExternalPkg.newBuilder().setPkgName(name).setPkgPath(path).build()
                )
            }
        }
        builder.addAllArgs(options)
    }

    private fun addStrings(builder: ExecProgramArgs.Builder, field: String, config: Map<*, *>, workDir: String) {
        val values = when (val node = config[field]) {
            is String -> listOf(node)
            is List<*> -> node.filterIsInstance<String>()
            else -> emptyList()
        }
        values.filter { it.isNotEmpty() }.forEach { builder.addKFilenameList(resolveInputFile(it, workDir)) }
    }

    private fun resolveInputFile(s: String, workDir: String): String {
        val pkgRoot = findPkgRoot(workDir)
        var resolved = s.replace("\${PWD}", workDir)
        if (pkgRoot.isNotEmpty()) {
            resolved = resolved.replace("\${KCL_MOD}", pkgRoot)
        }
        return if (resolved.startsWith(".") || (!resolved.startsWith("\${") && !Paths.get(resolved).isAbsolute)) {
            Paths.get(workDir).resolve(resolved).normalize().toString()
        } else {
            resolved
        }
    }

    /** Walk up from [workDir] looking for a `kcl.mod` file, mirroring
     * kcl-go's `tools/list.FindPkgInfo`. */
    private fun findPkgRoot(workDir: String): String {
        var dir: java.nio.file.Path? = Paths.get(workDir.ifEmpty { "." }).toAbsolutePath().normalize()
        while (dir != null) {
            if (Files.exists(dir.resolve("kcl.mod"))) {
                return dir.toString()
            }
            dir = dir.parent
        }
        return ""
    }
}
