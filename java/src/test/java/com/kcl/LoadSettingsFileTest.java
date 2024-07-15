package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.LoadSettingsFiles_Args;
import com.kcl.api.Spec.LoadSettingsFiles_Result;

public class LoadSettingsFileTest {
    @Test
    public void testLoadSettingsFile() throws Exception {
        API api = new API();
        LoadSettingsFiles_Args args = LoadSettingsFiles_Args.newBuilder().addFiles("./src/test_data/settings/kcl.yaml")
                .build();
        LoadSettingsFiles_Result result = api.loadSettingsFiles(args);
        Assert.assertEquals(result.getKclCliConfigs().getFilesCount(), 0);
        Assert.assertEquals(result.getKclCliConfigs().getStrictRangeCheck(), true);
        Assert.assertEquals(result.getKclOptions(0).getKey(), "key");
        Assert.assertEquals(result.getKclOptions(0).getValue(), "\"value\"");
    }
}
