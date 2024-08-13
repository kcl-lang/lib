package com.kcl

import com.kcl.api.API
import com.kcl.api.lintPathArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class LintTest {
    companion object {
        private const val TEST_PATH = "./src/test_data/lint_path/test-lint.k"
    }

    @Test
    fun testLintPathApi() {
        val args = lintPathArgs { paths += TEST_PATH }
        val api = API()
        val result = api.lintPath(args)
        val foundWarning = result.resultsList.any { warning -> warning.contains("Module 'math' imported but unused") }
        assertEquals(foundWarning, true)
    }
}
