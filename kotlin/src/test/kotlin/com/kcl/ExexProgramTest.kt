package com.kcl

import com.kcl.api.API
import com.kcl.api.execProgramArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class ExecProgramTest {
    companion object {
        private const val TEST_FILE = "./src/test_data/schema.k"
    }

    @Test
    fun testExecProgramApi() {
        val args = execProgramArgs { kFilenameList += TEST_FILE }
        val api = API()
        val result = api.execProgram(args)
        assertEquals(result.yamlResult, "app:\n  replicas: 2")
    }
}
