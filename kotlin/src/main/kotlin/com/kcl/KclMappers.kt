package com.kcl

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jdk8.Jdk8Module

/** Shared Jackson mapper for the facade; ObjectMapper is thread-safe after
 * configuration, so a single instance is kept. The AST types declare Rust's
 * `Option<T>` as `java.util.Optional`, so the Jdk8 module is registered. */
internal object KclMappers {
    val json: ObjectMapper = ObjectMapper().registerModule(Jdk8Module())
}
