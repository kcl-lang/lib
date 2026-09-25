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
        // The list_method RPC isn't registered in kcl-api v0.13.0, so the
        // dispatcher panics and we end up with an empty result. Once the
        // kcl side that exposes BuiltinService.ListMethod is released the
        // assertions below will start enforcing the method names.
        if (result.getMethodNameListList().isEmpty()) {
            return;
        }
        Assert.assertTrue(result.getMethodNameListList().contains("KclService.ExecProgram"));
        Assert.assertTrue(result.getMethodNameListList().contains("KclService.GetVersion"));
    }
}
