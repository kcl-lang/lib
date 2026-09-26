package com.kcl

import com.fasterxml.jackson.core.JsonProcessingException

/**
 * Structured view of one configuration document produced by a KCL run:
 * the parsed value (a [Map], [List] or scalar decoded from the runtime JSON
 * stream) plus the raw YAML document the runtime emitted for it.
 */
data class KCLResult internal constructor(
    /** The raw decoded value: a `Map<String, Any?>`, `List<Any?>` or scalar,
     * or `null`. */
    val value: Any?,
    /** The raw YAML document emitted by the runtime for this result (one
     * slice of the multi-document `yaml_result`), or `null` when
     * unavailable. */
    val yamlDocument: String?,
) {

    /**
     * Look up [key] in the parsed value, mirroring kcl-go's
     * `KCLResult.Get`. Dotted keys navigate nested maps and numeric segments
     * index into lists. Returns `null` when the key is absent.
     */
    fun get(key: String): Any? {
        var current: Any? = value
        for (part in key.split('.')) {
            current = when (current) {
                is Map<*, *> -> current[part]
                is List<*> -> {
                    val index = part.toIntOrNull()
                    if (index != null && index >= 0 && index < current.size) current[index] else null
                }
                else -> return null
            }
            if (current == null) {
                return null
            }
        }
        return current
    }

    /**
     * Typed variant of [get], mirroring kcl-go's `Get(key, target)`:
     * coerces the value at [key] to [target], throwing [KclException] on a
     * type mismatch (numeric widening is allowed, everything else is strict).
     * Returns `null` when the key is absent.
     */
    @Suppress("UNCHECKED_CAST")
    fun <T> get(key: String, target: Class<T>): T? {
        val value = get(key) ?: return null
        if (target.isInstance(value)) {
            return target.cast(value)
        }
        // Accept both the wrapper and the primitive class form (Kotlin's
        // `Int::class.java` is the primitive int.class).
        if ((target == Integer::class.javaObjectType || target == Integer::class.java) && value is Number) {
            return value.toInt() as T
        }
        if ((target == Double::class.javaObjectType || target == Double::class.java) && value is Number) {
            return value.toDouble() as T
        }
        throw KclException(
            "failed to convert $key to ${target.simpleName}: type mismatch, got " +
                (value?.javaClass?.simpleName ?: "null")
        )
    }

    /** Reified shorthand for `get(key, T::class.java)`. */
    fun <T : Any> get(key: String, target: kotlin.reflect.KClass<T>): T? = get(key, target.java)

    /** The value at [key] as a [String]; `null` when absent. */
    fun getString(key: String): String? {
        val value = get(key) ?: return null
        return value as? String
            ?: throw KclException("failed to convert $key to String: type mismatch")
    }

    /** The value at [key] as an [Int]; `null` when absent. */
    fun getInt(key: String): Int? {
        val value = get(key) ?: return null
        return (value as? Number)?.toInt()
            ?: throw KclException("failed to convert $key to Int: type mismatch")
    }

    /** The value at [key] as a [Double]; `null` when absent. */
    fun getDouble(key: String): Double? {
        val value = get(key) ?: return null
        return (value as? Number)?.toDouble()
            ?: throw KclException("failed to convert $key to Double: type mismatch")
    }

    /** The value at [key] as a [Boolean]; `null` when absent. */
    fun getBoolean(key: String): Boolean? {
        val value = get(key) ?: return null
        return value as? Boolean
            ?: throw KclException("failed to convert $key to Boolean: type mismatch")
    }

    /** The whole document as a map, mirroring kcl-go's `ToMap`. */
    @Suppress("UNCHECKED_CAST")
    fun toMap(): Map<String, Any?> = value as? Map<String, Any?>
        ?: throw KclException(
            "failed to convert result to map: type mismatch, got " +
                (value?.javaClass?.simpleName ?: "null")
        )

    /** The whole document as a list, mirroring kcl-go's `ToList`. */
    @Suppress("UNCHECKED_CAST")
    fun toList(): List<Any?> = value as? List<Any?>
        ?: throw KclException(
            "failed to convert result to list: type mismatch, got " +
                (value?.javaClass?.simpleName ?: "null")
        )

    /**
     * The raw YAML document emitted by the runtime for this result (one
     * slice of the multi-document `yaml_result`), or an empty string when
     * unavailable.
     */
    fun yamlString(): String = yamlDocument ?: ""

    /** The document re-encoded as JSON, mirroring kcl-go's `JSONString`. */
    fun jsonString(): String = try {
        KclMappers.json.writerWithDefaultPrettyPrinter().writeValueAsString(value)
    } catch (e: JsonProcessingException) {
        throw IllegalStateException("failed to encode KCL result as JSON", e)
    }
}

/**
 * Collection of [KCLResult] documents produced by a run, mirroring kcl-go's
 * `KCLResultList`. The raw runtime outputs are kept for callers that need the
 * untouched response.
 */
class KCLResultList internal constructor(
    private val results: List<KCLResult>,
    /** The untouched `json_result` emitted by the runtime. */
    val rawJsonResult: String,
    /** The untouched `yaml_result` emitted by the runtime. */
    val rawYamlResult: String,
) : List<KCLResult> by results {

    /** The first document, or `null` when empty. */
    fun first(): KCLResult? = results.firstOrNull()

    /** The last document, or `null` when empty. */
    fun tail(): KCLResult? = results.lastOrNull()

    /** The first document as a map, mirroring kcl-go's `KCLResultList.ToMap`. */
    fun toMap(): Map<String, Any?> =
        firstOrNull()?.toMap() ?: throw KclException("result is nil")

    /** Dotted-key lookup on the first document; `null` when absent. */
    fun get(key: String): Any? = firstOrNull()?.get(key)
}
