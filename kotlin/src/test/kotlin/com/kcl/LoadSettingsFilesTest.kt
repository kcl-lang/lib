package com.kcl

import com.kcl.api.API
import com.kcl.api.loadSettingsFilesArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class LoadSettingsFileTest {
    companion object {
        private const val TEST_FILE = "./src/test_data/settings/kcl.yaml"
    }

    @Test
    fun testLoadSettingsFilesApi() {
        val args = loadSettingsFilesArgs { files += TEST_FILE }
        val api = API()
        val result = api.loadSettingsFiles(args)
        assertEquals(result.kclCliConfigs.filesCount, 0)
        assertEquals(result.kclCliConfigs.strictRangeCheck, true)
        assertEquals(result.kclOptionsList[0].key, "key")
        assertEquals(result.kclOptionsList[0].value, "\"value\"")
    }
}
