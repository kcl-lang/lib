package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExecProgramResult;

import java.util.Collections;

import org.junit.Assert;
import org.junit.Test;

public class PluginTest {
    @Test
    public void testExecProgramWithPlugin() throws Exception {
        API.registerPlugin("my_plugin", Collections.singletonMap("add", (args, kwArgs) -> {
            return (int) args[0] + (int) args[1];
        }));
        API api = new API();
        ExecProgramArgs exec_args = ExecProgramArgs.newBuilder().addKFilenameList("./src/test_data/plugin/plugin.k")
                .build();
        ExecProgramResult result = api.execProgram(exec_args);

        Assert.assertEquals(result.getYamlResult(), "result: 2");

        API.registerPlugin("my_plugin", Collections.singletonMap("add", (args, kwArgs) -> {
            return (int) args[20];
        }));
        api = new API();
        result = api.execProgram(exec_args);

        Assert.assertTrue("err: " + result.getErrMessage() + "yaml:" + result.getYamlResult(),
                result.getErrMessage().contains("20"));
    }
}
