package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.LoadSettingsFilesArgs;
import com.kcl.api.Spec.LoadSettingsFilesResult;

public class LoadSettingsFilesTest {
    @Test
    public void testLoadSettingsFile() throws Exception {
        API api = new API();
        LoadSettingsFilesArgs args = LoadSettingsFilesArgs.newBuilder().addFiles("./src/test_data/settings/kcl.yaml")
                .build();
        LoadSettingsFilesResult result = api.loadSettingsFiles(args);
        Assert.assertEquals(result.getKclCliConfigs().getFilesCount(), 0);
        Assert.assertEquals(result.getKclCliConfigs().getStrictRangeCheck(), true);
        Assert.assertEquals(result.getKclOptions(0).getKey(), "key");
        Assert.assertEquals(result.getKclOptions(0).getValue(), "\"value\"");
    }
}
