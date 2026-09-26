package com.kcl

import com.fasterxml.jackson.databind.ObjectMapper

/** Shared Jackson mapper for the facade; ObjectMapper is thread-safe after
 * configuration, so a single instance is kept. */
internal object KclMappers {
    val json: ObjectMapper = ObjectMapper()
}
