package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.Test_Args;
import com.kcl.api.Spec.Test_Result;

import org.junit.Assert;
import org.junit.Test;

public class TestingTest {
    @Test
    public void testTestingApi() throws Exception {
        API apiInstance = new API();
        Test_Args args = Test_Args.newBuilder().addPkgList("./src/test_data/testing/...").build();
        Test_Result result = apiInstance.test(args);
        Assert.assertEquals(result.getInfoCount(), 2);
    }
}
