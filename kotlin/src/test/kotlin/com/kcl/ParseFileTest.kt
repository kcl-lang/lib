package com.kcl

import com.kcl.api.API
import com.kcl.api.parseFileArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals
import java.nio.file.Paths

class ParseFileTest {
    companion object {
        private val TEST_FILE = Paths.get("src", "test_data", "parse", "main.k").toString()
    }

    @Test
    fun testParseFileApi() {
        val args = parseFileArgs { path = TEST_FILE }
        val api = API()
        val result = api.parseFile(args)
        assertEquals(result.depsCount, 2)
    }
}
