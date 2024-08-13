package com.kcl

import com.kcl.api.API
import com.kcl.api.testArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class TestingTest {
    companion object {
        private const val TEST_PKG = "./src/test_data/testing/..."
    }

    @Test
    fun testTestingApi() {
        val args = testArgs {
            pkgList += TEST_PKG
        }
        val api = API()
        val result = api.test(args)
        assertEquals(result.infoCount, 2)
    }
}
