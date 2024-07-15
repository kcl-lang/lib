package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgram_Args;
import com.kcl.api.Spec.ExecProgram_Result;
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

    @Test
    public void testExecProgramWithExternalDependencies() throws Exception {
        // API instance
        API api = new API();

        UpdateDependencies_Result result = api.updateDependencies(
                UpdateDependencies_Args.newBuilder().setManifestPath("./src/test_data/update_dependencies").build());
        Assert.assertEquals(result.getExternalPkgsCount(), 2);

        ExecProgram_Args execArgs = ExecProgram_Args.newBuilder().addAllExternalPkgs(result.getExternalPkgsList())
                .addKFilenameList("./src/test_data/update_dependencies/main.k").build();

        ExecProgram_Result execResult = api.execProgram(execArgs);
        Assert.assertEquals(execResult.getYamlResult(), "a: Hello World!");
    }
}
