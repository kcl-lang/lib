package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.GetVersion_Args;
import com.kcl.api.Spec.GetVersion_Result;

public class GetVersionTest {
    @Test
    public void testGetVersion() throws Exception {
        API api = new API();
        GetVersion_Args version_args = GetVersion_Args.newBuilder().build();
        GetVersion_Result result = api.getVersion(version_args);
        String versionInfo = result.getVersionInfo();
        Assert.assertTrue(versionInfo, versionInfo.contains("Version"));
        Assert.assertTrue(versionInfo, versionInfo.contains("GitCommit"));
    }
}
