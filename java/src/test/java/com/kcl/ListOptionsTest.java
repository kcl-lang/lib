package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.ParseProgramArgs;
import com.kcl.api.Spec.ListOptionsResult;

public class ListOptionsTest {
    @Test
    public void testListOptionsApi() throws Exception {
        ParseProgramArgs args = ParseProgramArgs.newBuilder().addPaths("./src/test_data/option/main.k").build();

        API apiInstance = new API();
        ListOptionsResult result = apiInstance.listOptions(args);
        Assert.assertEquals(result.getOptions(0).getName(), "key1");
        Assert.assertEquals(result.getOptions(1).getName(), "key2");
        Assert.assertEquals(result.getOptions(2).getName(), "metadata-key");
    }
}
