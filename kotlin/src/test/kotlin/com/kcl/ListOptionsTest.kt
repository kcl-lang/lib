package com.kcl

import com.kcl.api.API
import com.kcl.api.parseProgramArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class ListOptionsTest {
    companion object {
        private const val TEST_FILE = "./src/test_data/option/main.k"
    }

    @Test
    fun testListOptionsApi() {
        val args = parseProgramArgs { paths += TEST_FILE }
        val api = API()
        val result = api.listOptions(args)
        assertEquals("key1", result.optionsList[0].name)
        assertEquals("key2", result.optionsList[1].name)
        assertEquals("metadata-key", result.optionsList[2].name)
    }
}
