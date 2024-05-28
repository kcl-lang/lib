package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.UpdateDependencies_Args;
import com.kcl.api.Spec.UpdateDependencies_Result;

import org.junit.Assert;
import org.junit.Test;

public class UpdateDependenciesTest {
    @Test
    public void testUpdateDependencies() throws Exception {
        // API instance
        API api = new API();

        UpdateDependencies_Result result = api.updateDependencies(
                UpdateDependencies_Args.newBuilder().setManifestPath("./src/test_data/update_dependencies").build());
        Assert.assertEquals(result.getExternalPkgsCount(), 2);
    }
}
