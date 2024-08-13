package com.kcl

import com.kcl.api.API
import com.kcl.api.overrideFileArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

class OverrideFileTest {
    companion object {
        private const val TEST_FILE = "./src/test_data/schema.k"
    }

    @Test
    fun testOverrideFileApi() {
        val api = API()
        val testCases = arrayOf("a=2", "b.a=[1, 2, 3]")
        val source = Paths.get("./src/test_data/override_file/main.k.bk")
        val target = Paths.get("./src/test_data/override_file/main.k")
        if (Files.exists(target)) {
            Files.delete(target)
        }
        Files.copy(source, target)
        for (spec in testCases) {
            val result = api.overrideFile(
                overrideFileArgs {
                    file = "./src/test_data/override_file/main.k";
                    specs += spec
                }
            )
            assertEquals(result.result, true)
        }

        if (Files.exists(target)) {
            Files.delete(target)
        }
    }
}
