package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExecProgramResult;
import com.kcl.api.Spec.UpdateDependenciesArgs;
import com.kcl.api.Spec.UpdateDependenciesResult;

import org.junit.Assert;
import org.junit.Test;

public class UpdateDependenciesTest {
    @Test
    public void testUpdateDependencies() throws Exception {
        // API instance
        API api = new API();

        UpdateDependenciesResult result = api.updateDependencies(
                UpdateDependenciesArgs.newBuilder().setManifestPath("./src/test_data/update_dependencies").build());
        Assert.assertEquals(result.getExternalPkgsCount(), 2);
    }

    @Test
    public void testExecProgramWithExternalDependencies() throws Exception {
        // API instance
        API api = new API();

        UpdateDependenciesResult result = api.updateDependencies(
                UpdateDependenciesArgs.newBuilder().setManifestPath("./src/test_data/update_dependencies").build());
        Assert.assertEquals(result.getExternalPkgsCount(), 2);

        ExecProgramArgs execArgs = ExecProgramArgs.newBuilder().addAllExternalPkgs(result.getExternalPkgsList())
                .addKFilenameList("./src/test_data/update_dependencies/main.k").build();

        ExecProgramResult execResult = api.execProgram(execArgs);
        Assert.assertEquals(execResult.getYamlResult(), "a: Hello World!");
    }
}
