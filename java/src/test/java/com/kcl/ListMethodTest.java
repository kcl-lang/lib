package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.ListMethodResult;

public class ListMethodTest {
    @Test
    public void testListMethod() throws Exception {
        API api = new API();
        ListMethodResult result = api.listMethod();
        Assert.assertNotNull(result.getMethodNameList());
        Assert.assertTrue(result.getMethodNameList().size() > 0);
        Assert.assertTrue(result.getMethodNameList().contains("KclService.ExecProgram"));
        Assert.assertTrue(result.getMethodNameList().contains("KclService.GetVersion"));
    }
}
