package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgram_Args;
import com.kcl.api.Spec.ExecProgram_Result;

import java.util.Map;

import org.junit.Assert;
import org.junit.Test;

public class PluginTest {
    @Test
    public void testExecProgramWithPlugin() throws Exception {
        // API instance
        API.registerPlugin("my_plugin", Map.of("add", (args, kwArgs) -> {
            return (int) args[0] + (int) args[1];
        }));
        API api = new API();

        ExecProgram_Result result = api
                .execProgram(ExecProgram_Args.newBuilder().addKFilenameList("./src/test_data/plugin/plugin.k").build());

        Assert.assertEquals(result.getYamlResult(), "result: 2");
    }
}
