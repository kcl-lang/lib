package com.kcl

import com.kcl.api.API
import com.kcl.api.formatCodeArgs
import com.kcl.api.formatPathArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class FormatTest {
    companion object {
        private const val TEST_PATH = "./src/test_data/format_path/test.k"
    }

    @Test
    fun testFormatPathApi() {
        val args = formatPathArgs { path = TEST_PATH }
        val api = API()
        val result = api.formatPath(args)
    }

    @Test
    fun testFormatCodeApi() {
        val sourceCode = "schema Person:\n" +
                "    name:   str\n" +
                "    age:    int\n" +
                "    check:\n" +
                "        0 <   age <   120\n"
        val args = formatCodeArgs { source = sourceCode }
        val api = API()
        val result = api.formatCode(args)
        val expectedFormattedCode = "schema Person:\n" +
                "    name: str\n" +
                "    age: int\n\n" +
                "    check:\n" +
                "        0 < age < 120\n\n"
        assertEquals(result.formatted.toStringUtf8(), expectedFormattedCode)
    }
}
