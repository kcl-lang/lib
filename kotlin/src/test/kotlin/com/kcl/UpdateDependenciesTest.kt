package com.kcl

import com.kcl.api.API
import com.kcl.api.execProgramArgs
import com.kcl.api.externalPkg
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
        val api = API()
        // The local kcl.mod declares both deps as `path = "../_mocks/..."`, but
        // `update_dependencies` always returns `pkg_path = <manifest>/<dep_name>`
        // (it ignores the `path` directive), so we hand-build `external_pkgs`
        // pointing at the actual mock locations.
        val execArgs = execProgramArgs {
            kFilenameList += "./src/test_data/update_dependencies/main.k"
            externalPkgs.add(
                externalPkg {
                    pkgName = "helloworld"
                    pkgPath = "./src/test_data/_mocks/helloworld"
                }
            )
            externalPkgs.add(
                externalPkg {
                    pkgName = "flask"
                    pkgPath = "./src/test_data/_mocks/flask"
                }
            )
        }
        val execResult = api.execProgram(execArgs)
        assertEquals(execResult.yamlResult, "a: Hello World!")
    }
}
