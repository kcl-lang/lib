package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.PingArgs;
import com.kcl.api.Spec.PingResult;

public class PingTest {
    @Test
    public void testPing() throws Exception {
        API api = new API();
        PingArgs args = PingArgs.newBuilder().setValue("hello-kcl").build();
        PingResult result = api.ping(args);
        Assert.assertEquals("hello-kcl", result.getValue());
    }
}
