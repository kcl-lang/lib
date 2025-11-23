package com.kcl;

import org.junit.Assert;
import org.junit.Test;

import com.kcl.api.API;
import com.kcl.api.Spec.GetVersionArgs;
import com.kcl.api.Spec.GetVersionResult;

public class GetVersionTest {
    @Test
    public void testGetVersion() throws Exception {
        API api = new API();
        GetVersionArgs version_args = GetVersionArgs.newBuilder().build();
        GetVersionResult result = api.getVersion(version_args);
        String versionInfo = result.getVersionInfo();
        Assert.assertTrue(versionInfo, versionInfo.contains("Version"));
        Assert.assertTrue(versionInfo, versionInfo.contains("GitCommit"));
    }
}
