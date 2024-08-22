package com.kcl

import com.kcl.api.API
import com.kcl.api.listVariablesArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class ListVariablesTest {
    companion object {
        private const val TEST_FILE = "./src/test_data/schema.k"
    }

    @Test
    fun testListVariablesApi() {
        val args = listVariablesArgs { files += TEST_FILE }
        val api = API()
        val result = api.listVariables(args)
        assertEquals(result.variablesMap["app"]?.variablesList?.get(0)?.value, "AppConfig {\n    replicas: 2\n}")
    }
}
