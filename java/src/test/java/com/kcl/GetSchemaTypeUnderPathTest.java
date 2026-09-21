package com.kcl;

import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExternalPkg;
import com.kcl.api.Spec.GetSchemaTypeMappingArgs;
import com.kcl.api.Spec.GetSchemaTypeMappingUnderPathResult;
import com.kcl.api.Spec.KclType;

import org.junit.Assert;
import org.junit.Test;

public class GetSchemaTypeUnderPathTest {

    private static final Path ROOT = Paths.get("./src/test_data/get_schema_ty_under_path").toAbsolutePath();

    @Test
    public void testGetSchemaTypeUnderPathApi() throws Exception {
        ExecProgramArgs execArgs = ExecProgramArgs.newBuilder()
                .addKFilenameList(ROOT.resolve("aaa").toString())
                .addExternalPkgs(ExternalPkg.newBuilder().setPkgName("bbb")
                        .setPkgPath(ROOT.resolve("bbb").toString()).build())
                .build();

        GetSchemaTypeMappingArgs args = GetSchemaTypeMappingArgs.newBuilder().setExecArgs(execArgs).build();

        API apiInstance = new API();
        GetSchemaTypeMappingUnderPathResult result = apiInstance.getSchemaTypeMappingUnderPath(args);

        // Schemas from the external dependency package must be keyed under
        // their own package name, not flattened into "__main__".
        Map<String, KclType> bbbSchemas = result.getSchemaTypeMappingOrThrow("bbb").getSchemaTypeList().stream()
                .collect(Collectors.toMap(KclType::getSchemaName, s -> s));
        Assert.assertTrue("expected schemas Base and B in bbb, got " + bbbSchemas.keySet(),
                bbbSchemas.containsKey("Base") && bbbSchemas.containsKey("B"));

        KclType base = bbbSchemas.get("Base");
        KclType b = bbbSchemas.get("B");
        // Regression for https://github.com/kcl-lang/kcl/issues/1546.
        Assert.assertEquals("bbb", base.getPkgPath());
        Assert.assertEquals("bbb", b.getPkgPath());
        Assert.assertTrue("B.base_schema must be resolved across the package boundary",
                b.hasBaseSchema());
        Assert.assertEquals("Base", b.getBaseSchema().getSchemaName());
        Assert.assertEquals("bbb", b.getBaseSchema().getPkgPath());

        // The main package keeps its own schemas too.
        List<KclType> mainSchemas = result.getSchemaTypeMappingOrThrow("__main__").getSchemaTypeList();
        Assert.assertTrue(mainSchemas.stream().anyMatch(s -> s.getSchemaName().equals("A")));
    }
}
