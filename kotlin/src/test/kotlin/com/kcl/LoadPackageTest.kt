package com.kcl

import com.kcl.api.API
import com.kcl.api.loadPackageArgs
import com.kcl.api.parseProgramArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class LoadPackageTest {
    companion object {
        private const val TEST_FILE = "./src/test_data/schema.k"
    }

    @Test
    fun testLoadPackageApi() {
        val args = loadPackageArgs { parseArgs = parseProgramArgs { paths += TEST_FILE }; resolveAst = true }
        val api = API()
        val result = api.loadPackage(args)
        assertEquals(result.parseErrorsList.size, 0)
        assertEquals(result.typeErrorsList.size, 0)
    }
}
