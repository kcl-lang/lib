package com.kcl

import com.kcl.api.API
import com.kcl.api.execProgramArgs
import com.kcl.api.updateDependenciesArgs
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals

class UpdateDependenciesTest {
    @Test
    fun testUpdateDependencies() {
        val args = updateDependenciesArgs { manifestPath = "./src/test_data/update_dependencies" }
        val api = API()
        val result = api.updateDependencies(args)
        assertEquals(result.externalPkgsList.size, 2)
    }

    @Test
    fun testExecProgramWithExternalDependencies() {
        val args = updateDependenciesArgs { manifestPath = "./src/test_data/update_dependencies" }
        val api = API()
        val result = api.updateDependencies(args)
        assertEquals(result.externalPkgsList.size, 2)
        val execArgs = execProgramArgs {
            kFilenameList += "./src/test_data/update_dependencies/main.k"
            externalPkgs.addAll(result.externalPkgsList)
        }
        val execResult = api.execProgram(execArgs)
        assertEquals(execResult.yamlResult, "a: Hello World!")
    }
}
