package com.kcl

import com.kcl.api.API
import com.kcl.api.getVersionArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class GetVersionTest {
    @Test
    fun testGetVersion() {
        val args = getVersionArgs {}
        val api = API()
        val result = api.getVersion(args)
        assertEquals(result.versionInfo.contains("Version"), true)
        assertEquals(result.versionInfo.contains("GitCommit"), true)
    }
}
