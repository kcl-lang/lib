package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.TestArgs;
import com.kcl.api.Spec.TestResult;

import org.junit.Assert;
import org.junit.Test;

public class TestingTest {
    @Test
    public void testTestingApi() throws Exception {
        API apiInstance = new API();
        TestArgs args = TestArgs.newBuilder().addPkgList("./src/test_data/testing/...").build();
        TestResult result = apiInstance.test(args);
        Assert.assertEquals(result.getInfoCount(), 2);
    }
}
