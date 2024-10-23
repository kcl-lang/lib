package com.kcl

import com.kcl.api.API
import com.kcl.api.parseProgramArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals
import java.nio.file.Paths

class ParseProgramTest {
    companion object {
        private val TEST_FILE = Paths.get("src", "test_data", "parse", "main.k").toString()
    }

    @Test
    fun testParseProgramApi() {
        val args = parseProgramArgs { paths += TEST_FILE }
        val api = API()
        val result = api.parseProgram(args)
        assertEquals(result.pathsCount, 3)
    }
}
