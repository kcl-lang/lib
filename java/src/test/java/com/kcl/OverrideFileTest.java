package com.kcl;

import com.kcl.api.API;
import com.kcl.api.Spec.LoadPackage_Args;
import com.kcl.api.Spec.LoadPackage_Result;
import com.kcl.api.Spec.OverrideFile_Args;
import com.kcl.api.Spec.OverrideFile_Result;
import com.kcl.api.Spec.ParseProgram_Args;
import com.kcl.api.Spec.Scope;
import com.kcl.api.Spec.Symbol;
import com.kcl.api.Spec.SymbolIndex;
import com.kcl.ast.NodeRef;
import com.kcl.ast.Program;
import com.kcl.ast.Stmt;
import com.kcl.util.JsonUtil;
import com.kcl.util.SematicUtil;

import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import org.junit.Assert;
import org.junit.Test;

public class OverrideFileTest {
    @Test
    public void testOverrideFile() throws Exception {
        // API instance
        API api = new API();

        // Define the variables to test and their expected results
        String[] testCases = { ":a=2", ":b.a=[1, 2, 3]" };

        Path source = Paths.get("./src/test_data/override_file/main.k.bk");
        Path target = Paths.get("./src/test_data/override_file/main.k");
        if (Files.exists(target)) {
            Files.delete(target);
        }
        Files.copy(source, target);

        for (String spec : testCases) {
            OverrideFile_Result result = api.overrideFile(OverrideFile_Args.newBuilder()
                    .setFile("./src/test_data/override_file/main.k").addSpecs(spec).build());

            Assert.assertEquals(result.getResult(), true);
        }
        if (Files.exists(target)) {
            Files.delete(target);
        }
    }
}
