package com.kcl

import com.kcl.api.API
import com.kcl.api.pingArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class PingTest {
    @Test
    fun testPing() {
        val args = pingArgs {
            value = "hello-kcl"
        }
        val api = API()
        val result = api.ping(args)
        assertEquals("hello-kcl", result.value)
    }
}
