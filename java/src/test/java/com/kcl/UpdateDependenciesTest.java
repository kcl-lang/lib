package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExecProgramResult;
import com.kcl.api.Spec.ExternalPkg;
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

        // The local kcl.mod declares both deps as `path = "../_mocks/..."`, but
        // `update_dependencies` always returns `pkg_path = <manifest>/<dep_name>`
        // (it ignores the `path` directive), so we hand-build `external_pkgs`
        // pointing at the actual mock locations.
        ExecProgramArgs execArgs = ExecProgramArgs.newBuilder()
                .addExternalPkgs(ExternalPkg.newBuilder().setPkgName("helloworld")
                        .setPkgPath("./src/test_data/_mocks/helloworld").build())
                .addExternalPkgs(
                        ExternalPkg.newBuilder().setPkgName("flask").setPkgPath("./src/test_data/_mocks/flask").build())
                .addKFilenameList("./src/test_data/update_dependencies/main.k").build();

        ExecProgramResult execResult = api.execProgram(execArgs);
        Assert.assertEquals(execResult.getYamlResult(), "a: Hello World!");
    }
}
