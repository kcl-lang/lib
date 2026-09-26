package com.kcl

import com.kcl.api.API
import com.kcl.api.Spec.ExecProgramArgs
import com.kcl.plugin.MethodFunction
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import java.util.Collections

class PluginTest {
    @Test
    fun testExecProgramWithPlugin() {
        API.registerPlugin("my_plugin", Collections.singletonMap<String, MethodFunction>("add",
            MethodFunction { args, _ -> (args[0] as Int) + (args[1] as Int) }
        ))
        var api = API()
        val execArgs = ExecProgramArgs.newBuilder()
            .addKFilenameList("./src/test_data/plugin.k")
            .build()
        var result = api.execProgram(execArgs)
        assertEquals(result.yamlResult, "result: 2")

        API.registerPlugin("my_plugin", Collections.singletonMap<String, MethodFunction>("add",
            MethodFunction { args, _ -> args[20] }
        ))
        api = API()
        result = api.execProgram(execArgs)
        val errContains20 = result.errMessage.contains("20")
        assertTrue(
            errContains20,
            "err: ${result.errMessage} yaml:${result.yamlResult}"
        )
    }
}
