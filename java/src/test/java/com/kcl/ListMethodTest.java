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
        Assert.assertNotNull(result.getMethodNameListList());
        Assert.assertTrue(result.getMethodNameListList().contains("KclService.ExecProgram"));
        Assert.assertTrue(result.getMethodNameListList().contains("KclService.GetVersion"));
        // Pin the registry size so a method cannot be dropped from the core
        // without this binding noticing -- `KclService.ListDepFiles` was removed
        // in v0.13.1, replaced by `LoadPackageResult.imports` / `kcl_mod` / `apps`.
        Assert.assertEquals(28, result.getMethodNameListList().size());
    }
}
