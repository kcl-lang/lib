package com.kcl

import com.kcl.api.API
import com.kcl.api.renameCodeArgs
import com.kcl.api.renameArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Paths

class RenameTest {
    @Test
    fun testRenameCodeApi() {
        val args = renameCodeArgs {
            packageRoot = "/mock/path"
            sourceCodes.put("/mock/path/main.k", "a = 1\nb = a")
            symbolPath = "a"
            newName = "a2"
        }
        val api = API()
        val result = api.renameCode(args)
        assertEquals(result.changedCodes["/mock/path/main.k"], "a2 = 1\nb = a2")
    }

    @Test
    fun testRenameApi() {
        val backupContent = Files.readAllBytes(Paths.get("./src/test_data/rename/main.bak")).toString(StandardCharsets.UTF_8)
        Files.write(Paths.get("./src/test_data/rename/main.k"), backupContent.toByteArray(StandardCharsets.UTF_8))
        val args = renameArgs {
            packageRoot = "./src/test_data/rename"
            filePaths += "./src/test_data/rename/main.k"
            symbolPath = "a"
            newName = "a2"
        }
        val api = API()
        val result = api.rename(args)
        assertEquals(result.changedFilesList[0].contains("main.k"), true)
    }
}
